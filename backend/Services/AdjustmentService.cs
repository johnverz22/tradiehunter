using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Hubs;
using FixoApi.Jobs;
using FixoApi.Models;
using FixoApi.Options;
using Hangfire;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace FixoApi.Services;

/// <summary>
/// v1.7 (P12-17): on-demand price adjustments during a job — materials bought
/// by the tradie, extra work, travel. Every change needs the homeowner's
/// explicit, recorded approval BEFORE it can be billed (NZ business.govt.nz /
/// Consumer Protection guidance on variations): only Approved adjustments
/// count toward Job.AdjustmentsTotal, and every proposal/decision is written
/// to the audit log — the "in writing" record.
///
/// P12-18: proposals expire (default 48h, reminder at 24h), both sides hear
/// about changes instantly via SignalR + FCM, and guards (max pending per job,
/// staff-review threshold) are enforced server-side.
/// </summary>
public class AdjustmentService
{
    private readonly FixoDbContext _context;
    private readonly IAuditLogService _audit;
    private readonly IHubContext<JobHub> _jobHub;
    private readonly INotificationService _notifications;
    private readonly IBackgroundJobClient _hangfire;
    private readonly IOptions<JobFlowOptions> _flowOptions;
    private readonly ILogger<AdjustmentService> _logger;

    public AdjustmentService(
        FixoDbContext context,
        IAuditLogService audit,
        IHubContext<JobHub> jobHub,
        INotificationService notifications,
        IBackgroundJobClient hangfire,
        IOptions<JobFlowOptions> flowOptions,
        ILogger<AdjustmentService> logger)
    {
        _context = context;
        _audit = audit;
        _jobHub = jobHub;
        _notifications = notifications;
        _hangfire = hangfire;
        _flowOptions = flowOptions;
        _logger = logger;
    }

    // ── Tradie: propose ───────────────────────────────────────────────────────

    public async Task<AdjustmentDto> ProposeAsync(
        int jobId, string tradieId, CreateAdjustmentRequest request)
    {
        var job = await _context.Jobs.Include(j => j.Adjustments).FirstOrDefaultAsync(j => j.Id == jobId)
            ?? throw new KeyNotFoundException($"Job {jobId} not found.");

        if (job.MatchedTradieId != tradieId)
            throw new UnauthorizedAccessException();

        if (job.Status is not (JobStatus.Booked or JobStatus.InProgress or JobStatus.AwaitingConfirmation))
            throw new InvalidOperationException(
                $"Adjustments can be proposed while Booked/InProgress/AwaitingConfirmation — job is '{job.Status}'.");

        // Config guard (P12-18): max simultaneous pending adjustments per job.
        var pending = job.Adjustments.Count(a => a.Status == AdjustmentStatus.Pending);
        if (pending >= _flowOptions.Value.MaxPendingAdjustmentsPerJob)
            throw new InvalidOperationException(
                $"This job already has {_flowOptions.Value.MaxPendingAdjustmentsPerJob} pending adjustments. Wait for the homeowner to respond.");

        var kind = Enum.TryParse<AdjustmentKind>(request.Kind, ignoreCase: true, out var k)
            ? k : AdjustmentKind.Other;

        var adjustment = new JobPriceAdjustment
        {
            JobId = jobId,
            ProposedByTradieId = tradieId,
            Kind = kind,
            Description = request.Description.Trim(),
            Amount = Math.Round(request.Amount, 2),
            EvidenceFileKey = string.IsNullOrWhiteSpace(request.EvidenceFileKey) ? null : request.EvidenceFileKey.Trim(),
            Status = AdjustmentStatus.Pending,
            CreatedAtUtc = DateTime.UtcNow,
        };

        _context.JobPriceAdjustments.Add(adjustment);
        await _context.SaveChangesAsync();

        // P12-18: expiry + reminder schedules.
        var expiryHours = Math.Max(1, _flowOptions.Value.AdjustmentExpiryHours);
        try
        {
            adjustment.ExpiryJobId = _hangfire.Schedule<AdjustmentExpiryJob>(
                j => j.ExecuteAsync(adjustment.Id), TimeSpan.FromHours(expiryHours));
            var reminderAt = TimeSpan.FromHours(Math.Max(1, expiryHours / 2));
            adjustment.ReminderJobId = _hangfire.Schedule<AdjustmentReminderJob>(
                j => j.ExecuteAsync(adjustment.Id), reminderAt);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not schedule expiry for adjustment {AdjustmentId}.", adjustment.Id);
        }

        // P12-18 guard: big adjustments get staff review.
        if (adjustment.Amount >= _flowOptions.Value.AdjustmentStaffReviewThreshold)
        {
            job.IsFlagged = true;
            job.FlagReason = $"Adjustment {adjustment.Id} ({adjustment.Amount:N2}) exceeds the staff-review threshold.";
            job.FlaggedAtUtc = DateTime.UtcNow;
            await _context.SaveChangesAsync();
            _logger.LogInformation(
                "Adjustment {AdjustmentId} on job {JobId} flagged for staff review ({Amount}).",
                adjustment.Id, jobId, adjustment.Amount);
        }

        await _audit.LogAsync(tradieId, "adjustment.propose", "JobPriceAdjustment",
            adjustment.Id.ToString(), null,
            new { adjustment.Id, adjustment.JobId, Kind = kind.ToString(), adjustment.Amount, adjustment.Description });

        _logger.LogInformation(
            "Adjustment {AdjustmentId} proposed on job {JobId} by tradie {TradieId}: {Kind} {Amount}.",
            adjustment.Id, jobId, tradieId, kind, adjustment.Amount);

        await BroadcastChangeAsync(jobId, adjustment, "AdjustmentProposed");
        await NotifyUserAsync(job.HomeownerId,
            "Extra cost request",
            $"\"{job.Title}\": {adjustment.Description} — {adjustment.Amount:N2}. Approve or decline in the app.",
            new Dictionary<string, string>
            {
                ["jobId"] = jobId.ToString(),
                ["adjustmentId"] = adjustment.Id.ToString(),
                ["type"] = "adjustment_proposed",
            });

        return ToDto(adjustment, job);
    }

