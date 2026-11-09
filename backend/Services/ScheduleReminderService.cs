using FixoApi.Data;
using FixoApi.Enums;
using Microsoft.EntityFrameworkCore;

namespace FixoApi.Services;

/// <summary>
/// Hangfire job worker that sends FCM reminders before a confirmed schedule (M4-09).
/// Called by ScheduleService via BackgroundJob.Schedule{ScheduleReminderService}.
/// </summary>
public class ScheduleReminderService
{
    private readonly FixoDbContext _context;
    private readonly PushNotificationService _push;
    private readonly ILogger<ScheduleReminderService> _logger;

    public ScheduleReminderService(
        FixoDbContext context,
        PushNotificationService push,
        ILogger<ScheduleReminderService> logger)
    {
        _context = context;
        _push    = push;
        _logger  = logger;
    }

    /// <summary>
    /// Send a reminder push to both homeowner and tradie.
    /// <paramref name="window"/> is "24h" or "1h" — used for the push copy.
    /// Idempotent: if the job is already cancelled, the method exits cleanly.
    /// </summary>
    [Hangfire.AutomaticRetry(Attempts = 3)]
    public async Task SendReminderAsync(int jobId, string window)
    {
        var job = await _context.Jobs
            .Include(j => j.Homeowner)
            .Include(j => j.MatchedTradie)
            .FirstOrDefaultAsync(j => j.Id == jobId);

        if (job == null)
        {
            _logger.LogWarning("Reminder skipped — job {JobId} not found", jobId);
            return;
        }

        // Don't remind for cancelled or already-complete jobs.
        if (job.Status is JobStatus.Cancelled or JobStatus.Completed)
        {
            _logger.LogInformation(
                "Reminder skipped — job {JobId} is {Status}", jobId, job.Status);
            return;
        }

        // Build reminder copy.
        var slotLabel = job.ScheduledTimeSlot?.ToString().ToLower() ?? "scheduled time";
        var dateStr   = job.ScheduledStart?.ToString("ddd d MMM") ?? "your upcoming appointment";
        var body      = window == "1h"
            ? $"Your job starts in 1 hour — {job.Title} ({slotLabel} on {dateStr})."
            : $"Reminder: \"{job.Title}\" is tomorrow, {dateStr} ({slotLabel}).";

        var recipientIds = new List<string> { job.HomeownerId };
        if (job.MatchedTradieId != null) recipientIds.Add(job.MatchedTradieId);

        var tokens = await _context.DeviceTokens
            .Where(dt => recipientIds.Contains(dt.UserId))
            .Select(dt => new { dt.UserId, dt.Token })
            .ToListAsync();

        if (tokens.Count == 0) return;

        var stale = await _push.SendMulticastAsync(
            tokens.Select(t => t.Token),
            title: window == "1h" ? "Job reminder — 1 hour" : "Job reminder — tomorrow",
            body:  body,
            data: new Dictionary<string, string>
            {
                { "type",  "schedule_reminder" },
                { "jobId", jobId.ToString() },
            });

        // Clean up stale tokens.
        if (stale.Count > 0)
        {
            var toRemove = await _context.DeviceTokens
                .Where(dt => recipientIds.Contains(dt.UserId) && stale.Contains(dt.Token))
                .ToListAsync();
            _context.DeviceTokens.RemoveRange(toRemove);
            await _context.SaveChangesAsync();
        }

        _logger.LogInformation(
            "Reminder ({Window}) sent for job {JobId} to {Count} devices",
            window, jobId, tokens.Count);
    }
}
