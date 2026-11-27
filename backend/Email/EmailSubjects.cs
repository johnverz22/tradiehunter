namespace FixoApi.Email;

/// <summary>
/// Subject lines for every transactional email (§4.2 — final copy, single
/// source so tests can assert them). Sentence case, no exclamation marks,
/// brand named where the brand introduces itself (E1/E2/E7); the rest lead
/// with the outcome. CriticalNotice (E5) subjects are caller-supplied.
/// </summary>
public static class EmailSubjects
{
    public static string Otp => "Your TradieHunter verification code";

    public static string StaffInvite => "You've been invited to the TradieHunter admin panel";

    public static string PaymentVerified(string jobTitle) => $"Payment confirmed — {jobTitle}";

    public static string PaymentRejected(string jobTitle) => $"Action needed — receipt for {jobTitle}";

    public static string RefundProcessed => "Your refund is on its way";

    public static string AccountSuspended => "Your TradieHunter account has been suspended";

    public static string StaffAlert(string heading) => $"Staff alert — {heading}";

    public static string CredentialDecision(string credentialType, bool approved) => approved
        ? $"{credentialType} credential approved"
        : $"{credentialType} credential rejected";

    public static string JobCancelled(string jobTitle) => $"Your job \"{jobTitle}\" has been closed";
}
