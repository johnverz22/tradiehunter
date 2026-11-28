using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Hubs;
using FixoApi.Models;
using FixoApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace FixoApi.Controllers;

/// <summary>
/// Handles tradie responses to job offers (P3-07; v1.7 P12-08).
///
/// Endpoints:
///   GET  /api/jobs/{id}/offers/pending          — tradie or homeowner polls the pending offer
///   GET  /api/offers/pending/mine               — tradie's live offers across all jobs (QA §3)
///   POST /api/jobs/{id}/offers/{offerId}/respond — tradie accepts or declines
///   POST /api/jobs/{id}/offers/{offerId}/withdraw — homeowner withdraws (P1 QA §2A)
///
/// Controller purity: only validates auth + ownership, then delegates to
/// OfferService. No direct state-machine logic here.
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
    private readonly ILogger<OffersController> _logger;

    public OffersController(
        FixoDbContext context,
        IJobStatusService jobStatusService,
        OfferService offerService,
        IHubContext<JobHub> jobHub,
        ILogger<OffersController> logger)
    {
        _context          = context;
        _jobStatusService = jobStatusService;
        _offerService     = offerService;
        _jobHub           = jobHub;
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

    // ── GET /api/offers/pending/mine ────────────────────────────────────────

    /// <summary>
    /// The calling tradie's live (Pending, unexpired) offers across every job,
    /// earliest expiry first. The mobile incoming-request coordinator reads this
    /// on cold start, resume and reconnect so nothing missed offline is lost.
    /// </summary>
    [HttpGet("~/api/offers/pending/mine")]
    [Authorize(Roles = "Tradie")]
    public async Task<IActionResult> GetMyPendingOffers()
    {
        var userId = User.FindFirstValue("sub") ?? User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (userId == null) return Unauthorized();

        return Ok(await _offerService.GetPendingForTradieAsync(userId));
    }

    // ── POST /api/jobs/{id}/offers/{offerId}/respond ──────────────────────────

    /// <summary>
    /// Tradie accepts or declines a pending offer.
    ///
    /// §7b fix: decline is fully delegated to OfferService.DeclineOfferAsync
    /// so the SignalR event, notifications, and Hangfire cancellation are issued
    /// from one place with correct copy (QA plan §7b).
    /// </summary>
    [HttpPost("{jobId:int}/offers/{offerId:int}/respond")]
    public async Task<IActionResult> RespondToOffer(
        int jobId, int offerId, [FromBody] RespondToOfferRequest request)
    {
        var userId = User.FindFirstValue("sub") ?? User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (userId == null) return Unauthorized();

        if (!User.IsInRole("Tradie")) return Forbid();

        if (string.IsNullOrWhiteSpace(request.Response))
            return BadRequest(ApiError.From("validation_error", "Response is required."));

        if (!Enum.TryParse<OfferResponse>(request.Response, ignoreCase: true, out var parsedResponse)
            || parsedResponse is not (OfferResponse.Accepted or OfferResponse.Declined))
        {
            return BadRequest(ApiError.From("validation_error", "Response must be 'Accepted' or 'Declined'."));
        }

        try
        {
            if (parsedResponse == OfferResponse.Accepted)
            {
                // v2 (P12-08/P12-10): accept books the job with the rate snapshot.
                // v1 legacy jobs keep the old Requested → AwaitingPayment path
                // (OfferService routes on the job's stored FlowVersion).
                // AcceptOfferAsync is now atomic (P1 QA §2A).
                var dto = await _offerService.AcceptOfferAsync(jobId, offerId, userId);
                return Ok(dto);
            }
            else
            {
                // §7b fix: delegate entirely to service — single source of truth
                // for SignalR, push notifications, Hangfire cancellation and copy.
                var dto = await _offerService.DeclineOfferAsync(jobId, offerId, userId);
                return Ok(dto);
            }
        }
        catch (KeyNotFoundException)
        {
            return NotFound();
        }
        catch (UnauthorizedAccessException)
        {
            return Forbid();
        }
        catch (BusinessRuleException ex)
        {
            return Conflict(ApiError.From(ex.Code, ex.Message));
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(ApiError.From("offer_conflict", ex.Message));
        }
    }

    // ── POST /api/jobs/{id}/offers/{offerId}/withdraw ─────────────────────────

    /// <summary>
    /// Homeowner withdraws their pending direct request (P1 QA §2A/2D).
    /// The job stays Requested; the tradie gets a SignalR + push close event.
    /// Returns the updated offer.
    /// </summary>
    [HttpPost("{jobId:int}/offers/{offerId:int}/withdraw")]
    public async Task<IActionResult> WithdrawOffer(int jobId, int offerId)
    {
        var userId = User.FindFirstValue("sub") ?? User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (userId == null) return Unauthorized();
        if (!User.IsInRole("Homeowner")) return Forbid();

        try
        {
            var dto = await _offerService.WithdrawOfferAsync(jobId, offerId, userId);
            return Ok(dto);
        }
        catch (KeyNotFoundException)
        {
            return NotFound();
        }
        catch (UnauthorizedAccessException)
        {
            return Forbid();
        }
        catch (BusinessRuleException ex)
        {
            return Conflict(ApiError.From(ex.Code, ex.Message));
        }
    }
}
