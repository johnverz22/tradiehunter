namespace FixoApi.Services;

/// <summary>Who an event is for. Flags so one event can reach several audiences.</summary>
[Flags]
public enum NotificationAudience
{
    None = 0,
    Homeowner = 1,
    Tradie = 2,
    Staff = 4,
}

/// <summary>
/// How an event uses email. <see cref="Fallback"/> sends mail only when push
/// is unavailable or failed; <see cref="Always"/> is the "critical" tier (money
/// moved, account or job outcome changed, a decision the user must see).
/// </summary>
public enum EmailPolicy
{
    None = 0,
    Fallback = 1,
    Always = 2,
}

/// <summary>
/// One row of the notification matrix: which audiences get the event, whether
/// it is pushed, and how email is used. <see cref="Key"/> is also sent as the
/// push <c>type</c> data field so clients can route taps.
/// </summary>
public sealed record NotificationDefinition(
    string Key,
    NotificationAudience Audiences,
    bool Push,
    EmailPolicy Email,
    string Summary)
{
    /// <summary>Critical events always email, even when the push succeeded.</summary>
    public bool IsCritical => Email == EmailPolicy.Always;

    /// <summary>Staff-facing events are alerts raised for the admin team.</summary>
    public bool IsStaffAlert => Audiences.HasFlag(NotificationAudience.Staff);
}

/// <summary>
/// Stable event keys (snake_case). Keys that already exist as push <c>type</c>
/// values keep their name so mobile routing does not change.
/// </summary>
public static class NotificationEvents
{
    // Existing critical kinds (see CriticalNotificationTypes).
    public const string RefundProcessed = CriticalNotificationTypes.RefundProcessed;
    public const string AccountSuspended = CriticalNotificationTypes.AccountSuspended;
    public const string JobCancelled = CriticalNotificationTypes.JobCancelled;
    public const string JobExpired = CriticalNotificationTypes.JobExpired;

    // Disputes (N2).
    public const string DisputeOpened = "dispute_opened";
    public const string DisputeEvidenceAdded = "dispute_evidence_added";
    public const string DisputeResolved = "dispute_resolved";
    public const string DisputeStaffAlert = "dispute_staff_alert";

    // Credentials and verification (N4).
    public const string CredentialSubmitted = "credential_submitted";
    public const string CredentialStaffAlert = "credential_staff_alert";
    public const string CredentialDecision = "credential_decision";
    public const string UserVerified = "user_verified";

    // Job status transitions for the counterparty (N3).
    public const string JobBooked = "job_booked";
    public const string JobInProgress = "job_in_progress";
    public const string JobAwaitingConfirmation = "job_awaiting_confirmation";
    public const string JobAwaitingPayment = "job_awaiting_payment";
    public const string JobPaymentReview = "job_payment_review";

    // Offers, quotes, adjustments (N3).
    public const string OfferAccepted = "offer_accepted";
    public const string OfferDeclined = "offer_declined";
    public const string OfferExpired = "offer_expired";
    public const string QuoteAccepted = "quote_accepted";
    public const string QuoteDeclined = "quote_declined";
    public const string AdjustmentWithdrawn = "adjustment_withdrawn";
    public const string AdjustmentExpired = "adjustment_expired";
    public const string AdjustmentReminder = "adjustment_reminder";

    // Payments and payouts (N3, N5).
    public const string ReceiptReceived = "receipt_received";
    public const string PayoutProcessed = "payout_processed";

    // Reminders, reports, reviews (N3).
    public const string PreJobReminder = "pre_job_reminder";
    public const string NoShowReported = "no_show_reported";
    public const string ReviewReceived = "review_received";
    public const string ReviewRevealed = "review_revealed";

    // Staff alerts (N5).
    public const string ReceiptAwaitingVerification = "receipt_awaiting_verification";
    public const string PaymentSlaBreach = "payment_sla_breach";
    public const string PaymentOverdueStaff = "payment_overdue_staff";
    public const string JobNeedsReview = "job_needs_review";
    public const string PayoutBatchReady = "payout_batch_ready";
    public const string PayoutBatchCompleted = "payout_batch_completed";
    public const string AccountFlagThreshold = "account_flag_threshold";
}

/// <summary>
/// The single reviewable place where channel decisions live (plan 09 §3.3).
/// Call sites name an event; this table decides audience, push and email.
/// Decisions recorded in docs/todos/09_notification_coverage_plan.md (N0.5):
/// <list type="bullet">
/// <item>Critical (always email): money moved, account/job closed, dispute
/// opened or resolved, credential decision.</item>
/// <item>Fallback (email only if push missed): status changes and offer
/// outcomes the counterparty would otherwise miss.</item>
/// <item>Push only: time-sensitive reminders and low-stakes review events
/// (an email after the moment has passed adds nothing).</item>
/// <item>Staff alerts: email always, no push (staff work in the web admin);
/// N6 adds the in-app bell, email stays for SLA breaches and flags.</item>
/// </list>
/// </summary>
public static class NotificationPolicy
{
    private const NotificationAudience Home = NotificationAudience.Homeowner;
    private const NotificationAudience Trade = NotificationAudience.Tradie;
    private const NotificationAudience Both = NotificationAudience.Homeowner | NotificationAudience.Tradie;
    private const NotificationAudience Staff = NotificationAudience.Staff;

    private static NotificationDefinition Def(
        string key, NotificationAudience audiences, bool push, EmailPolicy email, string summary) =>
        new(key, audiences, push, email, summary);

