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
/// Sends a pre-job reminder notification 1 hour before the scheduled start time (P5-03).
/// </summary>
public class PreJobReminderJob
{
    internal const string SystemUserId = "system";

    private readonly FixoDbContext _context;
    private readonly INotificationService _notifications;
    private readonly ILogger<PreJobReminderJob> _logger;

    public PreJobReminderJob(
        FixoDbContext context,
        INotificationService notifications,
        ILogger<PreJobReminderJob> logger)
    {
        _context = context;
        _notifications = notifications;
        _logger = logger;
    }

    [AutomaticRetry(Attempts = 0)]
    public async Task ExecuteAsync(int jobId)
    {
        var job = await _context.Jobs.FirstOrDefaultAsync(j => j.Id == jobId);
        if (job is null)
        {
            _logger.LogWarning("PreJobReminderJob: job {JobId} not found — skipping.", jobId);
            return;
        }

        // Only send reminder if job is still Booked (not yet started or cancelled)
        if (job.Status != JobStatus.Booked)
        {
            _logger.LogInformation("PreJobReminderJob: job {JobId} is {Status} — no reminder sent.", jobId, job.Status);
            return;
        }

        var recipients = new[] { job.HomeownerId, job.MatchedTradieId }
            .Where(id => !string.IsNullOrEmpty(id))
            .Distinct()
            .ToList();

        foreach (var userId in recipients)
        {
            var role = userId == job.HomeownerId ? "homeowner" : "tradie";
            var title = "Job starting soon";
            var body = $"Your job \"{job.Title}\" starts in 1 hour.";

            await _notifications.SendPushToUserAsync(userId, title, body,
                new Dictionary<string, string>
                {
                    ["jobId"] = job.Id.ToString(),
                    ["type"] = "pre_job_reminder",
                    ["role"] = role
                });
        }

        _logger.LogInformation("PreJobReminderJob: sent reminders for job {JobId}.", jobId);
    }
}