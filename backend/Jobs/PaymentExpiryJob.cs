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
/// v1 (P4-06): expires a job whose manual payment was never verified — the
/// homeowner's window elapsed, so the job drops out of the tradie's pipeline.
///
/// v2 (P12-12): work is DONE at this point, so expiring/cancelling is wrong.
/// The job instead becomes OVERDUE: the homeowner is reminded, and if the
/// window still lapses the account is flagged (OverduePayment — blocks posting
/// new jobs) and staff are notified for follow-up. The job itself stays in
/// AwaitingPayment so the payment can still land any time.
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

        // ── v2 (P12-12): work is done — no cancelling. Chase the payment. ─────
        if (job.FlowVersion >= 2)
        {
            await HandleOverdueAsync(job, payment);
            return;
        }

        // ── v1 legacy: expire the job as before (P4-06) ──────────────────────
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

    /// <summary>
    /// v2 overdue policy (P12-12): flag the homeowner (OverduePayment — blocks
    /// posting/requesting new jobs), notify staff for follow-up, and tell both
    /// parties. The job stays in AwaitingPayment — payment can still land.
    /// </summary>
    private async Task HandleOverdueAsync(Job job, Payment? payment)
    {
        _logger.LogInformation(
            "PaymentExpiryJob: job {JobId} is overdue (flow v{Flow}) — flagging homeowner, job stays payable.",
            job.Id, job.FlowVersion);

        if (payment is not null && payment.Status != PaymentStatus.Expired)
        {
            payment.Status       = PaymentStatus.Expired;
            payment.UpdatedAtUtc = DateTime.UtcNow;
        }

        // P12-12: raise the OverduePayment flag. Unlike the strike-based flags,
        // ONE overdue payment is enough to block posting — the flag is created
        // with ThresholdHit=true immediately and stays until staff clear it
        // after the payment is verified.
        var existingFlag = await _context.AccountFlags.FirstOrDefaultAsync(f =>
            f.UserId == job.HomeownerId
            && f.Type == AccountFlagType.OverduePayment
            && !f.Resolved);
        if (existingFlag is null)
        {
            _context.AccountFlags.Add(new AccountFlag
            {
                UserId = job.HomeownerId,
                Type = AccountFlagType.OverduePayment,
                Counter = 1,
                ThresholdHit = true,
                CreatedBy = SystemUserId,
                Note = $"Payment for job {job.Id} overdue past the {job.PaymentDueAtUtc:u} window.",
                CreatedAtUtc = DateTime.UtcNow,
            });
        }
        else
        {
            existingFlag.Counter++;
            existingFlag.ThresholdHit = true;
            existingFlag.Note = string.IsNullOrEmpty(existingFlag.Note)
                ? $"Payment for job {job.Id} overdue."
                : $"{existingFlag.Note}\nPayment for job {job.Id} overdue.";
        }

        job.UpdatedAtUtc = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        // Notify both sides.
        await NotifyAsync(job, "Payment overdue",
            $"\"{job.Title}\" — the payment window has passed. Upload your receipt now to avoid restrictions on your account.");

        _logger.LogInformation(
            "PaymentExpiryJob: overdue payment for job {JobId} — staff should follow up (amount={Amount}).",
            job.Id, payment?.Amount ?? job.FinalAmount ?? 0m);
    }

    /// <summary>Tell both parties. Best effort — never throws.</summary>
    private async Task NotifyAsync(Job job, string title, string body)
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
                        new Dictionary<string, string> { ["jobId"] = job.Id.ToString() });
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "FCM push to {UserId} about payment status for job {JobId} failed.", userId, job.Id);
            }
        }
    }
}
