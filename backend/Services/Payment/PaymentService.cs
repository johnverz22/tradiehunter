using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Threading;
using System.Threading.Tasks;

namespace FixoApi.Services;

/// <inheritdoc cref="IPaymentService"/>
public class PaymentService : IPaymentService
{
    /// <summary>How long a receipt SAS stays valid — long enough to open and read it.</summary>
    private static readonly TimeSpan ReceiptSasLifetime = TimeSpan.FromMinutes(15);

    private readonly FixoDbContext _db;
    private readonly IJobStatusService _jobStatus;
    private readonly IBlobStorageService _blob;
    private readonly IPaymentProvider _provider;
    private readonly PushNotificationService _push;
    private readonly IEmailSender _email;
    private readonly IAuditLogService _audit;
    private readonly IOptions<PaymentOptions> _paymentOptions;
    private readonly IOptions<LocaleOptions> _locale;
    private readonly ILogger<PaymentService> _logger;

    public PaymentService(
        FixoDbContext db,
        IJobStatusService jobStatus,
        IBlobStorageService blob,
        IPaymentProvider provider,
        PushNotificationService push,
        IEmailSender email,
        IAuditLogService audit,
        IOptions<PaymentOptions> paymentOptions,
        IOptions<LocaleOptions> locale,
        ILogger<PaymentService> logger)
    {
        _db = db;
        _jobStatus = jobStatus;
        _blob = blob;
        _provider = provider;
        _push = push;
        _email = email;
        _audit = audit;
        _paymentOptions = paymentOptions;
        _locale = locale;
        _logger = logger;
    }

    private string ReceiptsContainer => _paymentOptions.Value.PaymentsContainer;

    // ── Homeowner: instructions & receipt upload (P4-03, P4-04) ───────────────

    public async Task<PaymentStatusDto> GetPaymentAsync(
        int jobId, string homeownerUserId, CancellationToken ct = default)
    {
        var job = await LoadOwnedJobAsync(jobId, homeownerUserId, ct);
        var payment = await GetOrCreatePaymentAsync(job, ct);
        return MapToDto(job, payment);
    }

    public async Task<PaymentStatusDto> UploadReceiptAsync(
        int jobId, string homeownerUserId, ReceiptUpload receipt, CancellationToken ct = default)
    {
        var job = await LoadOwnedJobAsync(jobId, homeownerUserId, ct);

        if (job.Status != JobStatus.AwaitingPayment)
            throw new InvalidOperationException(
                $"Job {jobId} is '{job.Status}' — a receipt can only be uploaded while awaiting payment.");

        var payment = await GetOrCreatePaymentAsync(job, ct);

        if (payment.Status == PaymentStatus.Verified)
            throw new InvalidOperationException($"Payment {payment.Id} is already verified.");

        // Buffer once: the same bytes feed the duplicate check and the upload.
        byte[] bytes;
        await using (var buffer = new MemoryStream())
        {
            await receipt.Content.CopyToAsync(buffer, ct);
            bytes = buffer.ToArray();
        }

        var hash = Convert.ToHexString(SHA256.HashData(bytes));

        // P4-03: a receipt image is evidence of one specific bank line. Re-using
        // one screenshot across jobs would let a single transfer book two tradies.
        if (string.Equals(payment.ReceiptHash, hash, StringComparison.Ordinal))
            throw new InvalidOperationException(
                "This exact receipt was already submitted for this job and was not accepted. "
                + "Upload the corrected bank receipt.");

        var reused = await _db.Payments
            .Where(p => p.ReceiptHash == hash && p.Id != payment.Id)
            .Select(p => new { p.JobId })
            .FirstOrDefaultAsync(ct);
        if (reused is not null)
            throw new InvalidOperationException(
                "This receipt has already been uploaded for another payment. "
                + "Upload the original bank receipt.");

        // Replace the superseded blob so rejections don't leak private documents.
        if (!string.IsNullOrEmpty(payment.ReceiptFileKey))
        {
            try { await _blob.DeleteAsync(payment.ReceiptFileKey, ReceiptsContainer); }
            catch (Exception ex) { _logger.LogWarning(ex, "Could not delete superseded receipt {Key}", payment.ReceiptFileKey); }
        }

        var extension = Path.GetExtension(receipt.FileName);
        if (string.IsNullOrWhiteSpace(extension)) extension = ".bin";

        var key = $"payments/{jobId}/{Guid.NewGuid()}{extension}";
        using (var content = new MemoryStream(bytes, writable: false))
        {
            await _blob.UploadAsync(content, key, receipt.ContentType, ReceiptsContainer);
        }

        var submittedAt = DateTime.UtcNow;
        payment.ReceiptFileKey  = key;
        payment.ReceiptHash     = hash;
        payment.Status          = PaymentStatus.Submitted;
        payment.SubmittedAtUtc  = submittedAt;
        payment.UpdatedAtUtc    = submittedAt;
        payment.RejectReason    = null;
        await _db.SaveChangesAsync(ct);

        _logger.LogInformation(
            "Receipt {Hash} uploaded for payment {PaymentId} (job {JobId}) by {UserId}.",
            hash[..12], payment.Id, jobId, homeownerUserId);

        // AwaitingPayment → PaymentReview parks the job in the admin queue.
        // IJobStatusService owns the transition, its history row and the broadcast.
        await _jobStatus.TransitionAsync(
            jobId, JobStatus.PaymentReview, homeownerUserId, UserRole.Homeowner);

        return MapToDto(job, payment);
    }

