using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Hubs;
using FixoApi.Services;
using Hangfire;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace FixoApi.Jobs;

/// <summary>
/// Hangfire background job that fires when a job offer expires (P3-04).
///
/// If the offer is still Pending when this runs, it marks it as TimedOut,
/// emits the OfferExpired lifecycle event (P3-10), and triggers the next
/// sequential offer via <see cref="IMatchingService"/>. The job is idempotent
/// — a second call after the offer has already been answered is a no-op.
/// </summary>
public class OfferTimeoutJob
{
    private readonly FixoDbContext _context;
    private readonly IMatchingService _matching;
    private readonly IHubContext<JobHub> _jobHub;
    private readonly ILogger<OfferTimeoutJob> _logger;

    // The system user ID used when performing automated status transitions.
    internal const string SystemUserId = "system";

    public OfferTimeoutJob(
        FixoDbContext context,
        IMatchingService matching,
        IHubContext<JobHub> jobHub,
        ILogger<OfferTimeoutJob> logger)
    {
        _context  = context;
        _matching = matching;
        _jobHub   = jobHub;
        _logger   = logger;
    }

    /// <summary>
    /// Called by Hangfire at offer expiry. Safe to call multiple times.
    /// </summary>
    [AutomaticRetry(Attempts = 0)] // Do not retry — side-effects must fire exactly once.
    public async Task ExecuteAsync(int offerId)
    {
        var offer = await _context.JobOffers
            .Include(o => o.Job)
            .FirstOrDefaultAsync(o => o.Id == offerId);

        if (offer == null)
        {
            _logger.LogWarning("OfferTimeoutJob: offer {OfferId} not found — skipping.", offerId);
            return;
        }

        if (offer.Response != OfferResponse.Pending)
        {
            _logger.LogInformation(
                "OfferTimeoutJob: offer {OfferId} already in state {State} — skipping.",
                offerId, offer.Response);
            return;
        }

        offer.Response = OfferResponse.TimedOut;
        await _context.SaveChangesAsync();

        _logger.LogInformation(
            "OfferTimeoutJob: offer {OfferId} for job {JobId} timed out. Triggering next offer.",
            offerId, offer.JobId);

        // Tell the homeowner the tradie did not answer in time, and tell the
        // tradie the offer is gone so their screen stops counting down (P3-10).
        var payload = new OfferLifecyclePayload
        {
            EventType    = "OfferExpired",
            JobId        = offer.JobId,
            OfferId      = offer.Id,
            TradieId     = offer.TradieId,
            ExpiresAtUtc = offer.ExpiresAtUtc,
            JobTitle     = offer.Job.Title,
        };
        await _jobHub.Clients.Group(JobHub.GroupName(offer.JobId))
            .SendAsync("OfferLifecycleEvent", payload);
        await _jobHub.Clients.User(offer.TradieId)
            .SendAsync("OfferLifecycleEvent", payload);

        // Trigger the next sequential offer (P3-04 AC: triggers next ranked tradie).
        await _matching.SendNextOfferAsync(offer.JobId, SystemUserId);
    }
}
