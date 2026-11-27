using FixoApi.Data;
using FixoApi.Email;
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
    private readonly INotificationService _notifications;
    private readonly IEmailSender _email;
    private readonly IAuditLogService _audit;
    private readonly IOptions<PaymentOptions> _paymentOptions;
    private readonly IOptions<LocaleOptions> _locale;
    private readonly ILogger<PaymentService> _logger;
    private readonly IAccountFlagService _accountFlagService;

    public PaymentService(
        FixoDbContext db,
        IJobStatusService jobStatus,
        IBlobStorageService blob,
        IPaymentProvider provider,
        INotificationService notifications,
        IEmailSender email,
        IAuditLogService audit,
        IOptions<PaymentOptions> paymentOptions,
        IOptions<LocaleOptions> locale,
        ILogger<PaymentService> logger,
        IAccountFlagService accountFlagService)
    {
        _db = db;
        _jobStatus = jobStatus;
        _blob = blob;
        _provider = provider;
        _notifications = notifications;
        _email = email;
        _audit = audit;
        _paymentOptions = paymentOptions;
        _locale = locale;
        _logger = logger;
        _accountFlagService = accountFlagService;
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

        // N5.1: alert staff that a receipt is awaiting verification.
        await _notifications.SendToStaffAsync(new StaffAlert(
            EventKey: NotificationEvents.ReceiptAwaitingVerification,
            EntityKey: $"payment:{payment.Id}",
            Heading: $"Receipt awaiting verification — job #{jobId}",
            Body: $"A homeowner uploaded a payment receipt for \"{job.Title}\" (#{jobId}) and it is waiting for staff verification.",
            Rows:
            [
                new EmailSummaryRow("Job", $"{job.Title} (#{jobId})"),
                new EmailSummaryRow("Amount", Money.Format(payment.Amount, payment.Currency), Emphasize: true),
            ],
            AdminPath: "/payments"), ct);

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

    public async Task<PagedResult<OverduePaymentDto>> GetOverduePaymentsAsync(
        int page, int pageSize, CancellationToken ct = default)
    {
        // v2-flow jobs whose approved work is unpaid past the window. v1 jobs
        // keep the old expiry path, so they never appear here.
        var now = DateTime.UtcNow;
        var query = _db.Jobs
            .Include(j => j.Homeowner)
            .Include(j => j.Payment)
            .Where(j => j.FlowVersion >= 2
                        && j.Status == JobStatus.AwaitingPayment
                        && j.PaymentDueAtUtc != null
                        && j.PaymentDueAtUtc < now)
            .OrderBy(j => j.PaymentDueAtUtc);

        var total = await query.CountAsync(ct);

        var jobs = await query
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(ct);

        // GST label driver (D8): the matched tradie's registration flag.
        var tradieIds = jobs
            .Where(j => j.MatchedTradieId != null)
            .Select(j => j.MatchedTradieId!)
            .Distinct()
            .ToList();
        var gstFlags = tradieIds.Count == 0
            ? new Dictionary<string, bool>()
            : await _db.TradieProfiles
                .Where(p => tradieIds.Contains(p.UserId))
                .ToDictionaryAsync(p => p.UserId, p => p.IsGstRegistered, ct);

        var items = jobs.Select(j => new OverduePaymentDto
        {
            JobId = j.Id,
            JobTitle = j.Title,
            HomeownerName = j.Homeowner?.FullName ?? "Unknown",
            HomeownerEmail = j.Homeowner?.Email ?? string.Empty,
            Amount = j.Payment?.Amount ?? j.FinalAmount ?? j.EstimatedTotal ?? 0m,
            Currency = j.Payment?.Currency ?? "NZD",
            Reference = j.Payment?.ProviderReference ?? string.Empty,
            PaymentDueAtUtc = j.PaymentDueAtUtc,
            DaysOverdue = j.PaymentDueAtUtc.HasValue
                ? Math.Max(0, (int)(now - j.PaymentDueAtUtc.Value).TotalDays)
                : 0,
            IsGstRegistered = j.MatchedTradieId != null
                && gstFlags.TryGetValue(j.MatchedTradieId, out var gst)
                ? gst : null,
        }).ToList();

        return new PagedResult<OverduePaymentDto>
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
            .Include(p => p.Job).ThenInclude(j => j.MatchedTradie)
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

        // v1 (P4-05): PaymentReview → Booked releases the tradie.
        // v2 (P12-13/16): the work is already done — verification COMPLETES the
        // job, and the payout is created on that edge by IJobStatusService.
        var targetStatus = payment.Job.FlowVersion >= 2 ? JobStatus.Completed : JobStatus.Booked;
        await _jobStatus.TransitionAsync(
            payment.JobId, targetStatus, adminUserId, actorRole,
            note: "Payment verified.");

        // P12-12: Auto-clear OverduePayment flag on homeowner if outstanding overdue payment(s) are resolved.
        await _accountFlagService.ResolveOverdueFlagAsync(
            payment.Job.HomeownerId,
            adminUserId,
            $"Payment for job {payment.JobId} verified.");

        _logger.LogInformation(
            "Payment {PaymentId} (job {JobId}) verified by {AdminId} — job now {Status}.",
            paymentId, payment.JobId, adminUserId, targetStatus);

        await _audit.LogAsync(adminUserId, "payment.verify", "Payment", paymentId.ToString(),
            paymentBefore, new { payment.Id, Status = payment.Status.ToString(), payment.VerifiedBy });

        // P12-16: copy matches the flow — v2 verification closes the job, v1 books it.
        await NotifyHomeownerAsync(
            payment, "Payment confirmed",
            payment.Job.FlowVersion >= 2
                ? $"We verified your transfer for {payment.Job.Title}. The job is complete — thanks!"
                : $"We verified your transfer for {payment.Job.Title}. Your tradie is booked.",
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
            .Include(p => p.Job).ThenInclude(j => j.MatchedTradie)
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
            payment, "Receipt needs another look",
            $"Upload a corrected receipt for \"{payment.Job.Title}\" by " +
            $"{NzTime.Short(payment.Job.PaymentDueAtUtc ?? DateTime.UtcNow.AddHours(WindowHours(_paymentOptions.Value)))}.",
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

        // v1.7 (P12-13): the payment amount is the APPROVED final amount —
        // labour + approved adjustments, computed at check-out. Legacy jobs
        // (which still carry only the fixed estimate) keep their old behavior.
        var amount = job.FinalAmount
            ?? job.EstimatedTotal
            ?? 0m;

        var options = _paymentOptions.Value;
        var reference = options.BuildReference(job.Id);

        var payment = new Payment
        {
            JobId             = job.Id,
            Amount            = amount,
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
                Amount        = amount,
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
            // v1.7 (P12-16): itemised completion amounts + completion date.
            LabourAmount   = p.Job.LabourAmount,
            AdjustmentsTotal = p.Job.AdjustmentsTotal,
            FinalAmount    = p.Job.FinalAmount,
            EstimatedTotal = p.Job.EstimatedTotal,
            CompletionSubmittedAtUtc = p.Job.CompletionSubmittedAtUtc,
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

        await _notifications.SendPushToUserAsync(homeowner.Id, title, body, new Dictionary<string, string>
        {
            ["jobId"]     = payment.JobId.ToString(),
            ["paymentId"] = payment.Id.ToString(),
        }, ct);

        if (string.IsNullOrEmpty(homeowner.Email)) return;

        try
        {
            if (payment.Status == PaymentStatus.Verified)
                await _email.SendPaymentVerifiedAsync(
                    homeowner.Email, payment.Job.Title, payment.Amount, payment.Currency,
                    tradieName: payment.Job.MatchedTradie?.FullName,
                    reference: payment.Job.ReferenceCode,
                    jobId: payment.JobId);
            else if (payment.Status == PaymentStatus.Rejected)
                await _email.SendPaymentRejectedAsync(
                    homeowner.Email, payment.Job.Title, payment.RejectReason ?? string.Empty,
                    payment.Job.PaymentDueAtUtc ?? DateTime.UtcNow.AddHours(
                        WindowHours(_paymentOptions.Value)),
                    jobId: payment.JobId);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Payment notification email to {Email} failed.", homeowner.Email);
        }
    }
}
