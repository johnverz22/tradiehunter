using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Hubs;
using FixoApi.Jobs;
using FixoApi.Models;
using FixoApi.Services;
using Hangfire;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace FixoApi.Controllers;

/// <summary>
/// Handles tradie responses to job offers (P3-07; v1.7 P12-08).
///
/// POST /api/jobs/{id}/offers/{offerId}/respond
///
/// Controller purity: only validates auth + ownership, then delegates to
/// OfferService (v2: accept books the job with the rate snapshot) or the
/// legacy sequential path (v1). No direct state-machine logic here.
/// </summary>
[ApiController]
[Route("api/jobs")]
[Authorize]
public class OffersController : ControllerBase
{
    private readonly FixoDbContext _context;
    private readonly IJobStatusService _jobStatusService;
    private readonly OfferService _offerService;
    private readonly IHubContext<JobHub> _jobHub;
    private readonly IBackgroundJobClient _hangfire;
    private readonly ILogger<OffersController> _logger;

    public OffersController(
        FixoDbContext context,
        IJobStatusService jobStatusService,
        OfferService offerService,
        IHubContext<JobHub> jobHub,
        IBackgroundJobClient hangfire,
        ILogger<OffersController> logger)
    {
        _context          = context;
        _jobStatusService = jobStatusService;
        _offerService     = offerService;
        _jobHub           = jobHub;
        _hangfire         = hangfire;
        _logger           = logger;
    }

    // ── GET /api/jobs/{id}/offers/pending ───────────────────────────────────

    /// <summary>
    /// Returns the calling tradie's pending offer for a job, or the job's current
    /// pending offer for the owning homeowner. The tradie request-detail screen (P3-08)
    /// uses this to render the expiry countdown against <c>ExpiresAtUtc</c>.
    /// </summary>
    [HttpGet("{jobId:int}/offers/pending")]
    public async Task<IActionResult> GetPendingOffer(int jobId)
    {
        var userId = User.FindFirstValue("sub") ?? User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (userId == null) return Unauthorized();

        var job = await _context.Jobs.FindAsync(jobId);
        if (job == null) return NotFound();

        JobOffer? offer;
        if (User.IsInRole("Tradie"))
        {
            offer = await _context.JobOffers
                .Where(o => o.JobId == jobId
                    && o.TradieId == userId
                    && o.Response == OfferResponse.Pending)
                .OrderByDescending(o => o.OfferedAtUtc)
                .FirstOrDefaultAsync();
        }
        else if (job.HomeownerId == userId)
        {
            offer = await _context.JobOffers
                .Where(o => o.JobId == jobId
                    && o.Response == OfferResponse.Pending)
                .OrderByDescending(o => o.OfferedAtUtc)
                .FirstOrDefaultAsync();
        }
        else
        {
            return Forbid();
        }

        if (offer == null) return NoContent();

        // v1.7: surface who was asked, at what rate, with the optional message.
        string? tradieName = null;
        if (User.IsInRole("Homeowner") || !User.IsInRole("Tradie"))
        {
            tradieName = await _context.Users
                .Where(u => u.Id == offer.TradieId)
                .Select(u => u.FirstName + " " + u.LastName)
                .FirstOrDefaultAsync();
        }

        return Ok(new OfferDto
        {
            Id           = offer.Id,
            JobId        = offer.JobId,
            TradieId     = offer.TradieId,
            OfferedAtUtc = offer.OfferedAtUtc,
            ExpiresAtUtc = offer.ExpiresAtUtc,
            Response     = offer.Response.ToString(),
            Stage        = offer.Stage.ToString(),
            Kind         = offer.Kind.ToString(),
            HourlyRateSnapshot = offer.HourlyRateSnapshot,
            Message      = offer.Message,
            TradieName   = string.IsNullOrWhiteSpace(tradieName) ? null : tradieName.Trim(),
            JobTitle     = offer.Job?.Title,
        });
    }

    // ── POST /api/jobs/{id}/offers/{offerId}/respond ──────────────────────────

