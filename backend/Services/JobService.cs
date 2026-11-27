using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Hubs;
using FixoApi.Models;
using FixoApi.Options;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using NetTopologySuite.Geometries;
using System.Security.Cryptography;

namespace FixoApi.Services;

/// <summary>
/// Application-layer implementation of <see cref="IJobService"/> (M2-03, M2-04, M2-05, M2-06).
/// 
/// Responsibilities:
///   • CRUD operations with status-machine enforcement
///   • Calls IMatchingService for rule-based tradie selection
///   • Broadcasts every status transition via IHubContext&lt;JobHub&gt;
///   • Sends FCM push via PushNotificationService after SignalR dispatch
/// </summary>
public class JobService : IJobService
{
    private readonly IJobRepository _jobRepo;
    private readonly IMatchingService _matchingService;
    private readonly IHubContext<JobHub> _hub;
    private readonly PushNotificationService _push;
    private readonly FixoDbContext _context;
    private readonly IOptions<JobFlowOptions> _jobFlowOptions;
    private readonly ILogger<JobService> _logger;

    public JobService(
        IJobRepository jobRepo,
        IMatchingService matchingService,
        IHubContext<JobHub> hub,
        PushNotificationService push,
        FixoDbContext context,
        IOptions<JobFlowOptions> jobFlowOptions,
        ILogger<JobService> logger)
    {
        _jobRepo         = jobRepo;
        _matchingService = matchingService;
        _hub             = hub;
        _push            = push;
        _context         = context;
        _jobFlowOptions  = jobFlowOptions;
        _logger          = logger;
    }

    // ── CRUD ──────────────────────────────────────────────────────────────────

    public async Task<JobDto> CreateJobAsync(string homeownerId, CreateJobRequest request)
    {
        var service = await _context.Services.FindAsync(request.ServiceId)
            ?? throw new ArgumentException("The selected service does not exist.");

        // P12-12: a homeowner with an unresolved OverduePayment flag cannot post
        // or request new jobs until staff clear it after payment verification.
        var blocked = await _context.AccountFlags.AnyAsync(f =>
            f.UserId == homeownerId
            && f.Type == AccountFlagType.OverduePayment
            && f.ThresholdHit
            && !f.Resolved);
        if (blocked)
            throw new InvalidOperationException(
                "Your account has an overdue payment. Settle the outstanding job before posting a new one.");

        if (!Enum.TryParse<JobUrgency>(request.Urgency ?? "Medium", ignoreCase: true, out var urgency))
            urgency = JobUrgency.Medium;

        if (!Enum.TryParse<TimingPreference>(request.TimingPreference ?? "Flexible", ignoreCase: true, out var timing))
            timing = TimingPreference.Flexible;

        if (!Enum.TryParse<JobType>(request.JobType ?? "Hourly", ignoreCase: true, out var jobType))
            jobType = JobType.Hourly;

        if (!Enum.TryParse<MaterialsResponsibility>(request.MaterialsBy ?? "Undecided", ignoreCase: true, out var materialsBy))
            materialsBy = MaterialsResponsibility.Undecided;

        Point? location = null;
        if (request.Latitude.HasValue && request.Longitude.HasValue)
            location = new Point(request.Longitude.Value, request.Latitude.Value) { SRID = 4326 };

        // P12-01: the rate check is gone — the rate no longer exists at posting.
        // It is chosen on the Choose-a-Tradie screen and snapshotted onto the
        // offer at request time (P12-08). request.HourlyRate is ignored.
        var job = new Job
        {
            HomeownerId     = homeownerId,
            Title           = request.Title,
            Category        = service.Category,
            Description     = request.Description,
            Urgency         = urgency,
            Status          = JobStatus.Requested,
            Location        = location,
            Address         = request.Address,
            ServiceId       = service.Id,
            TimingPreference = timing,
            ScheduledStartUtc = timing is TimingPreference.SpecificDate or TimingPreference.DateRange
                ? request.ScheduledStartUtc
                : null,
            ScheduledEndUtc = timing == TimingPreference.DateRange ? request.ScheduledEndUtc : null,
            EstimatedHours  = request.EstimatedHours,
            // Display-only estimate (rate × guess is unknown here — estimated
            // total is filled when a quote is accepted or the rate snapshots on accept).
            EstimatedTotal  = null,
            ReferenceCode   = await GenerateReferenceCodeAsync(),
            JobType         = jobType,
            BudgetMin       = jobType == JobType.Project ? request.BudgetMin : null,
            BudgetMax       = jobType == JobType.Project ? request.BudgetMax : null,
            MaterialsBy     = jobType == JobType.Project ? materialsBy : MaterialsResponsibility.Undecided,
            SiteVisitWelcome = jobType == JobType.Project && request.SiteVisitWelcome,
            ScopeNotes      = jobType == JobType.Project ? request.ScopeNotes : null,
            FlowVersion     = Math.Max(1, _jobFlowOptions.Value.Version),
            CreatedAtUtc    = DateTime.UtcNow,
            UpdatedAtUtc    = DateTime.UtcNow,
        };

        var created = await _jobRepo.CreateAsync(job);
        _logger.LogInformation(
            "Job {JobId} created by homeowner {HomeownerId} (type={JobType}, timing={Timing}, flow=v{Flow}).",
            created.Id, homeownerId, created.JobType, created.TimingPreference, created.FlowVersion);
        return MapToDto(created);
    }