    // ── Admin queue (P4-05) ─────────────────────────────────────────────────

    public async Task<PagedResult<PendingPaymentDto>> GetPendingPaymentsAsync(
        int page, int pageSize, CancellationToken ct = default)
    {
        var query = _db.Payments
            .Include(p => p.Job).ThenInclude(j => j.Homeowner)
            .Where(p => p.Status == PaymentStatus.Submitted)
            .OrderBy(p => p.SubmittedAtUtc);

        var total = await query.CountAsync(ct);

        var payments = await query
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(ct);

        var items = new List<PendingPaymentDto>(payments.Count);
        foreach (var p in payments)
            items.Add(await MapToPendingDtoAsync(p, ct));

        return new PagedResult<PendingPaymentDto>
        {
            Items = items,
            TotalCount = total,
            Page = page,
            PageSize = pageSize,
        };
    }

    public async Task<PaymentActionResult> VerifyPaymentAsync(
        int paymentId, string adminUserId, UserRole actorRole, CancellationToken ct = default)
    {
        var payment = await _db.Payments
            .Include(p => p.Job).ThenInclude(j => j.Homeowner)
            .FirstOrDefaultAsync(p => p.Id == paymentId, ct);

        if (payment is null) return new PaymentActionResult { NotFound = true };

        if (payment.Status != PaymentStatus.Submitted)
            return new PaymentActionResult
            {
                Conflict = true,
                Error = $"Payment {paymentId} is '{payment.Status}' — only submitted receipts can be verified.",
            };

        var verifiedAt = DateTime.UtcNow;
        var paymentBefore = new { payment.Id, Status = payment.Status.ToString() };
        payment.Status         = PaymentStatus.Verified;
        payment.VerifiedBy     = adminUserId;
        payment.VerifiedAtUtc  = verifiedAt;
        payment.UpdatedAtUtc   = verifiedAt;
        payment.RejectReason   = null;
        await _db.SaveChangesAsync(ct);

        // PaymentReview → Booked releases the tradie. The expiry job becomes a
        // no-op on its next run (payment is Verified, job is Booked).
        await _jobStatus.TransitionAsync(
            payment.JobId, JobStatus.Booked, adminUserId, actorRole,
            note: "Payment verified.");

        _logger.LogInformation(
            "Payment {PaymentId} (job {JobId}) verified by {AdminId}.",
            paymentId, payment.JobId, adminUserId);

        await _audit.LogAsync(adminUserId, "payment.verify", "Payment", paymentId.ToString(),
            paymentBefore, new { payment.Id, Status = payment.Status.ToString(), payment.VerifiedBy });

        await NotifyHomeownerAsync(
            payment, "Payment confirmed",
            $"We verified your transfer for {payment.Job.Title}. Your tradie is booked.",
            ct);

        return new PaymentActionResult { Succeeded = true, Payment = MapToDto(payment.Job, payment) };
    }

    public async Task<PaymentActionResult> RejectPaymentAsync(
        int paymentId, string adminUserId, UserRole actorRole, string reason, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(reason))
            return new PaymentActionResult { Error = "A reason is required when rejecting a payment." };

        var payment = await _db.Payments
            .Include(p => p.Job).ThenInclude(j => j.Homeowner)
            .FirstOrDefaultAsync(p => p.Id == paymentId, ct);

        if (payment is null) return new PaymentActionResult { NotFound = true };

