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
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace FixoApi.Services;

/// <summary>
/// v1.7 (P12-08): the homeowner's chosen tradie is actually the one asked.
///
/// POST /api/jobs/{id}/request creates a <see cref="JobOffer"/> for exactly that
/// tradie, snapshotting the tradie's rate for the job's service at REQUEST time
/// — this fixes the latent bug (spec §3 row 4b) where the mobile client only
/// sent a rate and the backend accepted "some tradie with that rate".
///
/// Expiry is urgency-aware (D7): ~15–30 minutes for ASAP, ~2–4 hours for
/// flexible — both configurable. Decline/timeout leaves the job Requested so
/// the homeowner can pick someone else; no auto-broaden unless they chose
/// Quick match. Hourly jobs keep one pending request at a time; projects may
/// hold up to 3 concurrent QuoteRequest offers (P12-23).
///
/// The optional message is the ONLY pre-acceptance contact channel (D3) — chat
/// stays gated to Booked and later (P5-08 unchanged).
/// </summary>
public class OfferService
{
    private readonly FixoDbContext _context;
    private readonly IJobStatusService _jobStatusService;
    private readonly IHubContext<JobHub> _jobHub;
    private readonly INotificationService _notifications;
    private readonly IBackgroundJobClient _hangfire;
    private readonly IOptions<JobFlowOptions> _flowOptions;
    private readonly ILogger<OfferService> _logger;

    public OfferService(
        FixoDbContext context,
        IJobStatusService jobStatusService,
        IHubContext<JobHub> jobHub,
        INotificationService notifications,
        IBackgroundJobClient hangfire,
        IOptions<JobFlowOptions> flowOptions,
        ILogger<OfferService> logger)
    {
        _context = context;
        _jobStatusService = jobStatusService;
        _jobHub = jobHub;
        _notifications = notifications;
        _hangfire = hangfire;
        _flowOptions = flowOptions;
        _logger = logger;
    }

