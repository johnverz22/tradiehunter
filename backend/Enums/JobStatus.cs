namespace FixoApi.Enums;

public enum JobStatus
{
    Requested,
    AwaitingPayment,
    PaymentReview,
    Booked,
    InProgress,
    AwaitingConfirmation,
    Completed,
    Cancelled,
    Expired,
    Disputed
}
