using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Hubs;
using FixoApi.Jobs;
using FixoApi.Models;
using FixoApi.Options;
using Hangfire;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace FixoApi.Services;

/// <summary>
/// v1.7 (P12-23): project quotes. The homeowner may request quotes from up to 3
/// tradies concurrently (Builderscrack-style cap); each asked tradie submits a
/// structured quote instead of a one-tap accept. Accepting one quote declines
/// the others, books the job (after any written-contract confirmation, P12-25)
/// and snapshots the agreed pricing model onto the job. Payment still happens
/// at completion.
///
/// D8: quote prices are final consumer prices. GST-registered tradies must
/// carry GstIncluded=true; unregistered tradies cannot charge GST, so their
/// quotes must carry GstIncluded=false.
/// </summary>
public class QuoteService
{
    private readonly FixoDbContext _context;
    private readonly IJobStatusService _jobStatusService;
    private readonly IHubContext<JobHub> _jobHub;
    private readonly INotificationService _notifications;
    private readonly IBackgroundJobClient _hangfire;
    private readonly IOptions<JobFlowOptions> _flowOptions;
    private readonly IPlatformSettings _settings;
    private readonly IConfiguration _config;
    private readonly ILogger<QuoteService> _logger;

    public QuoteService(
        FixoDbContext context,
        IJobStatusService jobStatusService,
        IHubContext<JobHub> jobHub,
        INotificationService notifications,
        IBackgroundJobClient hangfire,
        IOptions<JobFlowOptions> flowOptions,
        IPlatformSettings settings,
        IConfiguration config,
        ILogger<QuoteService> logger)
    {
        _context = context;
        _jobStatusService = jobStatusService;
        _jobHub = jobHub;
        _notifications = notifications;
        _hangfire = hangfire;
        _flowOptions = flowOptions;
        _settings = settings;
        _config = config;
        _logger = logger;
    }

    // ── Tradie: submit a quote ────────────────────────────────────────────────

