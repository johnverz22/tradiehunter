using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Hubs;
using Hangfire;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace FixoApi.Services;

/// <summary>
/// Job scheduling proposal/confirmation and Hangfire reminder management (M4-07, M4-09).
/// </summary>
public class ScheduleService : IScheduleService
{
    private readonly FixoDbContext _context;
    private readonly IHubContext<JobHub> _hub;
    private readonly PushNotificationService _push;
    private readonly IBackgroundJobClient _hangfire;
    private readonly ILogger<ScheduleService> _logger;

    public ScheduleService(
        FixoDbContext context,
        IHubContext<JobHub> hub,
        PushNotificationService push,
        IBackgroundJobClient hangfire,
        ILogger<ScheduleService> logger)
    {
        _context  = context;
        _hub      = hub;
        _push     = push;
        _hangfire = hangfire;
        _logger   = logger;
    }

    // ── Propose or Confirm ────────────────────────────────────────────────────

    public async Task<ScheduleDto> ProposeOrConfirmAsync(
        int jobId, string userId, ScheduleJobRequest request)
    {
        var job = await _context.Jobs
            .Include(j => j.Homeowner)
            .Include(j => j.MatchedTradie)
            .FirstOrDefaultAsync(j => j.Id == jobId)
            ?? throw new KeyNotFoundException($"Job {jobId} not found.");

        // Only Confirmed-status jobs can be scheduled.
        if (job.Status != JobStatus.Booked)
            throw new InvalidOperationException(
                "Scheduling is only available for Confirmed jobs.");

        // User must be a participant.
        var isHomeowner = job.HomeownerId == userId;
        var isTradie    = job.MatchedTradieId == userId;
        if (!isHomeowner && !isTradie)
            throw new UnauthorizedAccessException("Only job participants can propose a schedule.");

        if (!Enum.TryParse<ScheduleTimeSlot>(request.TimeSlot, ignoreCase: true, out var slot))
            throw new ArgumentException($"Invalid time slot: {request.TimeSlot}");

        // If the OTHER party previously proposed, this is a confirmation.
        var isConfirmation = job.ScheduleStatus == ScheduleStatus.Proposed
                             && job.ScheduleProposedByUserId != userId;

        // Cancel any existing reminders before replacing.
        CancelExistingReminders(job);

        job.ScheduledStart         = request.ProposedDateUtc.Date; // UTC date only
        job.ScheduledTimeSlot        = slot;
        job.ScheduleProposedByUserId = userId;
        job.ScheduleStatus           = isConfirmation
            ? ScheduleStatus.Confirmed
            : ScheduleStatus.Proposed;

        if (isConfirmation)
        {
            // Enqueue Hangfire reminders (M4-09).
            EnqueueReminders(job);
        }

        await _context.SaveChangesAsync();

        _logger.LogInformation(
            "Job {JobId} schedule {Action} by {UserId}: {Date} {Slot}",
            jobId,
            isConfirmation ? "confirmed" : "proposed",
            userId,
            job.ScheduledStart?.ToString("yyyy-MM-dd"),
            slot);

        var dto = BuildDto(job);

        // SignalR event (M4-07).
        var eventName = isConfirmation ? "ScheduleConfirmed" : "ScheduleProposed";
        await _hub.Clients
            .Group(JobHub.GroupName(jobId))
            .SendAsync(eventName, dto);

        // FCM push on proposal (M4-07) — only notify the other party.
        if (!isConfirmation)
        {
            var recipientId = isHomeowner ? job.MatchedTradieId : job.HomeownerId;
            if (recipientId != null)
                _ = SendSchedulePushAsync(job, recipientId, slot, isConfirmation: false);
        }
        else
        {
            // Notify both on confirmation.
            var recipients = new[] { job.HomeownerId, job.MatchedTradieId }
                .Where(r => r != null).Cast<string>().ToList();
            _ = SendSchedulePushAsync(job, recipients, slot, isConfirmation: true);
        }

        return dto;
    }

    public async Task<ScheduleDto?> GetScheduleAsync(int jobId)
    {
        var job = await _context.Jobs.FindAsync(jobId);
        return job == null ? null : BuildDto(job);
    }

    // ── Hangfire reminder management (M4-09) ──────────────────────────────────

