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
/// v1 flow (P5-04): auto-completes a job if the homeowner hasn't confirmed after
/// 48 hours in AwaitingConfirmation.
///
/// v2 flow (P12-12): the 48h trigger becomes AUTO-APPROVE — the homeowner's
/// silence counts as accepting the final amount, but ONLY when nothing is
/// pending and the amount is inside tolerance (or under the no-estimate cap).
/// Otherwise the job escalates to staff instead of silently approving a higher
/// bill. It never cancels finished work.
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
    private readonly FixoApi.Options.JobFlowOptions _flowOptions;

    public AutoCompleteJob(
        FixoDbContext context,
        IJobStatusService jobStatus,
        PushNotificationService push,
        IBackgroundJobClient hangfire,
        Microsoft.Extensions.Options.IOptions<FixoApi.Options.JobFlowOptions> flowOptions,
        ILogger<AutoCompleteJob> logger)
    {
        _context = context;
        _jobStatus = jobStatus;
        _push = push;
        _hangfire = hangfire;
        _flowOptions = flowOptions.Value;
        _logger = logger;
    }

    [AutomaticRetry(Attempts = 0)]
    public async Task ExecuteAsync(int jobId)
    {
        var job = await _context.Jobs
            .Include(j => j.Adjustments)
            .FirstOrDefaultAsync(j => j.Id == jobId);
        if (job is null)
        {
            _logger.LogWarning("AutoCompleteJob: job {JobId} not found — skipping.", jobId);
            return;
        }

        // Only act while still in AwaitingConfirmation.
        if (job.Status != JobStatus.AwaitingConfirmation)
        {
            _logger.LogInformation("AutoCompleteJob: job {JobId} is {Status} — no auto action.", jobId, job.Status);
            return;
        }

        if (job.FlowVersion < 2)
        {
            // ── Legacy v1: auto-complete as before (P5-04) ───────────────────
            _logger.LogInformation("AutoCompleteJob: auto-completing job {JobId} after {Hours} hours.", jobId, AutoCompleteHours);

            await _jobStatus.TransitionAsync(
                jobId, JobStatus.Completed, SystemUserId, UserRole.Staff,
                ReasonCode.no_response, $"Auto-completed after {AutoCompleteHours}h without homeowner confirmation.");
            await NotifyRecipientsAsync(job, "Job completed", $"Job \"{job.Title}\" has been auto-completed.", "auto_complete");
            return;
        }

        // ── v2 (P12-12): auto-approve with guards ────────────────────────────
        var pendingAdjustments = job.Adjustments.Any(a => a.Status == Enums.AdjustmentStatus.Pending);
        var finalAmount = job.FinalAmount ?? 0m;

        var canAutoApprove = Services.JobMoney.CanAutoApprove(
            finalAmount, job.EstimatedTotal, pendingAdjustments,
            _flowOptions.EstimateTolerancePercent, _flowOptions.AutoApproveNoEstimateCap);

        if (!canAutoApprove)
        {
            // Never silently approve a higher bill — escalate to staff. The job
            // stays in AwaitingConfirmation so a human decides.
            _logger.LogWarning(
                "AutoCompleteJob: job {JobId} needs staff review (pending={Pending}, final={Final}, estimate={Estimate}).",
                jobId, pendingAdjustments, finalAmount, job.EstimatedTotal);

            job.IsFlagged = true;
            job.FlagReason = "Completion escalated for staff review: amount outside tolerance or pending adjustments at auto-approve time.";
            job.FlaggedAtUtc = DateTime.UtcNow;
            job.UpdatedAtUtc = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            await NotifyRecipientsAsync(job,
                "Approval needs review",
                $"Job \"{job.Title}\" needs staff review before the amount can be approved.",
                "auto_approve_escalated");
            return;
        }

        _logger.LogInformation(
            "AutoCompleteJob: auto-approving job {JobId} after {Hours}h (final={Final}).",
            jobId, AutoCompleteHours, finalAmount);

        // The homeowner's silence counts as approval → payment step opens.
        await _jobStatus.TransitionAsync(
            jobId, JobStatus.AwaitingPayment, SystemUserId, UserRole.Staff,
            ReasonCode.no_response, $"Auto-approved after {AutoCompleteHours}h without homeowner response.");

        await NotifyRecipientsAsync(job, "Job approved automatically",
            $"Job \"{job.Title}\" moved to payment — the final amount of {finalAmount:N2} was approved automatically after 48h.",
            "auto_approved");
    }

    private async Task NotifyRecipientsAsync(Job job, string title, string body, string type)
    {
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

                foreach (var token in tokens)
                {
                    await _push.SendAsync(token, title, body,
                        new Dictionary<string, string>
                        {
                            ["jobId"] = job.Id.ToString(),
                            ["type"] = type
                        });
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "FCM push to {UserId} about auto action for job {JobId} failed.", userId, job.Id);
            }
        }
    }
}