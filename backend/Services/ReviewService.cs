using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Hubs;
using FixoApi.Models;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace FixoApi.Services;

/// <summary>
/// Review submission, retrieval, and post-review notifications (M4-02, M4-04).
/// </summary>
public class ReviewService : IReviewService
{
    private readonly FixoDbContext _context;
    private readonly IHubContext<JobHub> _hub;
    private readonly PushNotificationService _push;
    private readonly ILogger<ReviewService> _logger;

    public ReviewService(
        FixoDbContext context,
        IHubContext<JobHub> hub,
        PushNotificationService push,
        ILogger<ReviewService> logger)
    {
        _context = context;
        _hub     = hub;
        _push    = push;
        _logger  = logger;
    }

    // ── Submit ────────────────────────────────────────────────────────────────

    public async Task<ReviewDto> SubmitReviewAsync(
        int jobId, string reviewerId, SubmitReviewRequest request)
    {
        var job = await _context.Jobs
            .Include(j => j.Homeowner)
            .Include(j => j.MatchedTradie)
            .FirstOrDefaultAsync(j => j.Id == jobId)
            ?? throw new KeyNotFoundException($"Job {jobId} not found.");

        // Only completed jobs can be reviewed.
        if (job.Status != JobStatus.Completed)
            throw new InvalidOperationException("Reviews can only be submitted for completed jobs.");

        // Reviewer must be a participant.
        var isHomeowner = job.HomeownerId == reviewerId;
        var isTradie    = job.MatchedTradieId == reviewerId;
        if (!isHomeowner && !isTradie)
            throw new UnauthorizedAccessException("Only job participants can submit a review.");

        // Cannot review yourself.
        if (request.RevieweeId == reviewerId)
            throw new InvalidOperationException("You cannot review yourself.");

        // Reviewee must also be a participant.
        if (request.RevieweeId != job.HomeownerId && request.RevieweeId != job.MatchedTradieId)
            throw new InvalidOperationException("Reviewee must be a participant of this job.");

        // One review per reviewer per job.
        var alreadyExists = await _context.Reviews
            .AnyAsync(r => r.JobId == jobId && r.ReviewerId == reviewerId);
        if (alreadyExists)
            throw new InvalidOperationException("You have already reviewed this job.");

        // P10-11: Blind Review Logic
        var existingReview = await _context.Reviews.FirstOrDefaultAsync(r => r.JobId == jobId);
        DateTime? revealAfter = existingReview == null 
            ? DateTime.UtcNow.AddDays(7) 
            : DateTime.UtcNow;

        if (existingReview != null)
        {
            existingReview.RevealAfterUtc = revealAfter;
        }

        var review = new Review
        {
            JobId        = jobId,
            ReviewerId   = reviewerId,
            RevieweeId   = request.RevieweeId,
            Rating       = request.Rating,
            Comment      = request.Comment,
            CreatedAtUtc = DateTime.UtcNow,
            RevealAfterUtc = revealAfter
        };

        _context.Reviews.Add(review);
        await _context.SaveChangesAsync();

        _logger.LogInformation(
            "Review {ReviewId} submitted: job={JobId} reviewer={ReviewerId} rating={Rating}",
            review.Id, jobId, reviewerId, request.Rating);

        var dto = await BuildDtoAsync(review);

        // Notify reviewee (M4-04).
        await NotifyRevieweeAsync(review, job);

        return dto;
    }

    // ── Queries ───────────────────────────────────────────────────────────────

    public async Task<ReviewListResponse> GetReviewsForJobAsync(int jobId)
    {
        var reviews = await _context.Reviews
            .Include(r => r.Reviewer)
            .Include(r => r.Job)
            .Where(r => r.JobId == jobId)
            .OrderByDescending(r => r.CreatedAtUtc)
            .ToListAsync();

        var now = DateTime.UtcNow;
        var items = reviews.Select(r => 
        {
            var isDisputed = r.Job.IsFlagged && r.Job.DisputeStatus != "Resolved";
            var isHidden = isDisputed || (r.RevealAfterUtc.HasValue && r.RevealAfterUtc.Value > now);
            
            var dto = MapToDto(r);
            if (isHidden)
            {
                dto.Rating = 0;
                dto.Comment = "This review is currently hidden.";
            }
            return dto;
        }).ToList();

        return new ReviewListResponse
        {
            Items      = items,
            TotalCount = reviews.Count,
            Page       = 1,
            PageSize   = reviews.Count,
        };
    }