    public async Task<JobListResponse> GetJobsForUserAsync(
        string userId, bool isTradie, string? status, int page, int pageSize)
    {
        pageSize = Math.Clamp(pageSize, 1, 50);
        page     = Math.Max(1, page);

        JobStatus? statusFilter = null;
        if (!string.IsNullOrEmpty(status) && Enum.TryParse<JobStatus>(status, ignoreCase: true, out var parsed))
            statusFilter = parsed;

        var (items, total) = await _jobRepo.GetForUserAsync(userId, isTradie, statusFilter, page, pageSize);

        // Plan 10 Q1.2: one grouped read for the whole page, only when it can matter.
        var quoteJobIds = items.Where(j => QuoteCounts.Applies(j, isTradie)).Select(j => j.Id).ToList();
        var quoteCounts = quoteJobIds.Count > 0
            ? await _jobRepo.GetQuoteCountsAsync(quoteJobIds, DateTime.UtcNow)
            : new Dictionary<int, QuoteCountSummary>();

        return new JobListResponse
        {
            Items      = items.Select(j => MapToDto(j, isTradie,
                quoteCounts.TryGetValue(j.Id, out var qc) ? qc : (QuoteCountSummary?)null)).ToList(),
            TotalCount = total,
            Page       = page,
            PageSize   = pageSize,
        };
    }

    public async Task<JobDto?> GetJobByIdAsync(int id, string requestingUserId, bool isTradie)
    {
        var job = await _jobRepo.GetByIdAsync(id, includePhotos: true, includeOffers: true);
        if (job == null) return null;

        // Authorisation: homeowners see their own; tradies see what's matched to them or pending offer.
        var hasPendingOffer = isTradie && job.Offers.Any(o => o.TradieId == requestingUserId && o.Response == OfferResponse.Pending);
        if (isTradie && job.MatchedTradieId != requestingUserId && !hasPendingOffer) return null;
        if (!isTradie && job.HomeownerId     != requestingUserId) return null;

        QuoteCountSummary? quoteCounts = null;
        if (QuoteCounts.Applies(job, isTradie))
        {
            var counts = await _jobRepo.GetQuoteCountsAsync(new[] { job.Id }, DateTime.UtcNow);
            quoteCounts = counts.TryGetValue(job.Id, out var c) ? c : (QuoteCountSummary?)null;
        }
        return MapToDto(job, isTradie, quoteCounts);
    }

    public async Task<bool> UpdateJobAsync(int id, string homeownerId, UpdateJobRequest request)
    {
        var job = await _jobRepo.GetByIdAsync(id);
        if (job == null || job.HomeownerId != homeownerId) return false;

        // Only Draft or Requested jobs can be edited.
        if (job.Status is not (JobStatus.Requested or JobStatus.Requested)) return false;

        if (request.Title       != null) job.Title       = request.Title;
        if (request.Description != null) job.Description = request.Description;
        if (request.Address     != null) job.Address     = request.Address;
        if (request.ScheduledStartUtc.HasValue) job.ScheduledStartUtc = request.ScheduledStartUtc.Value;
        if (request.ScheduledEndUtc.HasValue) job.ScheduledEndUtc = request.ScheduledEndUtc.Value;
        if (request.EstimatedHours.HasValue) job.EstimatedHours = request.EstimatedHours.Value;

        if (!string.IsNullOrEmpty(request.TimingPreference) &&
            Enum.TryParse<TimingPreference>(request.TimingPreference, ignoreCase: true, out var timingPref))
            job.TimingPreference = timingPref;

        if (!string.IsNullOrEmpty(request.Urgency) &&
            Enum.TryParse<JobUrgency>(request.Urgency, ignoreCase: true, out var urgency))
            job.Urgency = urgency;

        if (request.Latitude.HasValue && request.Longitude.HasValue)
            job.Location = new Point(request.Longitude.Value, request.Latitude.Value) { SRID = 4326 };

        await _jobRepo.UpdateAsync(job);
        return true;
    }

