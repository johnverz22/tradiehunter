using FixoApi.DTOs;
using FixoApi.Services;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace FixoApi.Controllers;

/// <summary>
/// Review endpoints (M4-02):
///   POST /api/jobs/{id}/reviews          — submit a review
///   GET  /api/jobs/{id}/reviews          — list reviews for a job
///   GET  /api/users/{id}/reviews         — list reviews received by a user (paginated)
/// </summary>
[ApiController]
[Authorize]
public class ReviewsController : ControllerBase
{
    private readonly IReviewService _reviewService;
    private readonly IValidator<SubmitReviewRequest> _validator;

    public ReviewsController(
        IReviewService reviewService,
        IValidator<SubmitReviewRequest> validator)
    {
        _reviewService = reviewService;
        _validator     = validator;
    }

    // ── POST /api/jobs/{id}/reviews ────────────────────────────────────────────

    [HttpPost("api/jobs/{id:int}/reviews")]
    public async Task<IActionResult> SubmitReview(
        int id, [FromBody] SubmitReviewRequest request)
    {
        var validation = await _validator.ValidateAsync(request);
        if (!validation.IsValid) return BadRequest(validation.Errors);

        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        try
        {
            var dto = await _reviewService.SubmitReviewAsync(id, userId, request);
            return CreatedAtAction(
                nameof(GetJobReviews), new { id }, dto);
        }
        catch (KeyNotFoundException) { return NotFound(); }
        catch (UnauthorizedAccessException ex) { return Forbid(ex.Message); }
        catch (InvalidOperationException ex) { return BadRequest(new { error = ex.Message }); }
    }

    // ── GET /api/jobs/{id}/reviews ─────────────────────────────────────────────

    [HttpGet("api/jobs/{id:int}/reviews")]
    public async Task<IActionResult> GetJobReviews(int id)
    {
        var result = await _reviewService.GetReviewsForJobAsync(id);
        return Ok(result);
    }

    // ── GET /api/users/{id}/reviews ────────────────────────────────────────────

    [HttpGet("api/users/{id}/reviews")]
    [AllowAnonymous]
    public async Task<IActionResult> GetUserReviews(
        string id,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
    {
        var result = await _reviewService.GetReviewsForUserAsync(id, page, pageSize);
        return Ok(result);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private string? GetUserId() => User.FindFirstValue("sub");
}
