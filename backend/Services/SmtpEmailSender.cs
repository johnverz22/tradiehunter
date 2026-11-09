using System.Net.Mail;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace FixoApi.Services;

public class SmtpEmailSender : IEmailSender
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<SmtpEmailSender> _logger;

    public SmtpEmailSender(IConfiguration configuration, ILogger<SmtpEmailSender> logger)
    {
        _configuration = configuration;
        _logger = logger;
    }

    public async Task SendOtpAsync(string toEmail, string otpCode)
    {
        var host = _configuration["EmailSender:Host"] ?? "localhost";
        var portString = _configuration["EmailSender:Port"];
        int port = int.TryParse(portString, out var p) ? p : 1025;
        var fromEmail = _configuration["EmailSender:FromEmail"] ?? "noreply@tradiehunter.nz";

        using var client = new SmtpClient(host, port);
        var mailMessage = new MailMessage
        {
            From = new MailAddress(fromEmail),
            Subject = "Your TradieHunter Registration OTP",
            Body = $"Your 6-digit OTP code is: {otpCode}\n\nIt expires in 10 minutes.",
            IsBodyHtml = false
        };
        mailMessage.To.Add(toEmail);

        _logger.LogInformation("Sending OTP to {Email}", toEmail);
        try
        {
            await client.SendMailAsync(mailMessage);
        }
        catch (System.Exception ex)
        {
            _logger.LogError(ex, "Failed to send OTP to {Email}", toEmail);
            throw;
        }
    }

    public async Task SendStaffInviteAsync(string toEmail, string inviteToken)
    {
        var host = _configuration["EmailSender:Host"] ?? "localhost";
        var portString = _configuration["EmailSender:Port"];
        int port = int.TryParse(portString, out var p) ? p : 1025;
        var fromEmail = _configuration["EmailSender:FromEmail"] ?? "noreply@tradiehunter.nz";

        using var client = new SmtpClient(host, port);
        var mailMessage = new MailMessage
        {
            From = new MailAddress(fromEmail),
            Subject = "You've been invited to TradieHunter Admin",
            Body = $"You've been invited to join the TradieHunter Admin panel.\n\nPlease use the following token to set your password and activate your account:\n{inviteToken}",
            IsBodyHtml = false
        };
        mailMessage.To.Add(toEmail);

        _logger.LogInformation("Sending Staff Invite to {Email}", toEmail);
        try
        {
            await client.SendMailAsync(mailMessage);
        }
        catch (System.Exception ex)
        {
            _logger.LogError(ex, "Failed to send Staff Invite to {Email}", toEmail);
            throw;
        }
    }

    public async Task SendPaymentVerifiedAsync(string toEmail, string jobTitle, decimal amount, string currency)
    {
        await SendAsync(toEmail, "Your TradieHunter payment is confirmed",
            $"We verified your transfer for \"{jobTitle}\".\n\n" +
            $"Amount: {amount:0.00} {currency}\n\n" +
            $"Your tradie has been booked and will be in touch to confirm the visit.");
    }

    public async Task SendPaymentRejectedAsync(string toEmail, string jobTitle, string reason, DateTime dueAtUtc)
    {
        var deadline = dueAtUtc.ToLocalTime().ToString("d MMM yyyy 'at' HH:mm");
        await SendAsync(toEmail, "We need a different payment receipt",
            $"We couldn't accept the receipt you uploaded for \"{jobTitle}\".\n\n" +
            $"Reason: {reason}\n\n" +
            $"Please upload a corrected receipt by {deadline} so we can book your tradie.");
    }

    public Task SendCriticalAsync(string toEmail, string subject, string body) =>
        SendAsync(toEmail, subject, body);

    public Task SendRefundProcessedAsync(string toEmail, string jobTitle, decimal amount, string currency, string reference) =>
        SendAsync(toEmail, "Your TradieHunter refund has been processed",
            $"Your refund for \"{jobTitle}\" has been processed.\n\n" +
            $"Amount: {amount:0.00} {currency}\n" +
            $"Reference: {reference}\n\n" +
            $"The money is on its way — allow 1–2 business days for it to land.");

    public Task SendAccountSuspendedAsync(string toEmail, string name) =>
        SendAsync(toEmail, "Your TradieHunter account has been suspended",
            $"Hi {name},\n\n" +
            $"Your TradieHunter account has been suspended by our team. " +
            $"If you think this is a mistake, reply to this email and we'll review it.");

    public Task SendJobCancelledAsync(string toEmail, string jobTitle, string reason) =>
        SendAsync(toEmail, "Update on your TradieHunter job",
            $"Your job \"{jobTitle}\" was closed.\n\n" +
            $"Reason: {reason}\n\n" +
            $"You can post a new job any time from the app.");

    /// <summary>Shared SMTP send for the notification emails. Mail is best-effort —
    /// callers must not fail a payment transition because the mail server is down.</summary>
    private async Task SendAsync(string toEmail, string subject, string body)
    {
        var host = _configuration["EmailSender:Host"] ?? "localhost";
        var portString = _configuration["EmailSender:Port"];
        int port = int.TryParse(portString, out var p) ? p : 1025;
        var fromEmail = _configuration["EmailSender:FromEmail"] ?? "noreply@tradiehunter.nz";

        using var client = new SmtpClient(host, port);
        var mailMessage = new MailMessage
        {
            From = new MailAddress(fromEmail),
            Subject = subject,
            Body = body,
            IsBodyHtml = false
        };
        mailMessage.To.Add(toEmail);

        _logger.LogInformation("Sending '{Subject}' to {Email}", subject, toEmail);
        await client.SendMailAsync(mailMessage);
    }
}
