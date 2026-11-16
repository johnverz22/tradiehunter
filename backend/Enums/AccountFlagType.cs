namespace FixoApi.Enums;

public enum AccountFlagType
{
    RepeatCanceller,
    RepeatNoShow,
    Abuse,
    Manual,
    LowRating,
    /// <summary>v1.7 (P12-12): homeowner let a verified payment window lapse twice
    /// or ignored overdue reminders — blocks posting/requesting new jobs until
    /// staff clear it after the payment is verified.</summary>
    OverduePayment
}