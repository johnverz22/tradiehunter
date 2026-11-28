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
            throw new BusinessRuleException("legacy_flow", "This job was posted under the legacy flow.");

        if (job.Status != JobStatus.Requested)
            throw new BusinessRuleException("job_not_requestable", $"Job is in state '{job.Status}' — it cannot take new requests.");

        if (string.IsNullOrWhiteSpace(request.TradieId))
            throw new BusinessRuleException("validation_error", "tradieId is required.");

        // Re-contact rules (P1 QA §2B) — evaluated BEFORE the pending-count guard so
        // idempotent double-taps are short-circuited before hitting the "one at a time" limit.
        //  • Existing Pending offer for THIS tradie → idempotent: return it immediately.
        //  • Declined → blocked ("tradie_already_declined").
        //  • Withdrawn or TimedOut → allow a fresh re-ask (falls through to new-offer creation below).
        var existingForTradie = job.Offers.FirstOrDefault(o => o.TradieId == request.TradieId);
        if (existingForTradie != null)
        {
            if (existingForTradie.Response == OfferResponse.Pending)
            {
                // Idempotent double-tap: load the tradie name and return existing offer.
                var tradie2 = await _context.Users.FindAsync(request.TradieId);
                var tradieName2 = tradie2 != null ? (tradie2.FirstName + " " + tradie2.LastName).Trim() : "";
                return ToDto(existingForTradie, tradieName2, job.Title);
            }
            if (existingForTradie.Response == OfferResponse.Declined)
                throw new BusinessRuleException(
                    "tradie_already_declined",
                    "This tradie already declined this job — pick someone else.");
            // Withdrawn or TimedOut: proceed — the filtered unique index permits a new row.
        }

        // Hourly: exactly one pending request at a time (existing invariant).
        // Project: up to MaxConcurrentQuoteRequests concurrent QuoteRequests (P12-23).
        var pendingCount = job.Offers.Count(o => o.Response == OfferResponse.Pending);
        if (job.JobType == JobType.Hourly && pendingCount > 0)
            throw new BusinessRuleException(
                "pending_request_exists",
                "This job already has a pending request. Cancel it or wait for a response before asking someone else.");

        if (job.JobType == JobType.Project && pendingCount >= _flowOptions.Value.MaxConcurrentQuoteRequests)
            throw new BusinessRuleException(
                "pending_request_exists",
                $"A project can have at most {_flowOptions.Value.MaxConcurrentQuoteRequests} concurrent quote requests.");

        // The chosen tradie must be offerable: verified, available, and carrying
        // a rate for the job's service — the homeowner must see a real price.
        var tradie = await _context.Users.FindAsync(request.TradieId)
            ?? throw new BusinessRuleException("tradie_unreachable", "That tradie no longer exists.");

        var rate = await _context.TradieRates
            .Where(r => r.ServiceId == job.ServiceId
                        && r.TradieProfile.UserId == request.TradieId
                        && r.TradieProfile.IsVerified
                        && r.TradieProfile.User.IsActive
                        && r.TradieProfile.IsAvailable)
            .Select(r => (decimal?)r.HourlyRate)
            .FirstOrDefaultAsync()
            ?? throw new BusinessRuleException(
                "tradie_unreachable",
                "That tradie is not available for this service — pick another tradie from the list.");

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
                [PushNotificationService.ChannelKey] = PushNotificationService.IncomingRequestsChannel,
                ["expiresAtUtc"] = offer.ExpiresAtUtc.ToString("O"),
            });

        return ToDto(offer, tradie.FullName, job.Title);
    }

    /// <summary>
    /// Tradie accepts an offer. v2 flow: Requested → Booked, copying the rate
    /// snapshot onto the job. v1 legacy jobs keep the old Requested →
    /// AwaitingPayment edge. Returns the accepted offer DTO.
    /// </summary>
    /// <summary>
    /// Tradie accepts an offer. v2 flow: Requested → Booked, copying the rate
    /// snapshot onto the job. v1 legacy jobs keep the old Requested →
    /// AwaitingPayment edge. Returns the accepted offer DTO.
    ///
    /// Atomicity (P1 QA §2A): a conditional ExecuteUpdate claims the offer
    /// atomically, so two racing accepts can never both succeed. The loser gets
    /// a 0-row result and receives a typed 409 (offer_not_pending).
    /// </summary>
    public async Task<OfferDto> AcceptOfferAsync(int jobId, int offerId, string tradieId)
    {
        // 1. Atomic claim: flip Pending → Accepted in one conditional UPDATE.
        //    Zero rows updated means someone else already claimed it.
        var now = DateTime.UtcNow;
        int claimed;
        if (_context.Database.IsRelational())
        {
            claimed = await _context.JobOffers
                .Where(o => o.Id == offerId
                         && o.JobId == jobId
                         && o.TradieId == tradieId
                         && o.Response == OfferResponse.Pending
                         && o.ExpiresAtUtc > now)
                .ExecuteUpdateAsync(s => s.SetProperty(o => o.Response, OfferResponse.Accepted));
        }
        else
        {
            // InMemory provider (unit tests) does not support ExecuteUpdateAsync.
            var candidate = await _context.JobOffers
                .FirstOrDefaultAsync(o => o.Id == offerId
                                       && o.JobId == jobId
                                       && o.TradieId == tradieId
                                       && o.Response == OfferResponse.Pending
                                       && o.ExpiresAtUtc > now);
            if (candidate != null)
            {
                candidate.Response = OfferResponse.Accepted;
                await _context.SaveChangesAsync();
                claimed = 1;
            }
            else
            {
                claimed = 0;
            }
        }

        if (claimed == 0)
        {
            // Load to give a typed error; throw typed so controller maps it correctly.
            var stale = await _context.JobOffers
                .Include(o => o.Job)
                .FirstOrDefaultAsync(o => o.Id == offerId && o.JobId == jobId)
                ?? throw new KeyNotFoundException($"Offer {offerId} not found.");
            if (stale.TradieId != tradieId) throw new UnauthorizedAccessException();
            if (stale.ExpiresAtUtc <= now)
                throw new BusinessRuleException("offer_expired", "This offer has expired — it can no longer be accepted.");
            if (stale.Job.Status != JobStatus.Requested)
                throw new BusinessRuleException(
                    stale.Job.Status == JobStatus.Booked ? "job_already_booked" : "job_not_requestable",
                    $"Job is in state '{stale.Job.Status}' — this offer can no longer be accepted.");
            throw new BusinessRuleException("offer_not_pending", $"Offer is already in state '{stale.Response}'.");
        }

        // 2. Reload the full offer + job now that we own it.
        var offer = await _context.JobOffers
            .Include(o => o.Job)
            .FirstAsync(o => o.Id == offerId);

        // 3. Cancel the Hangfire timeout.
        if (!string.IsNullOrEmpty(offer.HangfireJobId))
        {
            try { _hangfire.Delete(offer.HangfireJobId); }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Could not cancel timeout job for offer {OfferId}.", offerId);
            }
        }

        // 4. Apply rate snapshot to job (P12-08).
        offer.Job.MatchedTradieId = tradieId;
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

        // 5. Transition job status (this will also close any sibling offers via
        //    CloseOrphanedOffersAsync which TransitionAsync calls on Booked/Cancelled).
        if (offer.Job.FlowVersion >= 2)
        {
            await _jobStatusService.TransitionAsync(jobId, JobStatus.Booked, tradieId, UserRole.Tradie);
        }
        else
        {
            await _jobStatusService.TransitionAsync(jobId, JobStatus.AwaitingPayment, tradieId, UserRole.Tradie);
        }

        _logger.LogInformation(
            "Offer {OfferId} accepted: job {JobId} → {Status} with tradie {TradieId} at rate {Rate}.",
            offerId, jobId, offer.Job.Status, tradieId, offer.HourlyRateSnapshot);

        // 6. SignalR + notifications.
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

        // Notify homeowner: the job is booked (not "declined" — fixed copy-paste bug).
        var data = new Dictionary<string, string>
        {
            ["jobId"] = jobId.ToString(),
            ["offerId"] = offerId.ToString(),
        };
        await _notifications.NotifyAsync(
            NotificationEvents.OfferAccepted,
            offer.Job.HomeownerId,
            "Tradie accepted!",
            $"Your request for \"{offer.Job.Title}\" was accepted — the job is now booked.",
            data);
        await _notifications.NotifyAsync(
            NotificationEvents.OfferAccepted,
            tradieId,
            "Job booked",
            $"You accepted the request for \"{offer.Job.Title}\".",
            data);

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
            throw new BusinessRuleException("offer_not_pending", $"Offer is already in state '{offer.Response}'.");

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
            NotificationEvents.OfferDeclined,
            offer.Job.HomeownerId,
            "Request declined",
            $"The tradie declined your request for \"{offer.Job.Title}\" — pick someone else.",
            new Dictionary<string, string> { ["jobId"] = jobId.ToString(), ["offerId"] = offerId.ToString() });
        // Also notify the tradie so their screen confirms the decline was recorded.
        await _notifications.NotifyAsync(
            NotificationEvents.OfferDeclined,
            tradieId,
            "Request declined",
            $"You declined the request for \"{offer.Job.Title}\".",
            new Dictionary<string, string> { ["jobId"] = jobId.ToString(), ["offerId"] = offerId.ToString() });

        return ToDto(offer, null, offer.Job.Title);
    }

    /// <summary>
    /// Homeowner withdraws their pending direct request (P1 QA §2A/2D).
    /// The tradie gets a push/SignalR close event; the job stays Requested
    /// so the homeowner can pick someone else.
    /// </summary>
    public async Task<OfferDto> WithdrawOfferAsync(int jobId, int offerId, string homeownerId)
    {
        var offer = await _context.JobOffers
            .Include(o => o.Job)
            .FirstOrDefaultAsync(o => o.Id == offerId && o.JobId == jobId)
            ?? throw new KeyNotFoundException($"Offer {offerId} not found.");

        if (offer.Job.HomeownerId != homeownerId) throw new UnauthorizedAccessException();
        if (offer.Response != OfferResponse.Pending)
            throw new BusinessRuleException("offer_not_pending",
                $"Offer is already in state '{offer.Response}' — it cannot be withdrawn.");

        if (!string.IsNullOrEmpty(offer.HangfireJobId))
        {
            try { _hangfire.Delete(offer.HangfireJobId); }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Could not cancel timeout job for offer {OfferId}.", offerId);
            }
        }

        offer.Response = OfferResponse.Withdrawn;
        await _context.SaveChangesAsync();

        _logger.LogInformation(
            "Offer {OfferId} withdrawn by homeowner {UserId}: job {JobId} stays Requested.",
            offerId, homeownerId, jobId);

        var lifecycle = new OfferLifecyclePayload
        {
            EventType = "OfferWithdrawn",
            JobId = jobId,
            OfferId = offerId,
            TradieId = offer.TradieId,
            ExpiresAtUtc = offer.ExpiresAtUtc,
            JobTitle = offer.Job.Title,
        };
        await _jobHub.Clients.Group(JobHub.GroupName(jobId)).SendAsync("OfferLifecycleEvent", lifecycle);
        await _jobHub.Clients.User(offer.TradieId).SendAsync("OfferLifecycleEvent", lifecycle);

        var data = new Dictionary<string, string>
        {
            ["jobId"] = jobId.ToString(),
            ["offerId"] = offerId.ToString(),
        };
        await _notifications.NotifyAsync(
            NotificationEvents.OfferWithdrawn,
            offer.TradieId,
            "Request withdrawn",
            $"The homeowner withdrew their request for \"{offer.Job.Title}\".",
            data);

        return ToDto(offer, null, offer.Job.Title);
    }

    /// <summary>
    /// Closes all Pending offers on a job that are not the winning offer (P1 QA §2A/2C).
    /// Called by JobStatusService when a job leaves the Requested state (Booked or Cancelled/Expired).
    /// Each affected tradie receives a SignalR event and a push notification.
    ///
    /// <paramref name="closeAs"/>: use <see cref="OfferResponse.Superseded"/> when another tradie
    /// was booked, <see cref="OfferResponse.JobClosed"/> when the job is cancelled or expired.
    /// <paramref name="winnerOfferId"/>: exclude this offer ID from closing (the accepted offer).
    /// </summary>
    public async Task CloseOrphanedOffersAsync(
        int jobId,
        OfferResponse closeAs,
        int? winnerOfferId,
        CancellationToken ct = default)
    {
        var orphans = await _context.JobOffers
            .Include(o => o.Job)
            .Where(o => o.JobId == jobId
                     && o.Response == OfferResponse.Pending
                     && (winnerOfferId == null || o.Id != winnerOfferId.Value))
            .ToListAsync(ct);

        if (orphans.Count == 0) return;

        var closingEventType = closeAs == OfferResponse.Superseded ? "OfferSuperseded" : "OfferClosed";
        var notifEvent = closeAs == OfferResponse.Superseded
            ? NotificationEvents.OfferSuperseded
            : NotificationEvents.OfferExpired;  // JobClosed reuses OfferExpired (closest semantic)
        var notifTitle = closeAs == OfferResponse.Superseded
            ? "Job taken"
            : "Request closed";

        foreach (var offer in orphans)
        {
            offer.Response = closeAs;

            if (!string.IsNullOrEmpty(offer.HangfireJobId))
            {
                try { _hangfire.Delete(offer.HangfireJobId); }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Could not cancel timeout for orphaned offer {OfferId}.", offer.Id);
                }
            }
        }
        await _context.SaveChangesAsync(ct);

        foreach (var offer in orphans)
        {
            var payload = new OfferLifecyclePayload
            {
                EventType = closingEventType,
                JobId = jobId,
                OfferId = offer.Id,
                TradieId = offer.TradieId,
                ExpiresAtUtc = offer.ExpiresAtUtc,
                JobTitle = offer.Job?.Title,
            };
            await _jobHub.Clients.User(offer.TradieId).SendAsync("OfferLifecycleEvent", payload, ct);

            var notifBody = closeAs == OfferResponse.Superseded
                ? $"Another tradie accepted the job \"{offer.Job?.Title}\"."
                : $"The job \"{offer.Job?.Title}\" is no longer available.";
            await _notifications.NotifyAsync(
                notifEvent,
                offer.TradieId,
                notifTitle,
                notifBody,
                new Dictionary<string, string> { ["jobId"] = jobId.ToString(), ["offerId"] = offer.Id.ToString() },
                ct: ct);
        }

        _logger.LogInformation(
            "CloseOrphanedOffers: closed {Count} pending offers on job {JobId} as {CloseAs}.",
            orphans.Count, jobId, closeAs);
    }

    /// <summary>
    /// Every live offer waiting on <paramref name="tradieId"/> across all jobs
    /// (QA plan §3). Feeds the tradie's incoming-request alert on cold start,
    /// resume and reconnect, so offers missed while the app was closed still
    /// surface. Only Pending offers that have not passed <c>ExpiresAtUtc</c> on
    /// jobs still in Requested are returned, earliest expiry first.
    /// </summary>
    public async Task<List<OfferDto>> GetPendingForTradieAsync(string tradieId)
    {
        var now = DateTime.UtcNow;
        var offers = await _context.JobOffers
            .Include(o => o.Job)
            .Where(o => o.TradieId == tradieId
                && o.Response == OfferResponse.Pending
                && o.ExpiresAtUtc > now
                && o.Job.Status == JobStatus.Requested)
            .OrderBy(o => o.ExpiresAtUtc)
            .ToListAsync();

        return offers.Select(o => ToDto(o, null, o.Job.Title)).ToList();
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
