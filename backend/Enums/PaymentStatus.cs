namespace FixoApi.Enums;

/// <summary>
/// Lifecycle of a manual (bank-transfer) payment against a job — stored as a
/// string in the database. Mirrors the AwaitingPayment → PaymentReview → Booked
/// edges of <see cref="JobStatus"/>: the payment reaches <see cref="Submitted"/>
/// when the homeowner uploads a receipt, which parks the job in PaymentReview
/// until staff resolve the queue.
/// </summary>
public enum PaymentStatus
{
    /// <summary>Instructions issued to the homeowner; no receipt uploaded yet.</summary>
    Pending,

    /// <summary>Receipt uploaded, awaiting staff review in the admin queue.</summary>
    Submitted,

    /// <summary>Receipt confirmed by staff — the job is released to <c>Booked</c>.</summary>
    Verified,

    /// <summary>Receipt refused by staff. The job returns to AwaitingPayment for a re-upload.</summary>
    Rejected,

    /// <summary>The payment window elapsed without verification; the job expired.</summary>
    Expired
}