    // ── Homeowner: approve / decline ─────────────────────────────────────────

    public async Task<AdjustmentDto> RespondAsync(
        int jobId, int adjustmentId, string homeownerId, RespondAdjustmentRequest request)
    {
        var job = await _context.Jobs.Include(j => j.Adjustments).FirstOrDefaultAsync(j => j.Id == jobId)
            ?? throw new KeyNotFoundException($"Job {jobId} not found.");

        if (job.HomeownerId != homeownerId)
            throw new UnauthorizedAccessException();

        var adjustment = job.Adjustments.FirstOrDefault(a => a.Id == adjustmentId)
            ?? throw new KeyNotFoundException($"Adjustment {adjustmentId} not found.");

        if (adjustment.Status != AdjustmentStatus.Pending)
            throw new InvalidOperationException($"Adjustment is already '{adjustment.Status}'.");

        adjustment.Status = request.Approve ? AdjustmentStatus.Approved : AdjustmentStatus.Declined;
        adjustment.RespondedAtUtc = DateTime.UtcNow;
        adjustment.ResponseNote = string.IsNullOrWhiteSpace(request.Note) ? null : request.Note.Trim();
        CancelSchedules(adjustment);

        // Running total: only Approved adjustments count (P12-17).
        RecomputeAdjustmentsTotal(job);

        await _context.SaveChangesAsync();

        await _audit.LogAsync(homeownerId, request.Approve ? "adjustment.approve" : "adjustment.decline",
            "JobPriceAdjustment", adjustmentId.ToString(),
            new { Status = "Pending" },
            new { adjustment.Status, adjustment.ResponseNote, job.AdjustmentsTotal });

        _logger.LogInformation(
            "Adjustment {AdjustmentId} {Status} on job {JobId}; AdjustmentsTotal={Total}.",
            adjustmentId, adjustment.Status, jobId, job.AdjustmentsTotal);

        await BroadcastChangeAsync(jobId, adjustment, request.Approve ? "AdjustmentApproved" : "AdjustmentDeclined");
        await NotifyUserAsync(job.MatchedTradieId ?? adjustment.ProposedByTradieId,
            request.Approve ? "Extra cost approved" : "Extra cost declined",
            $"\"{job.Title}\": the homeowner {(request.Approve ? "approved" : "declined")} \"{adjustment.Description}\".",
            new Dictionary<string, string>
            {
                ["jobId"] = jobId.ToString(),
                ["adjustmentId"] = adjustment.Id.ToString(),
                ["type"] = request.Approve ? "adjustment_approved" : "adjustment_declined",
            });

        return ToDto(adjustment, job);
    }

    // ── Tradie: withdraw ──────────────────────────────────────────────────────

    public async Task<AdjustmentDto> WithdrawAsync(int jobId, int adjustmentId, string tradieId)
    {
        var job = await _context.Jobs.Include(j => j.Adjustments).FirstOrDefaultAsync(j => j.Id == jobId)
            ?? throw new KeyNotFoundException($"Job {jobId} not found.");

        var adjustment = job.Adjustments.FirstOrDefault(a => a.Id == adjustmentId)
            ?? throw new KeyNotFoundException($"Adjustment {adjustmentId} not found.");

        if (adjustment.ProposedByTradieId != tradieId)
            throw new UnauthorizedAccessException();

        if (adjustment.Status != AdjustmentStatus.Pending)
            throw new InvalidOperationException($"Only pending adjustments can be withdrawn — this one is '{adjustment.Status}'.");

        adjustment.Status = AdjustmentStatus.Withdrawn;
        adjustment.RespondedAtUtc = DateTime.UtcNow;
        CancelSchedules(adjustment);

        RecomputeAdjustmentsTotal(job);
        await _context.SaveChangesAsync();

        await _audit.LogAsync(tradieId, "adjustment.withdraw", "JobPriceAdjustment",
            adjustmentId.ToString(), new { Status = "Pending" }, new { adjustment.Status });

        await BroadcastChangeAsync(jobId, adjustment, "AdjustmentWithdrawn");

        return ToDto(adjustment, job);
    }