    public async Task<QuoteDto> SubmitQuoteAsync(
        int jobId, string tradieId, SubmitQuoteRequest request)
    {
        var job = await _context.Jobs
            .Include(j => j.Quotes)
            .Include(j => j.Offers)
            .FirstOrDefaultAsync(j => j.Id == jobId)
            ?? throw new KeyNotFoundException($"Job {jobId} not found.");

        if (job.JobType != JobType.Project)
            throw new InvalidOperationException("Quotes apply to project jobs only.");

        if (job.Status != JobStatus.Requested)
            throw new InvalidOperationException($"Job is in state '{job.Status}' — quotes can no longer be submitted.");

        // D8: GST-registered tradies price GST-inclusive; unregistered tradies
        // cannot charge GST at all (NZ: under $60k turnover must not register).
        var profile = await _context.TradieProfiles
            .Where(p => p.UserId == tradieId)
            .Select(p => new { p.IsGstRegistered, p.BusinessName, p.IsVerified, p.Location })
            .FirstOrDefaultAsync();
        if (profile == null)
            throw new InvalidOperationException("Tradie profile not found.");

        // Plan 10 (Q7.5): a tradie may quote without an invite when the job is
        // open to the board and within its accepting window.
        // For invite-only jobs, the original offer requirement stands.
        JobOffer? offer = null;
        var now = DateTime.UtcNow;
        var isOpenBoard = job.OpenToBoard && job.QuotesCloseAtUtc.HasValue && job.QuotesCloseAtUtc > now;

        if (isOpenBoard)
        {
            // Check eligibility: tradie must not have already quoted.
            if (job.Quotes.Any(q => q.TradieId == tradieId))
                throw new InvalidOperationException("You have already submitted a quote for this job.");

            // Service offered check: tradie must have a rate for this job's service.
            var offersService = await _context.TradieRates
                .AnyAsync(r => r.TradieProfile.UserId == tradieId && r.ServiceId == job.ServiceId);
            if (!offersService)
                throw new InvalidOperationException("Your profile does not list this job's service.");

            // Radius check: same radius as AvailableJobsService.
            var radiusMetres = _config.GetValue<double>("Matching:RadiusKm", 25.0) * 1000.0;
            if (profile.Location == null || job.Location == null ||
                Geo.HaversineMetres(profile.Location, job.Location) > radiusMetres)
                throw new InvalidOperationException("This job is outside your service area.");

            // Check blocks.
            var blocked = await _context.UserBlocks
                .AnyAsync(b =>
                    (b.BlockerId == job.HomeownerId && b.BlockedId == tradieId) ||
                    (b.BlockerId == tradieId && b.BlockedId == job.HomeownerId));
            if (blocked)
                throw new InvalidOperationException("You cannot quote on this job.");

            // Licence gate: same rule as FindMatchesAsync (Q7.4 / P10-08).
            var service = await _context.Services.FindAsync(job.ServiceId);
            if (service != null && service.RequiresLicence)
            {
                var hasLicence = await _context.TradieCredentials
                    .AnyAsync(c =>
                        c.TradieProfile.UserId == tradieId &&
                        c.Status == CredentialStatus.Approved &&
                        c.Type == CredentialType.License);
                if (!hasLicence)
                    throw new InvalidOperationException(
                        "This job requires a licence credential. Upload your licence and wait for approval.");
            }
        }
        else
        {
            // The tradie must hold a pending QuoteRequest offer for this job.
            offer = job.Offers
                .Where(o => o.TradieId == tradieId
                            && o.Kind == OfferKind.QuoteRequest
                            && o.Response == OfferResponse.Pending)
                .OrderByDescending(o => o.OfferedAtUtc)
                .FirstOrDefault();

            if (offer == null)
            {
                if (job.OpenToBoard && job.QuotesCloseAtUtc.HasValue && job.QuotesCloseAtUtc <= now)
                    throw new InvalidOperationException("The quoting window for this project has closed.");
                throw new InvalidOperationException("You have no pending quote request for this job.");
            }
        }

        if (profile.IsGstRegistered && !request.GstIncluded)
            throw new InvalidOperationException(
                "Your profile shows you are GST-registered — quote prices must be GST-inclusive.");

        if (!profile.IsGstRegistered && request.GstIncluded)
            throw new InvalidOperationException(
                "You are not GST-registered — you cannot charge GST on your quotes.");

        if (!Enum.TryParse<QuotePricingModel>(request.PricingModel, ignoreCase: true, out var pricingModel))
            throw new InvalidOperationException("PricingModel must be Fixed, EstimateRange or HourlyWithCap.");

        // Plan 10 (Q7.1): validity comes from the admin setting (fallback: JobFlow:QuoteWindowHours).
        var windows = await _settings.GetQuoteWindowsAsync();

        var quote = new Quote
        {
            JobId = jobId,
            TradieId = tradieId,
            PricingModel = pricingModel,
            Amount = request.Amount,
            MinAmount = request.MinAmount,
            MaxAmount = request.MaxAmount,
            Cap = request.Cap,
            Inclusions = request.Inclusions,
            Exclusions = request.Exclusions,
            MaterialsIncluded = request.MaterialsIncluded,
            GstIncluded = request.GstIncluded,
            ProposedStartUtc = request.ProposedStartUtc,
            EstimatedDurationDays = request.EstimatedDurationDays,
            ValidUntilUtc = DateTime.UtcNow.AddHours(windows.ValidityHours),
            Status = QuoteStatus.Submitted,
            // OfferId is null for board quotes (Q7.5); invite quotes carry the offer id.
            OfferId = offer?.Id,
            CreatedAtUtc = DateTime.UtcNow,
        };

        _context.Quotes.Add(quote);

        // The quote answers the invite-offer — mark it accepted (not applicable for board quotes).
        if (offer != null)
        {
            offer.Response = OfferResponse.Accepted;
            if (!string.IsNullOrEmpty(offer.HangfireJobId))
            {
                try { _hangfire.Delete(offer.HangfireJobId); }
                catch (Exception ex) { _logger.LogWarning(ex, "Could not cancel quote-request timeout {OfferId}.", offer.Id); }
            }
        }

        await _context.SaveChangesAsync();

        await NotifyUserAsync(job.HomeownerId, "New quote received",
            $"\"{job.Title}\": a tradie submitted a quote. Compare it with the others in the app.",
            new Dictionary<string, string> { ["jobId"] = jobId.ToString(), ["quoteId"] = quote.Id.ToString(), ["type"] = "quote_submitted" });

        return ToDto(quote, job, profile.BusinessName, profile.IsVerified, null);
    }

    // ── Homeowner: list / accept ─────────────────────────────────────────────

