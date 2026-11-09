using System.Threading.Tasks;

namespace FixoApi.Services;

public interface IEmailSender
{
    Task SendOtpAsync(string toEmail, string otpCode);
    Task SendStaffInviteAsync(string toEmail, string inviteToken);

    /// <summary>Staff confirmed a homeowner's transfer — the job is now booked (P4-05).</summary>
    Task SendPaymentVerifiedAsync(string toEmail, string jobTitle, decimal amount, string currency);

    /// <summary>Staff refused a receipt — carries the reason and the new deadline (P4-05).</summary>
    Task SendPaymentRejectedAsync(string toEmail, string jobTitle, string reason, DateTime dueAtUtc);

    /// <summary>
    /// P8-06: generic critical-event email. Used as the fallback when a user
    /// has push disabled (no device tokens) or a push send fails.
    /// </summary>
    Task SendCriticalAsync(string toEmail, string subject, string body);

    /// <summary>P8-06: refund processed (money moved — always email if push missed).</summary>
    Task SendRefundProcessedAsync(string toEmail, string jobTitle, decimal amount, string currency, string reference);

    /// <summary>P8-06: account suspended/deactivated by staff.</summary>
    Task SendAccountSuspendedAsync(string toEmail, string name);

    /// <summary>P8-06: job cancelled or expired — homeowner/tradie must know even without push.</summary>
    Task SendJobCancelledAsync(string toEmail, string jobTitle, string reason);
}