    public async Task<bool> CancelJobAsync(int id, string requestingUserId)
    {
        var job = await _jobRepo.GetByIdAsync(id);
        if (job == null) return false;

        // Either party can cancel before InProgress.
        var isOwner  = job.HomeownerId    == requestingUserId;
        var isTradie = job.MatchedTradieId == requestingUserId;
        if (!isOwner && !isTradie) return false;

        if (job.Status is JobStatus.Completed or JobStatus.Cancelled) return false;

        await TransitionStatusAsync(job, JobStatus.Cancelled);
        return true;
    }

    // ── Matching ──────────────────────────────────────────────────────────────

    public async Task<MatchResultDto> RunMatchingAsync(int jobId, string homeownerId)
    {
        var job = await _jobRepo.GetByIdAsync(jobId);
        if (job == null || job.HomeownerId != homeownerId)
            return new MatchResultDto();

        // Transition → Matching
        await TransitionStatusAsync(job, JobStatus.Requested);

        var matches = await _matchingService.FindMatchesAsync(job);

        if (matches.Count == 0)
        {
            _logger.LogInformation("Job {JobId}: no tradies matched", jobId);
            // Stay in Matching state — client will show "No tradies found" after timeout.
            return new MatchResultDto { Matches = matches };
        }

        if (job.FlowVersion >= 2)
        {
            // v1.7 (P12-04): under the pay-at-completion flow the quick-match
            // fallback runs through the sequential offer engine — no instant
            // match-to-AwaitingPayment shortcut anymore. Rate comes from the
            // offer snapshot when a tradie accepts (P12-08).
            return new MatchResultDto { Matches = matches };
        }

        // Legacy v1: transition → Matched (picks the top-ranked tradie as the suggested match)
        job.MatchedTradieId = matches[0].TradieId;
        await TransitionStatusAsync(job, JobStatus.AwaitingPayment);

        // Notify all matched tradies via SignalR + FCM (M2-05, M2-06).
        await NotifyMatchedTradiesAsync(job, matches);

        return new MatchResultDto { Matches = matches };
    }

    public async Task<MatchResultDto> GetMatchesAsync(int jobId, string requestingUserId)
    {
        var job = await _jobRepo.GetByIdAsync(jobId, includePhotos: false);
        if (job == null || job.HomeownerId != requestingUserId)
            return new MatchResultDto();

        var matches = await _matchingService.FindMatchesAsync(job);
        return new MatchResultDto { Matches = matches };
    }

    public async Task<bool> RequestTradieAsync(int jobId, string homeownerId, string tradieId)
    {
        // v1.7 (P12-08): the real direct-request flow moved to
        // POST /api/jobs/{id}/request (OfferService), which snapshots the rate
        // and creates a JobOffer for exactly the chosen tradie. This legacy
        // path only serves v1 in-flight jobs and keeps its old behaviour.
        var job = await _jobRepo.GetByIdAsync(jobId);
        if (job == null || job.HomeownerId != homeownerId) return false;
        if (job.FlowVersion >= 2) return false; // v2 must use the new endpoint
        if (job.Status is not (JobStatus.AwaitingPayment or JobStatus.Requested)) return false;

        job.MatchedTradieId = tradieId;
        await TransitionStatusAsync(job, JobStatus.AwaitingPayment);
        return true;
    }

    public async Task<bool> AcceptJobAsync(int jobId, string tradieId)
    {
        var job = await _jobRepo.GetByIdAsync(jobId);
        if (job == null || job.MatchedTradieId != tradieId) return false;
        if (job.FlowVersion >= 2) return false; // v2 accepts via the offer endpoints
        if (job.Status != JobStatus.AwaitingPayment) return false;

        await TransitionStatusAsync(job, JobStatus.Booked);
        return true;
    }

