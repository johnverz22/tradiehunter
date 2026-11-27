using FixoApi.Data;
using FixoApi.Enums;
using FixoApi.Hubs;
using FixoApi.Models;
using FixoApi.Services;
using Hangfire;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace FixoApi.Jobs;

/// <summary>
/// v1.7 (P12-18): expires a pending price adjustment after the configured
/// window (default 48h). A stale proposal must not linger as a silent blocker
/// of the completion approval (P12-11 blocks approving while anything is
/// Pending). Expiry flips the status, recomputes the job's AdjustmentsTotal,
/// and notifies both sides.
/// </summary>
public class AdjustmentExpiryJob
{
    internal const string SystemUserId = "system";

    private readonly FixoDbContext _context;
    private readonly IHubContext<JobHub> _jobHub;
    private readonly INotificationService _notifications;
    private readonly IBackgroundJobClient _hangfire;
    private readonly ILogger<AdjustmentExpiryJob> _logger;

    public AdjustmentExpiryJob(
        FixoDbContext context,
        IHubContext<JobHub> jobHub,
        INotificationService notifications,
        IBackgroundJobClient hangfire,
        ILogger<AdjustmentExpiryJob> logger)
    {
        _context = context;
        _jobHub = jobHub;
        _notifications = notifications;
        _hangfire = hangfire;
        _logger = logger;
    }

    [AutomaticRetry(Attempts = 0)]
    public async Task ExecuteAsync(int adjustmentId)
    {
        var adjustment = await _context.JobPriceAdjustments
            .Include(a => a.Job)
            .FirstOrDefaultAsync(a => a.Id == adjustmentId);

        if (adjustment == null)
        {
            _logger.LogWarning("AdjustmentExpiryJob: adjustment {AdjustmentId} not found — skipping.", adjustmentId);
            return;
        }

        if (adjustment.Status != AdjustmentStatus.Pending)
        {
            _logger.LogInformation(
                "AdjustmentExpiryJob: adjustment {AdjustmentId} already '{Status}' — skipping.",
                adjustmentId, adjustment.Status);
            return;
        }

        adjustment.Status = AdjustmentStatus.Expired;
        adjustment.RespondedAtUtc = DateTime.UtcNow;
        adjustment.ExpiryJobId = null;
        adjustment.ReminderJobId = null;

        var job = adjustment.Job;

        // Only Approved adjustments count toward the total (P12-17).
        var approved = job.Adjustments
            .Where(a => a.Status == AdjustmentStatus.Approved)
            .Sum(a => a.Amount);
        job.AdjustmentsTotal = Math.Round(approved, 2);
        job.UpdatedAtUtc = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        _logger.LogInformation(
            "Adjustment {AdjustmentId} on job {JobId} expired after no homeowner response.",
            adjustmentId, job.Id);

        await _jobHub.Clients.Group(JobHub.GroupName(job.Id))
            .SendAsync("JobAdjustmentChanged", new AdjustmentChangedPayload
            {
                EventType = "AdjustmentExpired",
                JobId = job.Id,
                AdjustmentId = adjustment.Id,
                AdjustmentStatus = AdjustmentStatus.Expired.ToString(),
                Amount = adjustment.Amount,
            });

        foreach (var userId in new[] { job.HomeownerId, adjustment.ProposedByTradieId })
        {
            await _notifications.SendPushToUserAsync(userId, "Extra cost request expired",
                $"\"{job.Title}\": the request for {adjustment.Amount:N2} expired without a response.",
                new Dictionary<string, string>
                {
                    ["jobId"] = job.Id.ToString(),
                    ["adjustmentId"] = adjustment.Id.ToString(),
                    ["type"] = "adjustment_expired",
                });
        }
    }
}

/// <summary>
/// v1.7 (P12-18): halfway reminder for a still-pending price adjustment
/// (default at 24h of the 48h window). Pure notification — never mutates state.
/// </summary>
public class AdjustmentReminderJob
{
    private readonly FixoDbContext _context;
    private readonly INotificationService _notifications;
    private readonly ILogger<AdjustmentReminderJob> _logger;

    public AdjustmentReminderJob(
        FixoDbContext context,
        INotificationService notifications,
        ILogger<AdjustmentReminderJob> logger)
    {
        _context = context;
        _notifications = notifications;
        _logger = logger;
    }

    [AutomaticRetry(Attempts = 0)]
    public async Task ExecuteAsync(int adjustmentId)
    {
        var adjustment = await _context.JobPriceAdjustments
            .Include(a => a.Job)
            .FirstOrDefaultAsync(a => a.Id == adjustmentId);

        if (adjustment == null || adjustment.Status != AdjustmentStatus.Pending)
            return; // decided (or withdrawn/expired) — nothing to remind about

        await _notifications.SendPushToUserAsync(adjustment.Job.HomeownerId,
            "Reminder: extra cost awaiting your approval",
            $"\"{adjustment.Job.Title}\": {adjustment.Description} — {adjustment.Amount:N2}. Approve or decline.",
            new Dictionary<string, string>
            {
                ["jobId"] = adjustment.JobId.ToString(),
                ["adjustmentId"] = adjustment.Id.ToString(),
                ["type"] = "adjustment_reminder",
            });
    }
}