    /// <summary>
    /// Tradie accepts or declines a pending offer.
    /// </summary>
    [HttpPost("{jobId:int}/offers/{offerId:int}/respond")]
    public async Task<IActionResult> RespondToOffer(
        int jobId, int offerId, [FromBody] RespondToOfferRequest request)
    {
        var userId = User.FindFirstValue("sub") ?? User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (userId == null) return Unauthorized();

        if (!User.IsInRole("Tradie")) return Forbid();

        if (string.IsNullOrWhiteSpace(request.Response))
            return BadRequest(new { error = "Response is required." });

        if (!Enum.TryParse<OfferResponse>(request.Response, ignoreCase: true, out var parsedResponse)
            || parsedResponse is not (OfferResponse.Accepted or OfferResponse.Declined))
        {
            return BadRequest(new { error = "Response must be 'Accepted' or 'Declined'." });
        }

        var offer = await _context.JobOffers
            .Include(o => o.Job)
            .FirstOrDefaultAsync(o => o.Id == offerId && o.JobId == jobId);

        if (offer == null) return NotFound();

        // Only the addressed tradie may respond.
        if (offer.TradieId != userId) return Forbid();

        if (offer.Response != OfferResponse.Pending)
            return Conflict(new { error = $"Offer is already in state '{offer.Response}'." });

        // Cancel the Hangfire timeout job since the tradie responded in time (P3-07 AC).
        if (!string.IsNullOrEmpty(offer.HangfireJobId))
        {
            try { _hangfire.Delete(offer.HangfireJobId); }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Could not cancel Hangfire job {HangfireJobId} for offer {OfferId}.",
                    offer.HangfireJobId, offerId);
            }
        }

        offer.Response = parsedResponse;
        await _context.SaveChangesAsync();

        _logger.LogInformation(
            "Offer {OfferId} for job {JobId}: tradie {TradieId} responded {Response}.",
            offerId, jobId, userId, parsedResponse);

        // Emit SignalR lifecycle event for homeowner + this tradie (P3-10).
        var eventType = parsedResponse == OfferResponse.Accepted ? "OfferAccepted" : "OfferDeclined";
        var lifeCyclePayload = new OfferLifecyclePayload
        {
            EventType    = eventType,
            JobId        = jobId,
            OfferId      = offerId,
            TradieId     = userId,
            ExpiresAtUtc = offer.ExpiresAtUtc,
            JobTitle     = offer.Job.Title,
        };
        await _jobHub.Clients.Group(JobHub.GroupName(jobId))
            .SendAsync("OfferLifecycleEvent", lifeCyclePayload);

        try
        {
            if (parsedResponse == OfferResponse.Accepted)
            {
                // v2 (P12-08/P12-10): accept books the job with the rate snapshot.
                // v1 legacy jobs keep the old Requested → AwaitingPayment path
                // (OfferService routes on the job's stored FlowVersion).
                var dto = await _offerService.AcceptOfferAsync(jobId, offerId, userId);
                return Ok(dto);
            }

            // Declined (P12-08): the job stays Requested so the homeowner can
            // pick someone else — no auto-broaden on direct requests. Quick
            // match offers keep the sequential dispatch.
            var isQuickMatch = offer.Stage != OfferStage.Direct;
            var legacy = await _context.Jobs.Where(j => j.Id == jobId).Select(j => j.FlowVersion).FirstAsync();
            if (isQuickMatch || legacy < 2)
            {
                _hangfire.Enqueue<SendOfferJob>(j => j.ExecuteAsync(jobId, userId));
            }

            return Ok(ToDto(offer));
        }
        catch (InvalidOperationException ex)
        {
            // Job left Requested between dispatch and response (e.g. the
            // homeowner cancelled). The response is already recorded, so report
            // the conflict rather than a 500.
            _logger.LogWarning(ex,
                "Offer {OfferId}: cannot process — job {JobId} is not awaiting a match.",
                offerId, jobId);
            return Conflict(new { error = ex.Message });
        }
    }

    private static OfferDto ToDto(JobOffer offer) => new()
    {
        Id           = offer.Id,
        JobId        = offer.JobId,
        TradieId     = offer.TradieId,
        OfferedAtUtc = offer.OfferedAtUtc,
        ExpiresAtUtc = offer.ExpiresAtUtc,
        Response     = offer.Response.ToString(),
        Stage        = offer.Stage.ToString(),
        Kind         = offer.Kind.ToString(),
        HourlyRateSnapshot = offer.HourlyRateSnapshot,
        Message      = offer.Message,
    };
}
