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
/// Expires a job whose manual payment was never verified (P4-06).
///
/// Armed by <see cref="JobStatusService"/> every time a job enters
/// <c>AwaitingPayment</c>. The job does not trust its own fire time: it re-reads
/// <c>Job.PaymentDueAtUtc</c>, because rejecting a receipt restarts the
/// homeowner's payment window and re-arms this job — a request enqueued under the
/// old deadline must not expire the job early. When that happens it re-schedules
/// itself for the remaining time and exits.
///
/// Safe to run more than once: every path is guarded by the current job status
/// and the payment's own state.
/// </summary>
public class PaymentExpiryJob
{
    /// <summary>Actor recorded on automated transitions, same as offer timeouts.</summary>
    internal const string SystemUserId = "system";

    private readonly FixoDbContext _context;
    private readonly IJobStatusService _jobStatus;
    private readonly PushNotificationService _push;
    private readonly IBackgroundJobClient _hangfire;
    private readonly ILogger<PaymentExpiryJob> _logger;

    public PaymentExpiryJob(
        FixoDbContext context,
        IJobStatusService jobStatus,
        PushNotificationService push,
        IBackgroundJobClient hangfire,
        ILogger<PaymentExpiryJob> logger)
    {
        _context   = context;
        _jobStatus = jobStatus;
        _push      = push;
        _hangfire  = hangfire;
        _logger    = logger;
    }

    /// <summary>
    /// Called by Hangfire at the payment deadline. Side effects must fire exactly
    /// once, so retries are disabled — a re-run is a no-op by construction.
    /// </summary>
    [AutomaticRetry(Attempts = 0)]
    public async Task ExecuteAsync(int jobId)
    {
        var job = await _context.Jobs.FirstOrDefaultAsync(j => j.Id == jobId);
        if (job is null)
        {
            _logger.LogWarning("PaymentExpiryJob: job {JobId} not found — skipping.", jobId);
            return;
        }

        if (job.Status is not (JobStatus.AwaitingPayment or JobStatus.PaymentReview))
        {
            _logger.LogInformation(
                "PaymentExpiryJob: job {JobId} is {Status} — nothing to expire.", jobId, job.Status);
            return;
        }

        var payment = await _context.Payments.FirstOrDefaultAsync(p => p.JobId == jobId);
        if (payment?.Status == PaymentStatus.Verified)
        {
            _logger.LogInformation("PaymentExpiryJob: payment {PaymentId} verified — skipping.", payment.Id);
            return;
        }

        // The window was re-baselined (staff rejected the receipt) — come back later.
        if (job.PaymentDueAtUtc is { } dueAt && DateTime.UtcNow < dueAt)
        {
            _logger.LogInformation(
                "PaymentExpiryJob: deadline for job {JobId} moved to {DueAtUtc} — rescheduling.", jobId, dueAt);
            _hangfire.Schedule<PaymentExpiryJob>(j => j.ExecuteAsync(jobId), dueAt);
            return;
        }

        if (payment is not null && payment.Status != PaymentStatus.Expired)
        {
            payment.Status       = PaymentStatus.Expired;
            payment.UpdatedAtUtc = DateTime.UtcNow;
            await _context.SaveChangesAsync();
        }

        _logger.LogInformation(
            "PaymentExpiryJob: job {JobId} expired — payment window elapsed without verification.", jobId);

        // AwaitingPayment|PaymentReview → Expired. IJobStatusService writes the
        // history row and broadcasts over SignalR, so both clients see the job drop
        // out of the tradie's active pipeline — that is what frees the tradie.
        await _jobStatus.TransitionAsync(
            jobId, JobStatus.Expired, SystemUserId, UserRole.Staff,
            ReasonCode.no_payment, "Payment window elapsed without verification.");

        await NotifyAsync(job);
    }

    /// <summary>Tell both parties the job lapsed. Best effort — the job is already closed.</summary>
    private async Task NotifyAsync(Job job)
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
                    await _push.SendAsync(token, "Job expired", $"{job.Title} expired — payment was not completed.",
                        new Dictionary<string, string> { ["jobId"] = job.Id.ToString() });
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "FCM push to {UserId} about expiring job {JobId} failed.", userId, job.Id);
            }
        }
    }
}