    public async Task<ReviewListResponse> GetReviewsForUserAsync(
        string userId, int page, int pageSize)
    {
        pageSize = Math.Clamp(pageSize, 1, 50);
        page     = Math.Max(1, page);

        var query = _context.Reviews
            .Include(r => r.Reviewer)
            .Where(r => r.RevieweeId == userId)
            .OrderByDescending(r => r.CreatedAtUtc);

        var total = await query.CountAsync();
        var items = await query
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        return new ReviewListResponse
        {
            Items      = items.Select(MapToDto).ToList(),
            TotalCount = total,
            Page       = page,
            PageSize   = pageSize,
        };
    }

    // ── M4-04: Notification ───────────────────────────────────────────────────

    private async Task NotifyRevieweeAsync(Review review, Job job)
    {
        try
        {
            // SignalR: ReviewReceived — push to the reviewee's connections only.
            var payload = new ReviewReceivedPayload
            {
                ReviewId     = review.Id,
                JobId        = review.JobId,
                JobTitle     = job.Title,
                ReviewerName = $"{review.Reviewer?.FirstName} {review.Reviewer?.LastName}".Trim(),
                Rating       = review.Rating,
            };

            await _hub.Clients
                .User(review.RevieweeId)
                .SendAsync("ReviewReceived", payload);

            // FCM push — does NOT reveal the comment per spec.
            var tokens = await _context.DeviceTokens
                .Where(dt => dt.UserId == review.RevieweeId)
                .Select(dt => dt.Token)
                .ToListAsync();

            if (tokens.Count > 0)
            {
                var stale = await _push.SendMulticastAsync(
                    tokens,
                    title: "You received a review",
                    body:  $"{payload.ReviewerName} rated your work on \"{job.Title}\"",
                    data: new Dictionary<string, string>
                    {
                        { "type",    "review_received" },
                        { "jobId",   review.JobId.ToString() },
                        { "link",    $"/profile/{review.RevieweeId}/reviews" },
                    });

                if (stale.Count > 0)
                {
                    var toRemove = await _context.DeviceTokens
                        .Where(dt => dt.UserId == review.RevieweeId && stale.Contains(dt.Token))
                        .ToListAsync();
                    _context.DeviceTokens.RemoveRange(toRemove);
                    await _context.SaveChangesAsync();
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Review notification failed for reviewee {UserId}", review.RevieweeId);
            // Swallowed — notification failure must not rollback the review.
        }
    }

    // ── Mapping ───────────────────────────────────────────────────────────────

    private static ReviewDto MapToDto(Review r) => new()
    {
        Id           = r.Id,
        JobId        = r.JobId,
        ReviewerId   = r.ReviewerId,
        ReviewerName = $"{r.Reviewer?.FirstName} {r.Reviewer?.LastName}".Trim(),
        RevieweeId   = r.RevieweeId,
        Rating       = r.Rating,
        Comment      = r.Comment,
        CreatedAtUtc = r.CreatedAtUtc,
    };

    private async Task<ReviewDto> BuildDtoAsync(Review review)
    {
        // Re-load with reviewer included after insert.
        var loaded = await _context.Reviews
            .Include(r => r.Reviewer)
            .FirstAsync(r => r.Id == review.Id);
        return MapToDto(loaded);
    }
}

/// <summary>Payload sent to the reviewee via SignalR ReviewReceived (M4-04).</summary>
public class ReviewReceivedPayload
{
    public Guid ReviewId { get; set; }
    public int JobId { get; set; }
    public string JobTitle { get; set; } = string.Empty;
    public string ReviewerName { get; set; } = string.Empty;
    public int Rating { get; set; }
}
