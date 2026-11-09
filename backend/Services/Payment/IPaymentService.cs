using FixoApi.DTOs;
using FixoApi.Enums;
using System.Threading;
using System.Threading.Tasks;

namespace FixoApi.Services;

/// <summary>
/// Orchestrates the manual payment flow (P4-03): issuing instructions, validating
/// and storing the receipt, driving the job state machine, and running the staff
/// review queue. Every job status change goes through
/// <see cref="IJobStatusService"/> so it lands in history and reaches both
/// clients over SignalR.
/// </summary>
public interface IPaymentService
{
    /// <summary>
    /// Payment instructions and current state for a job, creating the payment on
    /// first call. Throws <see cref="KeyNotFoundException"/> when the caller does
    /// not own the job.
    /// </summary>
    Task<PaymentStatusDto> GetPaymentAsync(int jobId, string homeownerUserId, CancellationToken ct = default);

    /// <summary>
    /// Store a receipt image and move the job to PaymentReview. Throws
    /// <see cref="InvalidOperationException"/> when the job is not awaiting
    /// payment, or when the image has already been used for a different payment.
    /// </summary>
    Task<PaymentStatusDto> UploadReceiptAsync(
        int jobId, string homeownerUserId, ReceiptUpload receipt, CancellationToken ct = default);

    /// <summary>Oldest-first page of receipts waiting on staff review (P4-05).</summary>
    Task<PagedResult<PendingPaymentDto>> GetPendingPaymentsAsync(int page, int pageSize, CancellationToken ct = default);

    /// <summary>Approve a receipt: payment → Verified, job → Booked (P4-05).</summary>
    Task<PaymentActionResult> VerifyPaymentAsync(
        int paymentId, string adminUserId, UserRole actorRole, CancellationToken ct = default);

    /// <summary>Refuse a receipt: payment → Rejected, job → AwaitingPayment (P4-05).</summary>
    Task<PaymentActionResult> RejectPaymentAsync(
        int paymentId, string adminUserId, UserRole actorRole, string reason, CancellationToken ct = default);
}