    /// <summary>Enqueue 24h and 1h reminders for a confirmed schedule.</summary>
    private void EnqueueReminders(Models.Job job)
    {
        if (job.ScheduledStart == null) return;

        // Compute the approximate reminder times based on the time slot.
        var slotHour = job.ScheduledTimeSlot switch
        {
            ScheduleTimeSlot.Morning   => 8,
            ScheduleTimeSlot.Afternoon => 12,
            ScheduleTimeSlot.Evening   => 17,
            _                          => 8,
        };

        var scheduledAt = DateTime.SpecifyKind(
            job.ScheduledStart.Value.Date.AddHours(slotHour),
            DateTimeKind.Utc);

        var reminder24h = scheduledAt.AddHours(-24);
        var reminder1h  = scheduledAt.AddHours(-1);

        var id24h = _hangfire.Schedule<ScheduleReminderService>(
            svc => svc.SendReminderAsync(job.Id, "24h"),
            reminder24h > DateTime.UtcNow ? reminder24h - DateTime.UtcNow : TimeSpan.FromSeconds(1));

        var id1h = _hangfire.Schedule<ScheduleReminderService>(
            svc => svc.SendReminderAsync(job.Id, "1h"),
            reminder1h > DateTime.UtcNow ? reminder1h - DateTime.UtcNow : TimeSpan.FromSeconds(1));

        // Store Hangfire job IDs on the Job row for later cancellation.
        job.ReminderJobIds = $"{id24h},{id1h}";
        _logger.LogInformation(
            "Enqueued reminders for job {JobId}: 24h={Id24h} 1h={Id1h}",
            job.Id, id24h, id1h);
    }

    /// <summary>Cancel existing Hangfire reminder jobs if any.</summary>
    private void CancelExistingReminders(Models.Job job)
    {
        if (string.IsNullOrEmpty(job.ReminderJobIds)) return;

        var ids = job.ReminderJobIds.Split(',', StringSplitOptions.RemoveEmptyEntries);
        foreach (var id in ids)
        {
            try { _hangfire.Delete(id); }
            catch (Exception ex)
            {
                _logger.LogWarning(ex,
                    "Could not cancel Hangfire job {HangfireJobId} for job {JobId}",
                    id, job.Id);
            }
        }
        job.ReminderJobIds = null;
    }

    // ── FCM helpers ────────────────────────────────────────────────────────────

    private async Task SendSchedulePushAsync(
        Models.Job job, string recipientId, ScheduleTimeSlot slot, bool isConfirmation)
        => await SendSchedulePushAsync(job, new[] { recipientId }, slot, isConfirmation);

    private async Task SendSchedulePushAsync(
        Models.Job job,
        IEnumerable<string> recipientIds,
        ScheduleTimeSlot slot,
        bool isConfirmation)
    {
        try
        {
            var ids    = recipientIds.ToList();
            var tokens = await _context.DeviceTokens
                .Where(dt => ids.Contains(dt.UserId))
                .Select(dt => dt.Token)
                .ToListAsync();

            if (tokens.Count == 0) return;

            var title = isConfirmation
                ? "Schedule confirmed"
                : "Schedule proposal";
            var slotLabel = slot.ToString().ToLower();
            var dateStr   = job.ScheduledStart?.ToString("ddd d MMM") ?? "upcoming";
            var body      = isConfirmation
                ? $"\"{job.Title}\" is confirmed for {dateStr} ({slotLabel})."
                : $"A {slotLabel} slot on {dateStr} was proposed for \"{job.Title}\".";

            var stale = await _push.SendMulticastAsync(
                tokens,
                title: title,
                body:  body,
                data: new Dictionary<string, string>
                {
                    { "type",  "schedule_update" },
                    { "jobId", job.Id.ToString() },
                });

            if (stale.Count > 0)
            {
                var toRemove = await _context.DeviceTokens
                    .Where(dt => ids.Contains(dt.UserId) && stale.Contains(dt.Token))
                    .ToListAsync();
                _context.DeviceTokens.RemoveRange(toRemove);
                await _context.SaveChangesAsync();
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Schedule push failed for job {JobId}", job.Id);
        }
    }

    // ── Mapping ────────────────────────────────────────────────────────────────

    private static ScheduleDto BuildDto(Models.Job job) => new()
    {
        JobId             = job.Id,
        ScheduledStart  = job.ScheduledStart,
        ScheduledTimeSlot = job.ScheduledTimeSlot?.ToString(),
        ScheduleStatus    = job.ScheduleStatus.ToString(),
        ProposedByUserId  = job.ScheduleProposedByUserId,
    };
}
