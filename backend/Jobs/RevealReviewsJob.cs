using System;
using System.Linq;
using System.Threading.Tasks;
using FixoApi.Data;
using FixoApi.Models;
using FixoApi.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace FixoApi.Jobs;

public class RevealReviewsJob
{
    private readonly FixoDbContext _context;
    private readonly INotificationService _notifications;
    private readonly IAccountFlagService _flagService;
    private readonly ILogger<RevealReviewsJob> _logger;

    public RevealReviewsJob(FixoDbContext context, INotificationService notifications, IAccountFlagService flagService, ILogger<RevealReviewsJob> logger)
    {
        _context = context;
        _notifications = notifications;
        _flagService = flagService;
        _logger = logger;
    }

    public async Task ExecuteAsync()
    {
        var now = DateTime.UtcNow;
        var threshold = now.AddMinutes(-5); // Look for recently revealed

        var justRevealed = await _context.Reviews
            .Where(r => r.RevealAfterUtc.HasValue && r.RevealAfterUtc.Value <= now && r.RevealAfterUtc.Value > threshold)
            .ToListAsync();

        foreach (var review in justRevealed)
        {
            try
            {
                await _notifications.SendPushToUserAsync(
                    review.RevieweeId,
                    "New Review Revealed!",
                    "A review for your recent job is now visible.",
                    new System.Collections.Generic.Dictionary<string, string> { { "jobId", review.JobId.ToString() } });
                
                // P10-12: Check Low Rating
                var allReviews = await _context.Reviews
                    .Where(r => r.RevieweeId == review.RevieweeId && (!r.RevealAfterUtc.HasValue || r.RevealAfterUtc.Value <= now))
                    .ToListAsync();
                    
                if (allReviews.Count > 0)
                {
                    var avg = allReviews.Average(r => r.Rating);
                    if (avg < 3.0)
                    {
                        await _flagService.LogFlagAsync(review.RevieweeId, FixoApi.Enums.AccountFlagType.LowRating, $"Average rating dropped to {avg:F1}");
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to process revealed review {ReviewId}", review.Id);
            }
        }
    }
}
