using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Hubs;
using FixoApi.Models;
using Hangfire;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using NetTopologySuite.Geometries;

namespace FixoApi.Services;

/// <summary>
/// Formal job-status state machine (M3-05).
///
/// Valid transitions:
///   Draft       → Requested
///   Requested   → Matching | Cancelled
///   Matching    → Matched  | Cancelled
///   Matched     → Confirmed | Matching | Cancelled
///   Confirmed   → InProgress | Cancelled
///   InProgress  → Complete | Cancelled
///   Complete    → (terminal)
///   Cancelled   → (terminal)
///
/// Any state → Cancelled is always legal (with a required reason).
/// </summary>
public class JobStatusService : IJobStatusService
{
    // State-machine: maps each status to its legal successors.
    private static readonly Dictionary<JobStatus, HashSet<JobStatus>> _validTransitions = new()
    {
        [JobStatus.Draft]      = [JobStatus.Requested, JobStatus.Cancelled],
        [JobStatus.Requested]  = [JobStatus.Matching, JobStatus.Cancelled],
        [JobStatus.Matching]   = [JobStatus.Matched, JobStatus.Cancelled],
        [JobStatus.Matched]    = [JobStatus.Confirmed, JobStatus.Matching, JobStatus.Cancelled],
        [JobStatus.Confirmed]  = [JobStatus.InProgress, JobStatus.Cancelled],
        [JobStatus.InProgress] = [JobStatus.Complete, JobStatus.Cancelled],
        [JobStatus.Complete]   = [],
        [JobStatus.Cancelled]  = [],
    };

    private readonly FixoDbContext _context;
    private readonly IHubContext<JobHub> _jobHub;
    private readonly PushNotificationService _push;
    private readonly IBackgroundJobClient _hangfire;
    private readonly ILogger<JobStatusService> _logger;

    public JobStatusService(
        FixoDbContext context,
        IHubContext<JobHub> jobHub,
        PushNotificationService push,
        IBackgroundJobClient hangfire,
        ILogger<JobStatusService> logger)
    {
        _context  = context;
        _jobHub   = jobHub;
        _push     = push;
        _hangfire = hangfire;
        _logger   = logger;
    }

    public async Task<JobDto> TransitionAsync(
        int jobId, JobStatus newStatus, string userId, string? reason = null)
    {
        var job = await _context.Jobs
            .Include(j => j.Photos)
            .FirstOrDefaultAsync(j => j.Id == jobId)
            ?? throw new KeyNotFoundException($"Job {jobId} not found.");

        var from = job.Status;

        // Validate the transition against the state machine.
        if (!_validTransitions.TryGetValue(from, out var allowed) || !allowed.Contains(newStatus))
        {
            throw new InvalidOperationException(
                $"Invalid job status transition: {from} → {newStatus}.");
        }

        // Apply transition.
        job.Status = newStatus;
        job.UpdatedAtUtc = DateTime.UtcNow;

        // M4-09: cancel Hangfire reminders if job is being cancelled.
        if (newStatus == JobStatus.Cancelled && !string.IsNullOrEmpty(job.ReminderJobIds))
        {
            foreach (var hId in job.ReminderJobIds.Split(',', StringSplitOptions.RemoveEmptyEntries))
            {
                try { _hangfire.Delete(hId); }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex,
                        "Could not cancel reminder {HangfireJobId} for job {JobId}", hId, job.Id);
                }
            }
            job.ReminderJobIds = null;
        }

        // Append audit row.
        var history = new JobStatusHistory
        {
            JobId           = jobId,
            FromStatus      = from,
            ToStatus        = newStatus,
            ChangedByUserId = userId,
            ChangedAtUtc    = DateTime.UtcNow,
            Reason          = reason,
        };
        _context.JobStatusHistory.Add(history);

        await _context.SaveChangesAsync();

        _logger.LogInformation("Job {Id} status: {From} → {To} by {User}", jobId, from, newStatus, userId);

        // Broadcast via SignalR (AGENTS.md rule: every transition must go through hub).
        var payload = new JobStatusChangedPayload
        {
            JobId     = jobId,
            NewStatus = newStatus.ToString(),
            JobTitle  = job.Title,
        };

        await _jobHub.Clients
            .Group(JobHub.GroupName(jobId))
            .SendAsync("JobStatusChanged", payload);

        // FCM push to both parties (fire-and-forget).
        _ = SendStatusPushAsync(job, from, newStatus);

        return MapToDto(job);
    }

    // ── FCM push for status changes ───────────────────────────────────────────

    private async Task SendStatusPushAsync(Job job, JobStatus from, JobStatus to)
    {
        try
        {
            var recipientIds = new List<string> { job.HomeownerId };
            if (job.MatchedTradieId != null) recipientIds.Add(job.MatchedTradieId);

            var tokens = await _context.DeviceTokens
                .Where(dt => recipientIds.Contains(dt.UserId))
                .Select(dt => new { dt.UserId, dt.Token })
                .ToListAsync();

            if (tokens.Count == 0) return;

            var stale = await _push.SendMulticastAsync(
                tokens.Select(t => t.Token),
                title: $"Job Update: {job.Title}",
                body:  $"Status changed to {to}.",
                data: new Dictionary<string, string>
                {
                    { "type",      "job_status" },
                    { "jobId",     job.Id.ToString() },
                    { "newStatus", to.ToString() },
                    { "jobTitle",  job.Title },
                });

            // Clean stale device tokens.
            if (stale.Count > 0)
            {
                var toRemove = await _context.DeviceTokens
                    .Where(dt => recipientIds.Contains(dt.UserId) && stale.Contains(dt.Token))
                    .ToListAsync();
                _context.DeviceTokens.RemoveRange(toRemove);
                await _context.SaveChangesAsync();
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Status push failed for job {JobId}", job.Id);
        }
    }

    // ── Mapping (mirrors JobService.MapToDto) ─────────────────────────────────

    private static JobDto MapToDto(Job job)
    {
        var stage = job.Status switch
        {
            JobStatus.Requested or JobStatus.Matching  => 0,
            JobStatus.Matched                          => 1,
            JobStatus.Confirmed or JobStatus.InProgress => 2,
            JobStatus.Complete                         => 3,
            _                                          => 0,
        };

        var suburb = job.Address?.Split(',').FirstOrDefault()?.Trim() ?? "";

        return new JobDto
        {
            Id               = job.Id,
            HomeownerId      = job.HomeownerId,
            Title            = job.Title,
            Category         = job.Category.ToString(),
            Description      = job.Description,
            Urgency          = job.Urgency.ToString(),
            Status           = job.Status.ToString(),
            Address          = job.Address,
            Suburb           = suburb,
            Latitude         = job.Location?.Y,
            Longitude        = job.Location?.X,
            CreatedAtUtc     = job.CreatedAtUtc,
            UpdatedAtUtc     = job.UpdatedAtUtc,
            ScheduledDateUtc = job.ScheduledDateUtc,
            MatchedTradieId  = job.MatchedTradieId,
            Stage            = stage,
            Photos           = job.Photos.Select(p => new JobPhotoDto
            {
                Id               = p.Id,
                Url              = $"/api/photos/{p.S3Key}",
                OriginalFileName = p.OriginalFileName,
            }).ToList(),
        };
    }
}