    /// <summary>
    /// Homeowner asks a specific tradie. Throws <see cref="InvalidOperationException"/>
    /// with a user-safe message on any business-rule violation; returns the
    /// created offer as a DTO.
    /// </summary>
    public async Task<OfferDto> CreateDirectRequestAsync(
        int jobId, string homeownerId, RequestTradieRequest request)
    {
        var job = await _context.Jobs.Include(j => j.Offers).FirstOrDefaultAsync(j => j.Id == jobId)
            ?? throw new KeyNotFoundException($"Job {jobId} not found.");

        if (job.HomeownerId != homeownerId)
            throw new UnauthorizedAccessException();

        if (job.FlowVersion < 2)
            throw new InvalidOperationException("This job was posted under the legacy flow.");

        if (job.Status != JobStatus.Requested)
            throw new InvalidOperationException($"Job is in state '{job.Status}' — it cannot take new requests.");

        if (string.IsNullOrWhiteSpace(request.TradieId))
            throw new InvalidOperationException("tradieId is required.");

        // Hourly: exactly one pending request at a time (existing invariant).
        // Project: up to MaxConcurrentQuoteRequests concurrent QuoteRequests (P12-23).
        var pendingCount = job.Offers.Count(o => o.Response == OfferResponse.Pending);
        if (job.JobType == JobType.Hourly && pendingCount > 0)
            throw new InvalidOperationException(
                "This job already has a pending request. Cancel it or wait for a response before asking someone else.");

        if (job.JobType == JobType.Project && pendingCount >= _flowOptions.Value.MaxConcurrentQuoteRequests)
            throw new InvalidOperationException(
                $"A project can have at most {_flowOptions.Value.MaxConcurrentQuoteRequests} concurrent quote requests.");

        // The chosen tradie must be offerable: verified, available, and carrying
        // a rate for the job's service — the homeowner must see a real price.
        var tradie = await _context.Users.FindAsync(request.TradieId)
            ?? throw new InvalidOperationException("That tradie no longer exists.");

        var rate = await _context.TradieRates
            .Where(r => r.ServiceId == job.ServiceId
                        && r.TradieProfile.UserId == request.TradieId
                        && r.TradieProfile.IsVerified
                        && r.TradieProfile.User.IsActive
                        && r.TradieProfile.IsAvailable)
            .Select(r => (decimal?)r.HourlyRate)
            .FirstOrDefaultAsync()
            ?? throw new InvalidOperationException(
                "That tradie is not available for this service — pick another tradie from the list.");

        // A tradie is offered a given job at most once (unique index backstops).
        if (job.Offers.Any(o => o.TradieId == request.TradieId))
            throw new InvalidOperationException("This tradie was already asked about this job.");

        // D7: urgency-aware, configurable expiry window.
        var windowMinutes = job.Urgency is JobUrgency.High or JobUrgency.Emergency
            ? _flowOptions.Value.AsapOfferWindowMinutes
            : _flowOptions.Value.FlexibleOfferWindowMinutes;

        var kind = job.JobType == JobType.Project ? OfferKind.QuoteRequest : OfferKind.Instant;

        var offer = new JobOffer
        {
            JobId = jobId,
            TradieId = request.TradieId,
            OfferedAtUtc = DateTime.UtcNow,
            ExpiresAtUtc = DateTime.UtcNow.AddMinutes(windowMinutes),
            Response = OfferResponse.Pending,
            Stage = OfferStage.Direct,
            HourlyRateSnapshot = rate,
            Message = string.IsNullOrWhiteSpace(request.Message) ? null : request.Message.Trim(),
            Kind = kind,
        };

        _context.JobOffers.Add(offer);
        await _context.SaveChangesAsync();

        // Hangfire timeout — same engine as quick-match offers (P3-04).
        try
        {
            var hangfireId = _hangfire.Schedule<OfferTimeoutJob>(j => j.ExecuteAsync(offer.Id),
                TimeSpan.FromMinutes(windowMinutes));
            offer.HangfireJobId = hangfireId;
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not schedule timeout for direct request {OfferId}.", offer.Id);
        }

        _logger.LogInformation(
            "Direct request {OfferId}: job {JobId} → tradie {TradieId} (rate={Rate}, kind={Kind}, expires={Expires}).",
            offer.Id, jobId, request.TradieId, rate, kind, offer.ExpiresAtUtc);

        // SignalR to the job group (homeowner screens) + the tradie's user group.
        var payload = new OfferLifecyclePayload
        {
            EventType = "OfferCreated",
            JobId = jobId,
            OfferId = offer.Id,
            TradieId = request.TradieId,
            ExpiresAtUtc = offer.ExpiresAtUtc,
            JobTitle = job.Title,
            OfferIndex = pendingCount + 1,
        };
        await _jobHub.Clients.Group(JobHub.GroupName(jobId)).SendAsync("OfferLifecycleEvent", payload);
        await _jobHub.Clients.User(request.TradieId).SendAsync("OfferLifecycleEvent", payload);

        // FCM push to the tradie (best effort).
        await _notifications.SendPushToUserAsync(
            request.TradieId,
            title: "New job request",
            body: $"{job.Title} — respond in {windowMinutes} minutes.",
            data: new Dictionary<string, string>
            {
                ["jobId"] = jobId.ToString(),
                ["offerId"] = offer.Id.ToString(),
                ["kind"] = kind.ToString(),
            });

        return ToDto(offer, tradie.FullName, job.Title);
    }

    /// <summary>
    /// Tradie accepts an offer. v2 flow: Requested → Booked, copying the rate
    /// snapshot onto the job. v1 legacy jobs keep the old Requested →
    /// AwaitingPayment edge. Returns the accepted offer DTO.
    /// </summary>
    public async Task<OfferDto> AcceptOfferAsync(int jobId, int offerId, string tradieId)
    {
        var offer = await _context.JobOffers
            .Include(o => o.Job)
            .FirstOrDefaultAsync(o => o.Id == offerId && o.JobId == jobId)
            ?? throw new KeyNotFoundException($"Offer {offerId} not found.");

        if (offer.TradieId != tradieId) throw new UnauthorizedAccessException();
        if (offer.Response != OfferResponse.Pending)
            throw new InvalidOperationException($"Offer is already in state '{offer.Response}'.");
        if (offer.Job.Status != JobStatus.Requested)
            throw new InvalidOperationException($"Job is in state '{offer.Job.Status}' — this offer can no longer be accepted.");

        // Cancel the Hangfire timeout — the tradie responded in time.
        if (!string.IsNullOrEmpty(offer.HangfireJobId))
        {
            try { _hangfire.Delete(offer.HangfireJobId); }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Could not cancel timeout job for offer {OfferId}.", offerId);
            }
        }

        offer.Response = OfferResponse.Accepted;
        offer.Job.MatchedTradieId = tradieId;

        // P12-08: the request-time snapshot becomes the job's rate. Legacy v1
        // offers predate the snapshot (0 in the DB) — keep their existing rate.
        if (offer.HourlyRateSnapshot > 0m)
        {
            offer.Job.HourlyRate = offer.HourlyRateSnapshot;
            if (offer.Job.EstimatedHours.HasValue)
            {
                offer.Job.EstimatedTotal = Math.Round(
                    offer.HourlyRateSnapshot * offer.Job.EstimatedHours.Value, 2);
            }
        }

