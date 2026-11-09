using FixoApi.Data;
using FixoApi.Enums;
using FixoApi.Models;
using FixoApi.Services;
using Hangfire;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace FixoApi.Jobs;

/// <summary>
/// Auto-completes a job if the homeowner hasn't confirmed after 48 hours in AwaitingConfirmation (P5-04).
/// </summary>
public class AutoCompleteJob
{
    internal const string SystemUserId = "system";
    private const int AutoCompleteHours = 48;

    private readonly FixoDbContext _context;
    private readonly IJobStatusService _jobStatus;
    private readonly PushNotificationService _push;
    private readonly IBackgroundJobClient _hangfire;
    private readonly ILogger<AutoCompleteJob> _logger;

    public AutoCompleteJob(
        FixoDbContext context,
        IJobStatusService jobStatus,
        PushNotificationService push,
        IBackgroundJobClient hangfire,
        ILogger<AutoCompleteJob> logger)
    {
        _context = context;
        _jobStatus = jobStatus;
        _push = push;
        _hangfire = hangfire;
        _logger = logger;
    }

    [AutomaticRetry(Attempts = 0)]
    public async Task ExecuteAsync(int jobId)
    {
        var job = await _context.Jobs.FirstOrDefaultAsync(j => j.Id == jobId);
        if (job is null)
        {
            _logger.LogWarning("AutoCompleteJob: job {JobId} not found — skipping.", jobId);
            return;
        }

        // Only auto-complete if still in AwaitingConfirmation
        if (job.Status != JobStatus.AwaitingConfirmation)
        {
            _logger.LogInformation("AutoCompleteJob: job {JobId} is {Status} — no auto-complete.", jobId, job.Status);
            return;
        }

        _logger.LogInformation("AutoCompleteJob: auto-completing job {JobId} after {Hours} hours.", jobId, AutoCompleteHours);

        await _jobStatus.TransitionAsync(
            jobId, JobStatus.Completed, SystemUserId, UserRole.Staff,
            ReasonCode.no_response, $"Auto-completed after {AutoCompleteHours}h without homeowner confirmation.");

        // Send notification to both parties
        var recipients = new[] { job.HomeownerId, job.MatchedTradieId }
            .Where(id => !string.IsNullOrEmpty(id))
            .Distinct()
            .ToList();

        foreach (var userId in recipients)
        {
            try
            {
                var tokens = await _context.DeviceTokens
                    .Where(dt => dt.UserId == userId)
                    .Select(dt => dt.Token)
                    .ToListAsync();

                var title = "Job completed";
                var body = $"Job \"{job.Title}\" has been auto-completed.";

                foreach (var token in tokens)
                {
                    await _push.SendAsync(token, title, body,
                        new Dictionary<string, string>
                        {
                            ["jobId"] = job.Id.ToString(),
                            ["type"] = "auto_complete"
                        });
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "FCM push to {UserId} about auto-complete for job {JobId} failed.", userId, job.Id);
            }
        }
    }
}