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
    private readonly PushNotificationService _push;
    private readonly IAccountFlagService _flagService;
    private readonly ILogger<RevealReviewsJob> _logger;

    public RevealReviewsJob(FixoDbContext context, PushNotificationService push, IAccountFlagService flagService, ILogger<RevealReviewsJob> logger)
    {
        _context = context;
        _push = push;
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
                var tokens = await _context.DeviceTokens
                    .Where(dt => dt.UserId == review.RevieweeId)
                    .Select(dt => dt.Token)
                    .ToListAsync();

                foreach (var token in tokens)
                {
                    await _push.SendAsync(token, "New Review Revealed!", "A review for your recent job is now visible.", new System.Collections.Generic.Dictionary<string, string> { { "jobId", review.JobId.ToString() } });
                }
                
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