        await _context.SaveChangesAsync();

        if (offer.Job.FlowVersion >= 2)
        {
            // v2: accept books the job directly — payment moves to the end (P12-10).
            await _jobStatusService.TransitionAsync(jobId, JobStatus.Booked, tradieId, UserRole.Tradie);
        }
        else
        {
            // v1 legacy: the old "tradie matched" edge.
            await _jobStatusService.TransitionAsync(jobId, JobStatus.AwaitingPayment, tradieId, UserRole.Tradie);
        }

        _logger.LogInformation(
            "Offer {OfferId} accepted: job {JobId} → {Status} with tradie {TradieId} at rate {Rate}.",
            offerId, jobId, offer.Job.Status, tradieId, offer.HourlyRateSnapshot);

        var lifecycle = new OfferLifecyclePayload
        {
            EventType = "OfferAccepted",
            JobId = jobId,
            OfferId = offerId,
            TradieId = tradieId,
            ExpiresAtUtc = offer.ExpiresAtUtc,
            JobTitle = offer.Job.Title,
        };
        await _jobHub.Clients.Group(JobHub.GroupName(jobId)).SendAsync("OfferLifecycleEvent", lifecycle);
        await _jobHub.Clients.User(tradieId).SendAsync("OfferLifecycleEvent", lifecycle);

        await _notifications.NotifyAsync(
            NotificationEvents.OfferAccepted,
            offer.Job.HomeownerId,
            "Offer accepted",
            $"A tradie accepted your request for \"{offer.Job.Title}\".",
            new Dictionary<string, string> { ["jobId"] = jobId.ToString(), ["offerId"] = offerId.ToString() });

        return ToDto(offer, null, offer.Job.Title);
    }

    /// <summary>
    /// Tradie declines an offer. The job stays Requested so the homeowner can
    /// pick someone else — no auto-broaden (P12-08; quick match is a separate path).
    /// </summary>
    public async Task<OfferDto> DeclineOfferAsync(int jobId, int offerId, string tradieId)
    {
        var offer = await _context.JobOffers
            .Include(o => o.Job)
            .FirstOrDefaultAsync(o => o.Id == offerId && o.JobId == jobId)
            ?? throw new KeyNotFoundException($"Offer {offerId} not found.");

        if (offer.TradieId != tradieId) throw new UnauthorizedAccessException();
        if (offer.Response != OfferResponse.Pending)
            throw new InvalidOperationException($"Offer is already in state '{offer.Response}'.");

        if (!string.IsNullOrEmpty(offer.HangfireJobId))
        {
            try { _hangfire.Delete(offer.HangfireJobId); }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Could not cancel timeout job for offer {OfferId}.", offerId);
            }
        }

        offer.Response = OfferResponse.Declined;
        await _context.SaveChangesAsync();

        _logger.LogInformation(
            "Offer {OfferId} declined by tradie {TradieId}: job {JobId} stays Requested.",
            offerId, tradieId, jobId);

        var lifecycle = new OfferLifecyclePayload
        {
            EventType = "OfferDeclined",
            JobId = jobId,
            OfferId = offerId,
            TradieId = tradieId,
            ExpiresAtUtc = offer.ExpiresAtUtc,
            JobTitle = offer.Job.Title,
        };
        await _jobHub.Clients.Group(JobHub.GroupName(jobId)).SendAsync("OfferLifecycleEvent", lifecycle);
        await _jobHub.Clients.User(tradieId).SendAsync("OfferLifecycleEvent", lifecycle);

        await _notifications.NotifyAsync(
            NotificationEvents.OfferAccepted,
            offer.Job.HomeownerId,
            "Offer accepted",
            $"A tradie accepted your request for \"{offer.Job.Title}\".",
            new Dictionary<string, string> { ["jobId"] = jobId.ToString(), ["offerId"] = offerId.ToString() });

        return ToDto(offer, null, offer.Job.Title);
    }

    private static OfferDto ToDto(JobOffer offer, string? tradieName, string? jobTitle) => new()
    {
        Id = offer.Id,
        JobId = offer.JobId,
        TradieId = offer.TradieId,
        OfferedAtUtc = offer.OfferedAtUtc,
        ExpiresAtUtc = offer.ExpiresAtUtc,
        Response = offer.Response.ToString(),
        Stage = offer.Stage.ToString(),
        Kind = offer.Kind.ToString(),
        HourlyRateSnapshot = offer.HourlyRateSnapshot,
        Message = offer.Message,
        TradieName = tradieName,
        JobTitle = jobTitle,
    };
}