    public async Task<List<QuoteDto>> ListQuotesAsync(int jobId, string requestingUserId)
    {
        var job = await _context.Jobs
            .Include(j => j.Quotes).ThenInclude(q => q.Tradie)
            .FirstOrDefaultAsync(j => j.Id == jobId)
            ?? throw new KeyNotFoundException($"Job {jobId} not found.");

        if (job.HomeownerId != requestingUserId && job.MatchedTradieId != requestingUserId)
            throw new UnauthorizedAccessException();

        // Rating + verified badge for the comparison view (P12-24).
        var tradieIds = job.Quotes.Select(q => q.TradieId).Distinct().ToList();
        var profiles = await _context.TradieProfiles
            .Where(p => tradieIds.Contains(p.UserId))
            .ToDictionaryAsync(p => p.UserId);
        var ratings = await _context.Reviews
            .Where(r => tradieIds.Contains(r.RevieweeId))
            .GroupBy(r => r.RevieweeId)
            .Select(g => new { UserId = g.Key, Avg = g.Average(x => (double)x.Rating), Count = g.Count() })
            .ToDictionaryAsync(x => x.UserId, x => (x.Avg, x.Count));

        return job.Quotes
            .OrderByDescending(q => q.CreatedAtUtc)
            .Select(q =>
            {
                profiles.TryGetValue(q.TradieId, out var p);
                (double Avg, int Count)? r = ratings.TryGetValue(q.TradieId, out var rating) ? rating : null;
                return ToDto(q, job, p?.BusinessName, p?.IsVerified ?? false, r);
            })
            .ToList();
    }

    /// <summary>
    /// Accept one quote: declines the others atomically, snapshots the agreed
    /// pricing model onto the job, and books it. When the accepted amount is at
    /// or above the written-contract threshold and the homeowner has not
    /// confirmed a contract, returns null with RequiresContractConfirmation set
    /// on the outcome object instead of booking (P12-25).
    /// </summary>
    public async Task<QuoteAcceptResult> AcceptQuoteAsync(
        int jobId, int quoteId, string homeownerId, AcceptQuoteRequest request)
    {
        var job = await _context.Jobs
            .Include(j => j.Quotes)
            .Include(j => j.Offers)
            .FirstOrDefaultAsync(j => j.Id == jobId)
            ?? throw new KeyNotFoundException($"Job {jobId} not found.");

        if (job.HomeownerId != homeownerId) throw new UnauthorizedAccessException();
        if (job.Status != JobStatus.Requested)
            throw new InvalidOperationException($"Job is in state '{job.Status}' — it can no longer accept quotes.");

        var quote = job.Quotes.FirstOrDefault(q => q.Id == quoteId)
            ?? throw new KeyNotFoundException($"Quote {quoteId} not found.");

        if (quote.Status != QuoteStatus.Submitted)
            throw new InvalidOperationException($"Quote is '{quote.Status}' — only submitted quotes can be accepted.");

        // P12-25: written-contract guardrail, threshold in configuration.
        var headlineAmount = QuoteHeadlineAmount(quote);
        var threshold = _flowOptions.Value.WrittenContractThresholdNzd;
        if (headlineAmount >= threshold && !job.WrittenContractConfirmed)
        {
            if (!request.ConfirmWrittenContract)
            {
                return new QuoteAcceptResult
                {
                    RequiresContractConfirmation = true,
                    ThresholdAmount = threshold,
                    Message = $"A written contract is legally required for residential building work of " +
                              $"${threshold:N0} or more (Building Act s362F). Confirm you have one with this tradie before booking.",
                };
            }
            job.WrittenContractConfirmed = true;
        }

        var acceptedAt = DateTime.UtcNow;
        quote.Status = QuoteStatus.Accepted;
        quote.RespondedAtUtc = acceptedAt;

        // Accept-one-declines-rest (atomic — same SaveChanges below).
        foreach (var other in job.Quotes.Where(q => q.Id != quoteId && q.Status == QuoteStatus.Submitted))
        {
            other.Status = QuoteStatus.Declined;
            other.RespondedAtUtc = acceptedAt;
        }

        // Any still-pending quote-request offers are answered by this decision.
        foreach (var pendingOffer in job.Offers.Where(o => o.Response == OfferResponse.Pending))
        {
            pendingOffer.Response = OfferResponse.Declined;
            if (!string.IsNullOrEmpty(pendingOffer.HangfireJobId))
            {
                try { _hangfire.Delete(pendingOffer.HangfireJobId); }
                catch (Exception ex) { _logger.LogWarning(ex, "Could not cancel offer timeout {OfferId}.", pendingOffer.Id); }
            }
        }

        // Snapshot the agreed pricing model onto the job (P12-23).
        job.AcceptedQuoteId = quote.Id;
        job.AgreedPricingModel = quote.PricingModel;
        job.MatchedTradieId = quote.TradieId;
        job.HourlyRate = quote.PricingModel == QuotePricingModel.HourlyWithCap ? quote.Amount ?? 0m : job.HourlyRate;
        job.EstimatedTotal = quote.PricingModel switch
        {
            QuotePricingModel.Fixed => quote.Amount,
            QuotePricingModel.EstimateRange => quote.MaxAmount ?? quote.MinAmount,
            QuotePricingModel.HourlyWithCap => quote.Cap,
            _ => job.EstimatedTotal,
        };

        await _context.SaveChangesAsync();

        // Requested → Booked (v2 state machine).
        await _jobStatusService.TransitionAsync(jobId, JobStatus.Booked, homeownerId, UserRole.Homeowner,
            note: $"Quote {quote.Id} accepted ({quote.PricingModel}).");

        await _notifications.NotifyAsync(
            NotificationEvents.QuoteAccepted,
            quote.TradieId,
            "Your quote was accepted",
            $"\"{job.Title}\": the homeowner accepted your quote. Chat is now open — agree a start time.",
            new Dictionary<string, string> { ["jobId"] = jobId.ToString(), ["quoteId"] = quote.Id.ToString() });

        var losingTradieIds = await _context.Quotes
            .Where(q => q.JobId == jobId && q.Id != quote.Id && q.Status == QuoteStatus.Declined)
            .Select(q => q.TradieId)
            .Distinct()
            .ToListAsync();
        foreach (var losingTradieId in losingTradieIds)
        {
            await _notifications.NotifyAsync(
                NotificationEvents.QuoteDeclined,
                losingTradieId,
                "Quote not chosen",
                $"Another quote was chosen for \"{job.Title}\".",
                new Dictionary<string, string> { ["jobId"] = jobId.ToString() });
        }

        var acceptedProfile = await _context.TradieProfiles
            .Where(p => p.UserId == quote.TradieId)
            .Select(p => new { p.BusinessName, p.IsVerified })
            .FirstOrDefaultAsync();

        return new QuoteAcceptResult { Quote = ToDto(quote, job, acceptedProfile?.BusinessName, acceptedProfile?.IsVerified ?? false, null) };
    }

