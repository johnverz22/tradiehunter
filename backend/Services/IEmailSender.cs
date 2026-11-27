using FixoApi.Email;

namespace FixoApi.Services;

public interface IEmailSender
{
    Task SendOtpAsync(string toEmail, string otpCode);
    Task SendStaffInviteAsync(string toEmail, string inviteToken);

    /// <summary>Staff confirmed a homeowner's transfer — the job is now booked (P4-05).
    /// tradieName/reference/jobId enrich the template (summary rows, deep link, X-Entity-Ref).</summary>
    Task SendPaymentVerifiedAsync(
        string toEmail, string jobTitle, decimal amount, string currency,
        string? tradieName = null, string? reference = null, int? jobId = null);

    /// <summary>Staff refused a receipt — carries the reason and the new deadline (P4-05).</summary>
    Task SendPaymentRejectedAsync(
        string toEmail, string jobTitle, string reason, DateTime dueAtUtc, int? jobId = null);

    /// <summary>
    /// P8-06: generic critical-event email. Used as the fallback when a user
    /// has push disabled (no device tokens) or a push send fails. Legacy
    /// caller-supplied subject/body — kept for compatibility.
    /// </summary>
    Task SendCriticalAsync(string toEmail, string subject, string body);

    /// <summary>
    /// E5 structured variant (§4.2): NotificationService passes sections and a
    /// CTA instead of pre-flattened strings; the CriticalNotice template
    /// renders them through the shared design-system layout.
    /// </summary>
    Task SendCriticalNoticeAsync(string toEmail, CriticalNoticeModel notice);

    /// <summary>E9: alert one staff member that something needs the admin team.
    /// Renders the StaffAlert template; <paramref name="entityRef"/> becomes X-Entity-Ref.</summary>
    Task SendStaffAlertAsync(string toEmail, StaffAlertModel alert, string? entityRef = null);

    Task SendCredentialDecisionAsync(
        string toEmail,
        string credentialType,
        bool approved,
        string? rejectReason = null,
        int? credentialId = null);

    /// <summary>P8-06: refund processed (money moved — always email if push missed).</summary>
    Task SendRefundProcessedAsync(
        string toEmail, string jobTitle, decimal amount, string currency,
        string reference, int? jobId = null);

    /// <summary>P8-06: account suspended/deactivated by staff.</summary>
    Task SendAccountSuspendedAsync(string toEmail, string name);

    /// <summary>P8-06: job cancelled or expired — homeowner/tradie must know even without push.
    /// Wired for real now: ExpirationWorker and the cancel paths route here (E8, §4.2).</summary>
    Task SendJobCancelledAsync(string toEmail, string jobTitle, string reason);
}