    public async Task<bool> DeclineJobAsync(int jobId, string tradieId)
    {
        var job = await _jobRepo.GetByIdAsync(jobId);
        if (job == null || job.MatchedTradieId != tradieId) return false;
        if (job.FlowVersion >= 2) return false;
        if (job.Status != JobStatus.AwaitingPayment) return false;

        // Clear matched tradie and go back to Matching so another can be found.
        job.MatchedTradieId = null;
        await TransitionStatusAsync(job, JobStatus.Requested);
        return true;
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /// <summary>
    /// Transitions <paramref name="job"/> to <paramref name="newStatus"/>, persists,
    /// then broadcasts a JobStatusChanged event to the job's SignalR group.
    /// Always call this instead of setting Job.Status directly.
    /// </summary>
    private async Task TransitionStatusAsync(Job job, JobStatus newStatus)
    {
        var prev = job.Status;
        job.Status = newStatus;
        await _jobRepo.UpdateAsync(job);

        _logger.LogInformation("Job {JobId} status: {Prev} → {New}", job.Id, prev, newStatus);

        // Broadcast to any clients subscribed to this job's group.
        await _hub.Clients
            .Group(JobHub.GroupName(job.Id))
            .SendAsync("JobStatusChanged", job.Id, newStatus.ToString());
    }

    /// <summary>
    /// Sends SignalR NewJobMatch then FCM push to each matched tradie (M2-05, M2-06).
    /// FCM failures are logged but never throw — they must not abort the matching flow.
    /// </summary>
    private async Task NotifyMatchedTradiesAsync(Job job, List<TradieMatchDto> matches)
    {
        foreach (var match in matches)
        {
            var payload = new NewJobMatchPayload
            {
                JobId      = job.Id,
                Title      = job.Title,
                Category   = job.Category.ToString(),
                Urgency    = job.Urgency.ToString(),
                Address    = job.Address,
                DistanceKm = match.Distance,
            };

            // SignalR — user-targeted (only this tradie's connections).
            await _hub.Clients
                .User(match.TradieId)
                .SendAsync("NewJobMatch", payload);

            // FCM — fire-and-forget; failures are caught and logged inside SendMulticastAsync.
            _ = SendFcmToTradieAsync(match.TradieId, job);
        }
    }

    private async Task SendFcmToTradieAsync(string tradieId, Job job)
    {
        try
        {
            var tokens = await _context.DeviceTokens
                .Where(dt => dt.UserId == tradieId)
                .Select(dt => dt.Token)
                .ToListAsync();

            if (tokens.Count == 0) return;

            var staleTokens = await _push.SendMulticastAsync(
                tokens,
                title: "New job match",
                body:  $"{job.Category}: {job.Title}",
                data: new Dictionary<string, string>
                {
                    { "jobId",    job.Id.ToString()    },
                    { "category", job.Category.ToString() },
                    { "urgency",  job.Urgency.ToString()  },
                });

            // Clean up stale tokens so we don't retry them.
            if (staleTokens.Count > 0)
            {
                var toRemove = await _context.DeviceTokens
                    .Where(dt => dt.UserId == tradieId && staleTokens.Contains(dt.Token))
                    .ToListAsync();
                _context.DeviceTokens.RemoveRange(toRemove);
                await _context.SaveChangesAsync();
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "FCM dispatch failed for tradie {TradieId} job {JobId}", tradieId, job.Id);
            // Deliberately swallowed — push failure must not break the matching flow.
        }
    }

    // ── Mapping ───────────────────────────────────────────────────────────────

    private async Task<string> GenerateReferenceCodeAsync()
    {
        const string alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        const int length = 8;

        for (var attempt = 0; attempt < 10; attempt++)
        {
            var bytes = RandomNumberGenerator.GetBytes(length);
            var code = string.Concat(bytes.Select(b => alphabet[b % alphabet.Length]));
            if (!await _context.Jobs.AnyAsync(job => job.ReferenceCode == code))
                return code;
        }

        throw new InvalidOperationException("Could not generate a unique job reference code.");
    }

    private JobDto MapToDto(Job job, bool isTradie = false, QuoteCountSummary? quoteCounts = null)
    {
        var flow = _jobFlowOptions.Value;
        // P12-15: stage mapping follows the stepper order for the flow the job
        // runs under. v2: Requested → Booked → In progress → Review & approve →
        // Pay → Completed. v1 keeps the legacy upfront-payment mapping.
        var stage = job.FlowVersion >= 2
            ? job.Status switch
            {
                JobStatus.Requested            => 0,
                JobStatus.Booked               => 1,
                JobStatus.InProgress           => 2,
                JobStatus.AwaitingConfirmation => 3, // Review & approve
                JobStatus.AwaitingPayment      => 4, // Pay
                JobStatus.PaymentReview        => 4, // Pay (receipt queued)
                JobStatus.Completed            => 5,
                _                              => 0,
            }
            : job.Status switch
            {
                JobStatus.Requested          => 0,
                JobStatus.AwaitingPayment    => 1,
                JobStatus.PaymentReview      => 1,
                JobStatus.Booked             => 2,
                JobStatus.InProgress         => 3,
                JobStatus.AwaitingConfirmation => 4,
                JobStatus.Completed          => 5,
                _                            => 0,
            };

        // Extract suburb as the first comma-separated segment of the address.
        var suburb = job.Address?.Split(',').FirstOrDefault()?.Trim() ?? "";

        // P5-01: Address privacy - mask exact address for tradies before Booked
        var showFullAddress = !isTradie || job.Status >= JobStatus.Booked;
        var addressToShow = showFullAddress ? job.Address : suburb;
        var latToShow = showFullAddress ? job.Location?.Y : null;
        var lngToShow = showFullAddress ? job.Location?.X : null;

        // P12-11: the "higher than estimate" banner flag, computed server-side
        // from the same money math the auto-approve guard uses.
        var aboveTolerance = job.FinalAmount.HasValue &&
            JobMoney.ExceedsTolerance(
                job.FinalAmount.Value, job.EstimatedTotal,
                flow.EstimateTolerancePercent, flow.AutoApproveNoEstimateCap);

        return new JobDto
        {
            Id               = job.Id,
            HomeownerId      = job.HomeownerId,
            Title            = job.Title,
            Category         = job.Category.ToString(),
            Description      = job.Description,
            Urgency          = job.Urgency.ToString(),
            Status           = job.Status.ToString(),
            Address          = addressToShow,
            Suburb           = suburb,
            Latitude         = latToShow,
            Longitude        = lngToShow,
            CreatedAtUtc     = job.CreatedAtUtc,
            UpdatedAtUtc     = job.UpdatedAtUtc,
            ServiceId        = job.ServiceId,
            TimingPreference = job.TimingPreference.ToString(),
            ScheduledStartUtc = job.ScheduledStartUtc,
            ScheduledEndUtc  = job.ScheduledEndUtc,
            EstimatedHours   = job.EstimatedHours,
            HourlyRate       = job.HourlyRate,
            EstimatedTotal   = job.EstimatedTotal,
            FinalHours       = job.FinalHours,
            LabourAmount     = job.LabourAmount,
            AdjustmentsTotal = job.AdjustmentsTotal,
            FinalAmount      = job.FinalAmount,
            CompletionSubmittedAtUtc = job.CompletionSubmittedAtUtc,
            JobType          = job.JobType.ToString(),
            AgreedPricingModel = job.AgreedPricingModel?.ToString(),
            FlowVersion      = job.FlowVersion,
            IsAboveEstimateTolerance = aboveTolerance,
            ReferenceCode    = job.ReferenceCode,
            MatchedTradieId  = job.MatchedTradieId,
            MatchedTradieName = string.IsNullOrWhiteSpace(job.MatchedTradie?.FullName) ? null : job.MatchedTradie.FullName,
            DisputeStatus    = job.DisputeStatus,
            Stage            = stage,
            QuotesRequested  = quoteCounts?.Requested,
            QuotesReceived   = quoteCounts?.Received,
            Photos           = job.Photos.Select(p => new JobPhotoDto
            {
                Id               = p.Id,
                Url              = BuildPhotoUrl(p.BlobKey),
                OriginalFileName = p.OriginalFileName,
            }).ToList(),
        };
    }

    /// <summary>
    /// In production this would generate a read-SAS URL via the blob client.
    /// For now return a relative path the Flutter client can resolve.
    /// </summary>
    private static string BuildPhotoUrl(string blobKey) =>
        $"/api/photos/{blobKey}";
}