    /// <summary>The amount to compare against the written-contract threshold.</summary>
    private static decimal QuoteHeadlineAmount(Quote quote) => quote.PricingModel switch
    {
        QuotePricingModel.Fixed => quote.Amount ?? 0m,
        QuotePricingModel.EstimateRange => quote.MaxAmount ?? quote.MinAmount ?? 0m,
        QuotePricingModel.HourlyWithCap => quote.Cap ?? 0m,
        _ => 0m,
    };

    private QuoteDto ToDto(Quote quote, Job job, string? businessName, bool verified,
        (double Avg, int Count)? rating)
    {
        var firstName = quote.Tradie?.FirstName ?? string.Empty;
        var lastName = quote.Tradie?.LastName ?? string.Empty;
        var f = string.IsNullOrEmpty(firstName) ? "" : firstName[..1].ToUpperInvariant();
        var l = string.IsNullOrEmpty(lastName) ? "" : lastName[..1].ToUpperInvariant();

        return new QuoteDto
        {
            Id = quote.Id,
            JobId = quote.JobId,
            TradieId = quote.TradieId,
            TradieName = string.IsNullOrWhiteSpace(quote.Tradie?.FullName)
                ? quote.TradieId : quote.Tradie.FullName,
            BusinessName = businessName,
            Initials = $"{f}{l}",
            Verified = verified,
            Rating = rating.HasValue ? Math.Round(rating.Value.Avg, 1) : 0,
            ReviewCount = rating?.Count ?? 0,
            PricingModel = quote.PricingModel.ToString(),
            Amount = quote.Amount,
            MinAmount = quote.MinAmount,
            MaxAmount = quote.MaxAmount,
            Cap = quote.Cap,
            Inclusions = quote.Inclusions,
            Exclusions = quote.Exclusions,
            MaterialsIncluded = quote.MaterialsIncluded,
            GstIncluded = quote.GstIncluded,
            ProposedStartUtc = quote.ProposedStartUtc,
            EstimatedDurationDays = quote.EstimatedDurationDays,
            ValidUntilUtc = quote.ValidUntilUtc,
            Status = quote.Status.ToString(),
            CreatedAtUtc = quote.CreatedAtUtc,
        };
    }

    private async Task NotifyUserAsync(string? userId, string title, string body, Dictionary<string, string> data)
    {
        if (string.IsNullOrEmpty(userId)) return;
        await _notifications.SendPushToUserAsync(userId, title, body, data);
    }
}

/// <summary>P12-25: outcome of AcceptQuoteAsync — either a quote, or a contract-confirmation gate.</summary>
public class QuoteAcceptResult
{
    public QuoteDto? Quote { get; set; }

    /// <summary>True when the homeowner must confirm a written contract first (P12-25).</summary>
    public bool RequiresContractConfirmation { get; set; }

    /// <summary>The configured threshold that triggered the gate.</summary>
    public decimal ThresholdAmount { get; set; }

    public string? Message { get; set; }
}