    public static IReadOnlyList<NotificationDefinition> All { get; } = new[]
    {
        // ── Critical: always email ────────────────────────────────────────────
        Def(NotificationEvents.RefundProcessed, Home, true, EmailPolicy.Always, "Refund transferred to the homeowner."),
        Def(NotificationEvents.AccountSuspended, Both, false, EmailPolicy.Always, "Account suspended by staff (locked, so email only)."),
        Def(NotificationEvents.JobCancelled, Both, true, EmailPolicy.Always, "Job cancelled; the counterparty must know."),
        Def(NotificationEvents.JobExpired, Home, true, EmailPolicy.Always, "Job expired with no booking."),
        Def(NotificationEvents.DisputeOpened, Both, true, EmailPolicy.Always, "A dispute was opened on the job; affects payment."),
        Def(NotificationEvents.DisputeResolved, Both, true, EmailPolicy.Always, "Staff resolved the dispute (completed or cancelled)."),
        Def(NotificationEvents.CredentialDecision, Trade, true, EmailPolicy.Always, "Credential approved or rejected, with the reason."),
        Def(NotificationEvents.PayoutProcessed, Trade, true, EmailPolicy.Always, "Payout transferred to the tradie."),

        // ── Fallback: email only when push did not land ───────────────────────
        Def(NotificationEvents.DisputeEvidenceAdded, Both, true, EmailPolicy.Fallback, "The other party added dispute evidence."),
        Def(NotificationEvents.CredentialSubmitted, Trade, true, EmailPolicy.Fallback, "Confirmation that a credential upload was received."),
        Def(NotificationEvents.UserVerified, Trade, true, EmailPolicy.Fallback, "Staff verified the tradie."),
        Def(NotificationEvents.JobBooked, Both, true, EmailPolicy.Fallback, "Job booked."),
        Def(NotificationEvents.JobInProgress, Home, true, EmailPolicy.Fallback, "Tradie checked in; work started."),
        Def(NotificationEvents.JobAwaitingConfirmation, Home, true, EmailPolicy.Fallback, "Tradie finished; homeowner must confirm."),
        Def(NotificationEvents.JobAwaitingPayment, Home, true, EmailPolicy.Fallback, "Payment is due."),
        Def(NotificationEvents.JobPaymentReview, Trade, true, EmailPolicy.Fallback, "Homeowner uploaded a receipt; staff are verifying."),
        Def(NotificationEvents.OfferAccepted, Home, true, EmailPolicy.Fallback, "Tradie accepted the request."),
        Def(NotificationEvents.OfferDeclined, Home, true, EmailPolicy.Fallback, "Tradie declined the request."),
        Def(NotificationEvents.OfferExpired, Both, true, EmailPolicy.Fallback, "Offer window passed without a response."),
        Def(NotificationEvents.QuoteAccepted, Trade, true, EmailPolicy.Fallback, "Homeowner accepted the quote."),
        Def(NotificationEvents.QuoteDeclined, Trade, true, EmailPolicy.Fallback, "Quote not chosen."),
        Def(NotificationEvents.AdjustmentWithdrawn, Home, true, EmailPolicy.Fallback, "Tradie withdrew the pending extra-cost request."),
        Def(NotificationEvents.AdjustmentExpired, Both, true, EmailPolicy.Fallback, "Extra-cost request expired unanswered."),
        Def(NotificationEvents.ReceiptReceived, Home, true, EmailPolicy.Fallback, "We received the payment receipt."),
        Def(NotificationEvents.NoShowReported, Both, true, EmailPolicy.Fallback, "A no-show was reported on the job."),

        // ── Push only ─────────────────────────────────────────────────────────
        Def(NotificationEvents.AdjustmentReminder, Home, true, EmailPolicy.None, "Reminder: extra cost awaiting approval."),
        Def(NotificationEvents.PreJobReminder, Both, true, EmailPolicy.None, "Job starts in one hour."),
        Def(NotificationEvents.ReviewReceived, Both, true, EmailPolicy.None, "A review was submitted for you."),
        Def(NotificationEvents.ReviewRevealed, Both, true, EmailPolicy.None, "A review is now visible."),

        // ── Staff alerts: email always, no push ───────────────────────────────
        Def(NotificationEvents.DisputeStaffAlert, Staff, false, EmailPolicy.Always, "A dispute or flag needs staff attention."),
        Def(NotificationEvents.CredentialStaffAlert, Staff, false, EmailPolicy.Always, "A tradie credential is waiting for review."),
        Def(NotificationEvents.ReceiptAwaitingVerification, Staff, false, EmailPolicy.Always, "A payment receipt is waiting for verification."),
        Def(NotificationEvents.PaymentSlaBreach, Staff, false, EmailPolicy.Always, "A receipt has waited past the verification SLA."),
        Def(NotificationEvents.PaymentOverdueStaff, Staff, false, EmailPolicy.Always, "A homeowner payment is overdue."),
        Def(NotificationEvents.JobNeedsReview, Staff, false, EmailPolicy.Always, "Auto-complete escalated a job for staff review."),
        Def(NotificationEvents.PayoutBatchReady, Staff, false, EmailPolicy.Always, "A payout batch is ready to process."),
        Def(NotificationEvents.PayoutBatchCompleted, Staff, false, EmailPolicy.Always, "A payout batch was completed."),
        Def(NotificationEvents.AccountFlagThreshold, Staff, false, EmailPolicy.Always, "An account flag reached its threshold."),
    };

    private static readonly IReadOnlyDictionary<string, NotificationDefinition> ByKey =
        All.ToDictionary(d => d.Key, StringComparer.Ordinal);

    /// <summary>Look up an event; throws for an unknown key so typos fail in tests, not in prod silence.</summary>
    public static NotificationDefinition Get(string key) =>
        ByKey.TryGetValue(key, out var def)
            ? def
            : throw new KeyNotFoundException($"Unknown notification event '{key}'.");

    public static bool TryGet(string key, out NotificationDefinition definition) =>
        ByKey.TryGetValue(key, out definition!);
}