    // ── List ─────────────────────────────────────────────────────────────────

    public async Task<List<AdjustmentDto>> ListAsync(int jobId, string requestingUserId)
    {
        var job = await _context.Jobs
            .Include(j => j.Adjustments).ThenInclude(a => a.ProposedByTradie)
            .FirstOrDefaultAsync(j => j.Id == jobId)
            ?? throw new KeyNotFoundException($"Job {jobId} not found.");

        if (job.HomeownerId != requestingUserId && job.MatchedTradieId != requestingUserId)
            throw new UnauthorizedAccessException();

        return job.Adjustments
            .OrderByDescending(a => a.CreatedAtUtc)
            .Select(a => ToDto(a, job))
            .ToList();
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /// <summary>Only Approved adjustments count toward the billed total (P12-17).</summary>
    private static void RecomputeAdjustmentsTotal(Job job)
    {
        var approved = job.Adjustments
            .Where(a => a.Status == AdjustmentStatus.Approved)
            .Sum(a => a.Amount);
        job.AdjustmentsTotal = Math.Round(approved, 2);
    }

    private void CancelSchedules(JobPriceAdjustment adjustment)
    {
        foreach (var id in new[] { adjustment.ExpiryJobId, adjustment.ReminderJobId })
        {
            if (string.IsNullOrEmpty(id)) continue;
            try { _hangfire.Delete(id); }
            catch (Exception ex) { _logger.LogWarning(ex, "Could not cancel Hangfire job {Id}.", id); }
        }
        adjustment.ExpiryJobId = null;
        adjustment.ReminderJobId = null;
    }

    private async Task BroadcastChangeAsync(int jobId, JobPriceAdjustment adjustment, string eventType)
    {
        var payload = new AdjustmentChangedPayload
        {
            EventType = eventType,
            JobId = jobId,
            AdjustmentId = adjustment.Id,
            AdjustmentStatus = adjustment.Status.ToString(),
            Amount = adjustment.Amount,
        };
        await _jobHub.Clients.Group(JobHub.GroupName(jobId))
            .SendAsync("JobAdjustmentChanged", payload);
    }

    private async Task NotifyUserAsync(string? userId, string title, string body, Dictionary<string, string> data)
    {
        if (string.IsNullOrEmpty(userId)) return;
        await _notifications.SendPushToUserAsync(userId, title, body, data);
    }

    private AdjustmentDto ToDto(JobPriceAdjustment adjustment, Job job)
    {
        DateTime? expiresAt = adjustment.Status == AdjustmentStatus.Pending
            ? adjustment.CreatedAtUtc.AddHours(Math.Max(1, _flowOptions.Value.AdjustmentExpiryHours))
            : null;

        // Evidence lives in the private payments container — a short-lived SAS,
        // never a public URL (P12-17). Synchronous best-effort SAS build via the
        // async-capable blob client is avoided; the read URL is generated lazily
        // by the dedicated evidence endpoint instead.

        return new AdjustmentDto
        {
            Id = adjustment.Id,
            JobId = adjustment.JobId,
            ProposedByTradieId = adjustment.ProposedByTradieId,
            ProposedByTradieName = string.IsNullOrWhiteSpace(adjustment.ProposedByTradie?.FullName)
                ? null : adjustment.ProposedByTradie.FullName,
            Kind = adjustment.Kind.ToString(),
            Description = adjustment.Description,
            Amount = adjustment.Amount,
            EvidenceUrl = string.IsNullOrEmpty(adjustment.EvidenceFileKey)
                ? null : $"/api/jobs/{job.Id}/adjustments/{adjustment.Id}/evidence",
            Status = adjustment.Status.ToString(),
            CreatedAtUtc = adjustment.CreatedAtUtc,
            RespondedAtUtc = adjustment.RespondedAtUtc,
            ResponseNote = adjustment.ResponseNote,
            ExpiresAtUtc = expiresAt,
        };
    }
}

/// <summary>SignalR payload for adjustment lifecycle events (P12-18).</summary>
public class AdjustmentChangedPayload
{
    /// <summary>"AdjustmentProposed" | "AdjustmentApproved" | "AdjustmentDeclined" | "AdjustmentWithdrawn" | "AdjustmentExpired".</summary>
    public string EventType { get; set; } = string.Empty;
    public int JobId { get; set; }
    public int AdjustmentId { get; set; }
    public string AdjustmentStatus { get; set; } = string.Empty;
    public decimal Amount { get; set; }
}
