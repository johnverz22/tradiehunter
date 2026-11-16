using FixoApi.Enums;

namespace FixoApi.Services;

/// <summary>
/// v1.7 (P12-10 / P12-27): the pure job status transition table, split by flow
/// version. Pure function so every edge has a unit test without a database.
///
/// v1 (legacy, P4): Requested → AwaitingPayment (tradie accepts) → PaymentReview
/// (receipt) → Booked (staff verify) → … → AwaitingConfirmation → Completed.
///
/// v2 (pay-at-completion): Requested → Booked (tradie accepts) → InProgress →
/// AwaitingConfirmation → AwaitingPayment (homeowner approves) → PaymentReview
/// (receipt) → Completed (staff verify + payout).
/// </summary>
public static class JobFlowTransitions
{
    public static bool IsValid(JobStatus from, JobStatus to, UserRole actorRole, int flowVersion)
    {
        if (flowVersion >= 2)
            return IsValidV2(from, to, actorRole);
        return IsValidV1(from, to, actorRole);
    }

    // ── v1: the legacy upfront-payment flow (P4) ─────────────────────────────

    private static bool IsValidV1(JobStatus from, JobStatus to, UserRole actorRole)
    {
        var valid = (from, to) switch
        {
            (JobStatus.Requested, JobStatus.AwaitingPayment) => actorRole == UserRole.Tradie,
            // System cancels Requested jobs when matching is exhausted (no_tradie_found).
            (JobStatus.Requested, JobStatus.Cancelled) => actorRole is UserRole.Staff or UserRole.Superadmin,
            (JobStatus.AwaitingPayment, JobStatus.PaymentReview) => actorRole == UserRole.Homeowner,
            (JobStatus.AwaitingPayment, JobStatus.Expired) => actorRole is UserRole.Staff or UserRole.Superadmin,
            (JobStatus.PaymentReview, JobStatus.Booked) => actorRole is UserRole.Staff or UserRole.Superadmin,
            (JobStatus.PaymentReview, JobStatus.AwaitingPayment) => actorRole is UserRole.Staff or UserRole.Superadmin,
            // A receipt can sit un-reviewed past the payment window, so PaymentReview
            // expires on the same terms as AwaitingPayment (P4-06).
            (JobStatus.PaymentReview, JobStatus.Expired) => actorRole is UserRole.Staff or UserRole.Superadmin,
            (JobStatus.Booked, JobStatus.InProgress) => actorRole == UserRole.Tradie,
            (JobStatus.Booked, JobStatus.Requested) => actorRole is UserRole.Staff or UserRole.Superadmin,
            (JobStatus.Booked, JobStatus.Cancelled) => true,
            (JobStatus.InProgress, JobStatus.AwaitingConfirmation) => actorRole == UserRole.Tradie,
            (JobStatus.InProgress, JobStatus.Cancelled) => true,
            (JobStatus.AwaitingConfirmation, JobStatus.Completed) => actorRole is UserRole.Homeowner or UserRole.Staff or UserRole.Superadmin,
            (JobStatus.AwaitingConfirmation, JobStatus.Disputed) => actorRole == UserRole.Homeowner,
            (_, JobStatus.Disputed) => true,
            (JobStatus.Disputed, JobStatus.Completed) => actorRole is UserRole.Staff or UserRole.Superadmin,
            (JobStatus.Disputed, JobStatus.Cancelled) => actorRole is UserRole.Staff or UserRole.Superadmin,
            _ => false
        };
        return valid;
    }

    // ── v2: the pay-at-completion flow (P12-10) ──────────────────────────────

    private static bool IsValidV2(JobStatus from, JobStatus to, UserRole actorRole)
    {
        var valid = (from, to) switch
        {
            // P12-10: the tradie's accept now books the job directly — payment
            // moves to the end. Requested → AwaitingPayment is REMOVED.
            (JobStatus.Requested, JobStatus.Booked) => actorRole == UserRole.Tradie,
            // System cancels Requested jobs when matching is exhausted (no_tradie_found).
            (JobStatus.Requested, JobStatus.Cancelled) => actorRole is UserRole.Staff or UserRole.Superadmin,
            (JobStatus.Booked, JobStatus.InProgress) => actorRole == UserRole.Tradie,
            (JobStatus.Booked, JobStatus.Requested) => actorRole is UserRole.Staff or UserRole.Superadmin,
            (JobStatus.Booked, JobStatus.Cancelled) => true,
            (JobStatus.InProgress, JobStatus.AwaitingConfirmation) => actorRole == UserRole.Tradie,
            (JobStatus.InProgress, JobStatus.Cancelled) => true,
            // P12-11: the homeowner approves the final amount, THEN pays.
            (JobStatus.AwaitingConfirmation, JobStatus.AwaitingPayment) => actorRole is UserRole.Homeowner or UserRole.Staff or UserRole.Superadmin,
            (JobStatus.AwaitingConfirmation, JobStatus.Disputed) => actorRole == UserRole.Homeowner,
            (_, JobStatus.Disputed) => true,
            // Dispute resolved → back to the approval step (nothing was paid yet).
            (JobStatus.Disputed, JobStatus.AwaitingConfirmation) => actorRole is UserRole.Staff or UserRole.Superadmin,
            // Dispute resolved in the homeowner's leave-the-job-finished favour:
            // staff can push an agreed job into payment directly.
            (JobStatus.Disputed, JobStatus.AwaitingPayment) => actorRole is UserRole.Staff or UserRole.Superadmin,
            (JobStatus.Disputed, JobStatus.Cancelled) => actorRole is UserRole.Staff or UserRole.Superadmin,
            // Receipt uploaded → staff queue.
            (JobStatus.AwaitingPayment, JobStatus.PaymentReview) => actorRole == UserRole.Homeowner,
            // P12-13: staff verify → Completed (payout created on this edge).
            (JobStatus.PaymentReview, JobStatus.Completed) => actorRole is UserRole.Staff or UserRole.Superadmin,
            // P12-10: staff reject → back to the payment window.
            (JobStatus.PaymentReview, JobStatus.AwaitingPayment) => actorRole is UserRole.Staff or UserRole.Superadmin,
            _ => false
        };
        return valid;
    }
}