        if (payment.Status != PaymentStatus.Submitted)
            return new PaymentActionResult
            {
                Conflict = true,
                Error = $"Payment {paymentId} is '{payment.Status}' — only submitted receipts can be rejected.",
            };

        payment.Status       = PaymentStatus.Rejected;
        payment.RejectReason = reason.Trim();
        // P4-05: each send-back is counted so the homeowner sees how many
        // attempts it has taken, and staff can spot a payment that keeps failing.
        payment.ReUploadCount += 1;
        payment.UpdatedAtUtc  = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);
        // PaymentReview → AwaitingPayment re-opens the payment window. The
        // transition also re-baselines Job.PaymentDueAtUtc and re-schedules the
        // expiry job, so the homeowner gets a fresh deadline.
        await _jobStatus.TransitionAsync(
            payment.JobId, JobStatus.AwaitingPayment, adminUserId, actorRole,
            note: $"Payment rejected: {payment.RejectReason}");

        _logger.LogInformation(
            "Payment {PaymentId} (job {JobId}) rejected by {AdminId}: {Reason}",
            paymentId, payment.JobId, adminUserId, payment.RejectReason);

        await _audit.LogAsync(adminUserId, "payment.reject", "Payment", paymentId.ToString(),
            new { payment.Id, Status = "Submitted" },
            new { payment.Id, Status = payment.Status.ToString(), payment.RejectReason });

        await NotifyHomeownerAsync(
            payment, "Payment receipt needs fixing",
            $"We couldn't accept the receipt for {payment.Job.Title}. {payment.RejectReason}",
            ct);

        return new PaymentActionResult { Succeeded = true, Payment = MapToDto(payment.Job, payment) };
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private async Task<Job> LoadOwnedJobAsync(int jobId, string homeownerUserId, CancellationToken ct)
    {
        var job = await _db.Jobs
            .Include(j => j.Homeowner)
            .FirstOrDefaultAsync(j => j.Id == jobId, ct)
            ?? throw new KeyNotFoundException($"Job {jobId} not found.");

        if (job.HomeownerId != homeownerUserId)
            throw new KeyNotFoundException($"Job {jobId} not found.");

        return job;
    }

    /// <summary>
    /// Returns the job's single payment, opening one on first access. A homeowner
    /// opening the payment screen is what starts the clock, so instructions can be
    /// fetched repeatedly without creating duplicates.
    /// </summary>
    private async Task<Payment> GetOrCreatePaymentAsync(Job job, CancellationToken ct)
    {
        var existing = await _db.Payments.FirstOrDefaultAsync(p => p.JobId == job.Id, ct);
        if (existing is not null) return existing;

        var options = _paymentOptions.Value;
        var reference = options.BuildReference(job.Id);

        var payment = new Payment
        {
            JobId             = job.Id,
            Amount            = job.TotalAmount,
            Currency          = _locale.Value.DefaultCurrency,
            Method            = "BankTransfer",
            Provider          = _provider.Name,
            ProviderReference = reference,
            Status            = PaymentStatus.Pending,
            CreatedAtUtc      = DateTime.UtcNow,
        };

        var result = await _provider.CreatePaymentAsync(
            new PaymentRequest
            {
                JobId         = job.Id,
                Amount        = job.TotalAmount,
                Currency      = payment.Currency,
                PayerUserId   = job.HomeownerId,
                Reference     = reference,
            }, ct);
        payment.ProviderReference = result.ProviderReference;

        _db.Payments.Add(payment);
        try
        {
            await _db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException)
        {
            // Two devices opened the payment screen at once; the unique index on
            // JobId decided the winner. Re-read and use that row.
            _db.ChangeTracker.Clear();
            var winner = await _db.Payments.FirstOrDefaultAsync(p => p.JobId == job.Id, ct);
            if (winner is null) throw;
            return winner;
        }

        // Give the job a deadline if the state machine did not already set one.
        if (job.PaymentDueAtUtc is null)
        {
            job.PaymentDueAtUtc = DateTime.UtcNow.AddHours(WindowHours(options));
            await _db.SaveChangesAsync(ct);
        }

        return payment;
    }

    private static int WindowHours(PaymentOptions options) => Math.Max(0, options.WindowHours);

    private async Task<PendingPaymentDto> MapToPendingDtoAsync(Payment p, CancellationToken ct)
    {
        var receiptUrl = string.Empty;
        if (!string.IsNullOrEmpty(p.ReceiptFileKey))
        {
            try
            {
                receiptUrl = (await _blob.GetReadSasUriAsync(
                    p.ReceiptFileKey, ReceiptsContainer, ReceiptSasLifetime)).ToString();
            }
            catch (Exception ex)
            {
                // A missing blob must not take the whole queue down — the row
                // still needs verifying, so surface it without a URL.
                _logger.LogError(ex, "Could not issue receipt SAS for payment {PaymentId}", p.Id);
            }
        }

        return new PendingPaymentDto
        {
            Id             = p.Id,
            JobId          = p.JobId,
            JobTitle       = p.Job.Title,
            HomeownerName  = p.Job.Homeowner?.FullName ?? "Unknown",
            HomeownerEmail = p.Job.Homeowner?.Email ?? string.Empty,
            Amount         = p.Amount,
            Currency       = p.Currency,
            Reference      = p.ProviderReference,
            Status         = p.Status.ToString(),
            Method         = p.Method,
            SubmittedAtUtc = p.SubmittedAtUtc,
            ReUploadCount  = p.ReUploadCount,
            MinutesSinceSubmission = p.SubmittedAtUtc.HasValue ? (int)(DateTime.UtcNow - p.SubmittedAtUtc.Value).TotalMinutes : 0,
            ReceiptUrl     = receiptUrl,
        };
    }

    private PaymentStatusDto MapToDto(Job job, Payment payment)
    {
        var isSettled = payment.Status == PaymentStatus.Verified;
        return new PaymentStatusDto
        {
            PaymentId       = payment.Id,
            JobId           = job.Id,
            JobTitle        = job.Title,
            JobStatus       = job.Status.ToString(),
            Amount          = payment.Amount,
            Currency        = payment.Currency,
            Method          = payment.Method,
            Provider        = payment.Provider,
            Reference       = payment.ProviderReference,
            Status          = payment.Status.ToString(),
            // Once verified the transfer details are noise to the homeowner.
            BankDetails     = isSettled ? null : MapBankDetails(),
            DueAtUtc        = job.PaymentDueAtUtc ?? payment.CreatedAtUtc.AddHours(
                                  WindowHours(_paymentOptions.Value)),
            SubmittedAtUtc  = payment.SubmittedAtUtc,
            VerifiedAtUtc   = payment.VerifiedAtUtc,
            RejectReason    = payment.RejectReason,
            ReUploadCount   = payment.ReUploadCount,
            CreatedAtUtc    = payment.CreatedAtUtc,
            // The job sits in PaymentReview while staff hold the receipt, so the
            // picker only re-opens after a rejection has sent the job back.
            CanUploadReceipt = job.Status == JobStatus.AwaitingPayment
                               && payment.Status is not (PaymentStatus.Submitted or PaymentStatus.Verified),
        };
    }

    private BankDetailsDto MapBankDetails()
    {
        var options = _paymentOptions.Value;
        return new BankDetailsDto
        {
            AccountName    = options.AccountName,
            AccountNumber  = options.AccountNumber,
        };
    }

    /// <summary>
    /// Best-effort push + email to the homeowner. A payment transition is already
    /// committed by the time this runs, so notification failures are logged and
    /// swallowed rather than surfaced as a failed request.
    /// </summary>
    private async Task NotifyHomeownerAsync(Payment payment, string title, string body, CancellationToken ct)
    {
        var homeowner = payment.Job.Homeowner;
        if (homeowner is null) return;

        try
        {
            var tokens = await _db.DeviceTokens
                .Where(dt => dt.UserId == homeowner.Id)
                .Select(dt => dt.Token)
                .ToListAsync(ct);

            foreach (var token in tokens)
            {
                await _push.SendAsync(token, title, body, new Dictionary<string, string>
                {
                    ["jobId"]     = payment.JobId.ToString(),
                    ["paymentId"] = payment.Id.ToString(),
                });
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "FCM push to homeowner {UserId} failed.", homeowner.Id);
        }

        if (string.IsNullOrEmpty(homeowner.Email)) return;

        try
        {
            if (payment.Status == PaymentStatus.Verified)
                await _email.SendPaymentVerifiedAsync(
                    homeowner.Email, payment.Job.Title, payment.Amount, payment.Currency);
            else if (payment.Status == PaymentStatus.Rejected)
                await _email.SendPaymentRejectedAsync(
                    homeowner.Email, payment.Job.Title, payment.RejectReason ?? string.Empty,
                    payment.Job.PaymentDueAtUtc ?? DateTime.UtcNow.AddHours(
                        WindowHours(_paymentOptions.Value)));
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Payment notification email to {Email} failed.", homeowner.Email);
        }
    }
}
