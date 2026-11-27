
using FixoApi.Data;
using FixoApi.Email;
using FixoApi.Models;
using FixoApi.Options;
using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using MimeKit;

namespace FixoApi.Services;

/// <summary>
/// Production email sender (EMAIL-TEMPLATE-REVISION-PLAN §4/§5):
/// Razor templates + MailKit SMTP, multipart/alternative (HTML + plain-text
/// twin), per-class From identities (security@/billing@/hello@), sandbox mode,
/// send observability and hard-bounce marking. The IEmailSender interface is
/// unchanged apart from additive optional parameters — call sites churn
/// nothing unless they pass the new data (§4, "keeping the interface identical").
/// </summary>
public class SmtpEmailSender : IEmailSender
{
    private readonly EmailSenderOptions _options;
    private readonly BrandOptions _brand;
    private readonly EmailTemplateRenderer _templates;
    private readonly FixoDbContext _db;
    private readonly IEmailMetrics _metrics;
    private readonly ILogger<SmtpEmailSender> _logger;

    public SmtpEmailSender(
        IOptions<EmailSenderOptions> options,
        IOptions<BrandOptions> brandOptions,
        EmailTemplateRenderer templates,
        FixoDbContext db,
        IEmailMetrics metrics,
        ILogger<SmtpEmailSender> logger)
    {
        _options = options.Value;
        _brand = brandOptions.Value;
        _templates = templates;
        _db = db;
        _metrics = metrics;
        _logger = logger;
    }

    // ── Template senders (E1–E8) ─────────────────────────────────────────────

    public async Task SendOtpAsync(string toEmail, string otpCode)
    {
        if (!_options.UseTemplates)
        {
            await SendLegacyAsync(toEmail, "Your TradieHunter Registration OTP",
                $"Your 6-digit OTP code is: {otpCode}\n\nIt expires in 10 minutes.",
                SecurityIdentity());
            return;
        }

        var rendered = await RenderAsync("Otp", "Otp", new OtpModel
        {
            Otp = otpCode,
            Brand = _brand,
        });
        await SendAsync(toEmail, EmailSubjects.Otp, rendered,
            SecurityIdentity(), template: "Otp");
    }

    public async Task SendStaffInviteAsync(string toEmail, string inviteToken)
    {
        if (!_options.UseTemplates)
        {
            await SendLegacyAsync(toEmail, "You've been invited to TradieHunter Admin",
                "You've been invited to join the TradieHunter Admin panel.\n\n" +
                $"Please use the following token to set your password and activate your account:\n{inviteToken}",
                SecurityIdentity());
            return;
        }

        var rendered = await RenderAsync("StaffInvite", "StaffInvite", new StaffInviteModel
        {
            Token = inviteToken,
            ActivationUrl = WithBaseUrl($"/staff/activate?token={Uri.EscapeDataString(inviteToken)}"),
            ExpiresInHours = 24,
            Brand = _brand,
        });
        await SendAsync(toEmail, EmailSubjects.StaffInvite, rendered,
            SecurityIdentity(), template: "StaffInvite");
    }

    public async Task SendPaymentVerifiedAsync(
        string toEmail, string jobTitle, decimal amount, string currency,
        string? tradieName = null, string? reference = null, int? jobId = null)
    {
        var amountDisplay = Money.Format(amount, currency);
        if (!_options.UseTemplates)
        {
            await SendLegacyAsync(toEmail, "Your TradieHunter payment is confirmed",
                $"We verified your transfer for \"{jobTitle}\".\n\n" +
                $"Amount: {amountDisplay}\n\n" +
                "Your tradie has been booked and will be in touch to confirm the visit.",
                BillingIdentity(), entityRef: EntityRef(jobId));
            return;
        }

        var rendered = await RenderAsync("PaymentVerified", "PaymentVerified", new PaymentVerifiedModel
        {
            JobTitle = jobTitle,
            AmountDisplay = amountDisplay,
            TradieName = tradieName,
            Reference = reference,
            JobUrl = WithBaseUrl($"/jobs/{jobId}"),
            Brand = _brand,
        });
        await SendAsync(toEmail, EmailSubjects.PaymentVerified(jobTitle), rendered,
            BillingIdentity(), template: "PaymentVerified", entityRef: EntityRef(jobId));
    }

    public async Task SendPaymentRejectedAsync(
        string toEmail, string jobTitle, string reason, DateTime dueAtUtc, int? jobId = null)
    {
        // §4.2 E4: NZT via the NzTime helper — ToLocalTime() rendered the
        // *server* timezone, a latent bug for NZ users when hosted offshore.
        var deadline = NzTime.Format(dueAtUtc);
        if (!_options.UseTemplates)
        {
            await SendLegacyAsync(toEmail, "We need a different payment receipt",
                $"We couldn't accept the receipt you uploaded for \"{jobTitle}\".\n\n" +
                $"Reason: {reason}\n\n" +
                $"Please upload a corrected receipt by {deadline} so we can book your tradie.",
                BillingIdentity(), entityRef: EntityRef(jobId));
            return;
        }

        var rendered = await RenderAsync("PaymentRejected", "PaymentRejected", new PaymentRejectedModel
        {
            JobTitle = jobTitle,
            Reason = reason,
            DeadlineDisplay = deadline,
            PaymentUrl = WithBaseUrl($"/jobs/{jobId}/payment"),
            Brand = _brand,
        });
        await SendAsync(toEmail, EmailSubjects.PaymentRejected(jobTitle), rendered,
            BillingIdentity(), template: "PaymentRejected", entityRef: EntityRef(jobId));
    }

    /// <summary>E5 legacy path — caller-supplied subject/body, no branding (kept for compatibility).</summary>
    public Task SendCriticalAsync(string toEmail, string subject, string body) =>
        SendLegacyAsync(toEmail, subject, body, HelloIdentity());

    /// <summary>E5 structured path — NotificationService passes sections, not flattened strings.</summary>
    public async Task SendCriticalNoticeAsync(string toEmail, CriticalNoticeModel notice)
    {
        var rendered = await RenderAsync("CriticalNotice", "CriticalNotice", notice);
        await SendAsync(toEmail, notice.Heading, rendered,
            HelloIdentity(), template: "CriticalNotice");
    }

    /// <summary>E9 staff alert — one design-system template for every staff event.</summary>
    public async Task SendStaffAlertAsync(string toEmail, StaffAlertModel alert, string? entityRef = null)
    {
        var subject = EmailSubjects.StaffAlert(alert.Heading);
        if (!_options.UseTemplates)
        {
            await SendLegacyAsync(toEmail, subject, alert.Body, HelloIdentity(), entityRef: entityRef);
            return;
        }

        var rendered = await RenderAsync("StaffAlert", "StaffAlert", alert);
        await SendAsync(toEmail, subject, rendered,
            HelloIdentity(), template: "StaffAlert", entityRef: entityRef);
    }

    public async Task SendRefundProcessedAsync(
        string toEmail, string jobTitle, decimal amount, string currency, string reference, int? jobId = null)
    {
        var amountDisplay = Money.Format(amount, currency);
        if (!_options.UseTemplates)
        {
            await SendLegacyAsync(toEmail, "Your TradieHunter refund has been processed",
                $"Your refund for \"{jobTitle}\" has been processed.\n\n" +
                $"Amount: {amountDisplay}\n" +
                $"Reference: {reference}\n\n" +
                "The money is on its way — allow 1–2 business days for it to land.",
                BillingIdentity(), entityRef: EntityRef(jobId));
            return;
        }

        var rendered = await RenderAsync("RefundProcessed", "RefundProcessed", new RefundProcessedModel
        {
            JobTitle = jobTitle,
            AmountDisplay = amountDisplay,
            Reference = reference,
            PaymentUrl = WithBaseUrl($"/jobs/{jobId}/payment"),
            Brand = _brand,
        });
        await SendAsync(toEmail, EmailSubjects.RefundProcessed, rendered,
            BillingIdentity(), template: "RefundProcessed", entityRef: EntityRef(jobId));
    }

    public async Task SendAccountSuspendedAsync(string toEmail, string name)
    {
        if (!_options.UseTemplates)
        {
            await SendLegacyAsync(toEmail, "Your TradieHunter account has been suspended",
                $"Hi {name},\n\n" +
                "Your TradieHunter account has been suspended by our team. " +
                "If you think this is a mistake, reply to this email and we'll review it.",
                HelloIdentity());
            return;
        }

        var rendered = await RenderAsync("AccountSuspended", "AccountSuspended", new AccountSuspendedModel
        {
            Name = name,
            Brand = _brand,
        });
        await SendAsync(toEmail, EmailSubjects.AccountSuspended, rendered,
            HelloIdentity(), template: "AccountSuspended");
    }

    /// <summary>E8 — job closed/expired. Dead code no more: the expiry worker and
    /// the cancel paths route here (see ExpirationWorker, JobStatusService).</summary>
    public async Task SendJobCancelledAsync(string toEmail, string jobTitle, string reason)
    {
        if (!_options.UseTemplates)
        {
            await SendLegacyAsync(toEmail, "Update on your TradieHunter job",
                $"Your job \"{jobTitle}\" was closed.\n\n" +
                $"Reason: {reason}\n\n" +
                "You can post a new job any time from the app.",
                HelloIdentity());
            return;
        }

        var rendered = await RenderAsync("JobCancelled", "JobCancelled", new JobClosedModel
        {
            JobTitle = jobTitle,
            Reason = reason,
            PostAgainUrl = WithBaseUrl("/jobs/new"),
            Brand = _brand,
        });
        await SendAsync(toEmail, EmailSubjects.JobCancelled(jobTitle), rendered,
            HelloIdentity(), template: "JobCancelled");
    }

    // ── Template plumbing ─────────────────────────────────────────────────────

    private async Task<RenderedEmail> RenderAsync(string templateName, string metricTag, IEmailTextModel model)
    {
        var sw = System.Diagnostics.Stopwatch.StartNew();
        try
        {
            return await _templates.RenderAsync(templateName, model);
        }
        finally
        {
            sw.Stop();
            _metrics.RecordRender(metricTag, sw.ElapsedMilliseconds);
        }
    }

    private string? WithBaseUrl(string? path)
    {
        if (string.IsNullOrWhiteSpace(_brand.FrontendBaseUrl) || string.IsNullOrWhiteSpace(path)) return null;
        return _brand.FrontendBaseUrl.TrimEnd('/') + path;
    }

    private static string? EntityRef(int? jobId) => jobId.HasValue ? $"job:{jobId.Value}" : null;

    // ── MIME construction + SMTP (MailKit) ────────────────────────────────────

    /// <summary>
    /// Build and send one message: text part first, then HTML (multipart/
    /// alternative order matters for spam heuristics, §4). Mail is best-effort
    /// at the call-site level; here a transport failure is logged, counted and
    /// rethrown so callers' existing catch-and-continue keeps working.
    /// </summary>
    private async Task SendAsync(
        string toEmail, string subject, RenderedEmail rendered,
        SenderIdentity from, string template, string? entityRef = null)
    {
        // §5.4 list hygiene: hard-bounced addresses stop receiving mail.
        if (await IsBouncedAsync(toEmail))
        {
            _logger.LogInformation("Email {Template} to {To} skipped — address marked bounced", template, toEmail);
            return;
        }

        var finalSubject = _options.SandboxMode ? $"[SANDBOX] {subject}" : subject;
        var sw = System.Diagnostics.Stopwatch.StartNew();
        try
        {
            var message = BuildMessage(toEmail, finalSubject, rendered, from, entityRef);

            using var client = new SmtpClient();
            await client.ConnectAsync(_options.Host, _options.Port, ResolveTlsMode());

            if (!string.IsNullOrWhiteSpace(_options.Username))
            {
                await client.AuthenticateAsync(_options.Username, _options.Password ?? string.Empty);
            }

            // §5.3: bounces → bounces@ envelope (Return-Path is set by the relay).
            var envelopeFrom = string.IsNullOrWhiteSpace(_options.BounceAddress)
                ? (MailboxAddress)message.From[0]
                : MailboxAddress.Parse(_options.GetBounceAddress());

            // MailKit 5 API: the envelope is explicit in the send request.
            var request = new SmtpSendRequest(message, envelopeFrom, [message.To.Mailboxes.First()]);
            var result = await client.SendAsync(request);
            await client.DisconnectAsync(quit: true);

            sw.Stop();
            if (result.RejectedRecipients.Count > 0)
            {
                // Recipient-level failure — MailKit raises per-recipient errors
                // through RejectedRecipients rather than an exception here.
                _metrics.IncrementFailed(template);
                _logger.LogWarning(
                    "Email {Template} to {To}: recipient rejected by relay ({Rejected})",
                    template, toEmail, string.Join(", ", result.RejectedRecipients.Select(r => r.ToString())));
                await MarkBouncedAsync(toEmail);
                throw new InvalidOperationException(
                    $"SMTP relay rejected recipient for {template} to {toEmail}");
            }

            _metrics.IncrementSent(template);
            _logger.LogInformation(
                "Email sent {Template} to {To} entityRef {EntityRef} response {Response} elapsedMs {ElapsedMs}",
                template, toEmail, entityRef ?? "-", result.ResponseText, sw.ElapsedMilliseconds);
        }
        catch (Exception ex) when (IsHardBounce(ex))
        {
            _metrics.IncrementFailed(template);
            _logger.LogWarning(ex,
                "Email hard-bounced {Template} to {To} — address marked bounced (§5.4 list hygiene)",
                template, toEmail);
            await MarkBouncedAsync(toEmail);
            throw;
        }
        catch (Exception ex)
        {
            _metrics.IncrementFailed(template);
            _logger.LogError(ex, "Email send failed {Template} to {To}", template, toEmail);
            throw;
        }
    }

    private MimeMessage BuildMessage(
        string toEmail, string subject, RenderedEmail rendered,
        SenderIdentity from, string? entityRef)
    {
        var message = new MimeMessage();

        message.From.Add(new MailboxAddress(from.DisplayName, from.Email));
        message.To.Add(MailboxAddress.Parse(toEmail));

        // §4: UTF-8 subject — MimeKit applies RFC 2047 encoding automatically
        // when the subject carries non-ASCII characters.
        message.Subject = subject;

        // OTP has NO Reply-To (unmonitored replies there would leak codes into a
        // shared inbox — §4); human-facing templates route replies to support.
        if (from.ReplyTo != null)
        {
            message.ReplyTo.Add(new MailboxAddress(_brand.AppName, from.ReplyTo));
        }

        // Inbound threading can match on the related entity (§4).
        if (!string.IsNullOrWhiteSpace(entityRef))
        {
            message.Headers.Add("X-Entity-Ref", entityRef);
        }

        // Multipart/alternative — text part first, then html (§3.4/§4).
        // Legacy (feature-flag-off) sends are plain text only.
        if (string.IsNullOrWhiteSpace(rendered.Html))
        {
            message.Body = new TextPart("plain") { Text = rendered.Text };
        }
        else
        {
            var body = new BodyBuilder
            {
                TextBody = rendered.Text,
                HtmlBody = rendered.Html,
            };
            message.Body = body.ToMessageBody();
        }
        return message;
    }

    private SecureSocketOptions ResolveTlsMode() => _options.TlsMode?.Trim().ToLowerInvariant() switch
    {
        "none" => SecureSocketOptions.None,
        "starttls" => SecureSocketOptions.StartTls,
        "starttlswhenavailable" => SecureSocketOptions.StartTlsWhenAvailable,
        "sslonconnect" => SecureSocketOptions.SslOnConnect,
        "auto" or null or "" => SecureSocketOptions.Auto,
        _ => SecureSocketOptions.Auto,
    };

    // ── Bounce handling (§5.4) ────────────────────────────────────────────────

    private static bool IsHardBounce(Exception ex)
    {
        // MailKit surfaces per-recipient failures as SmtpCommandException with
        // the SMTP status code; 5xx = permanent (bad mailbox), 4xx = transient.
        return ex is SmtpCommandException cmd && cmd.StatusCode >= (SmtpStatusCode)500;
    }

    private async Task<bool> IsBouncedAsync(string toEmail)
    {
        try
        {
            return await _db.Users
                .Where(u => u.Email != null && u.Email == toEmail && u.EmailBouncedAtUtc != null)
                .AnyAsync();
        }
        catch
        {
            // A failed lookup must never block a send.
            return false;
        }
    }

    /// <summary>Hard-bounced addresses stop receiving mail (§5.4): EmailBouncedAtUtc
    /// is set once and the sender short-circuits before a next send attempt.</summary>
    private async Task MarkBouncedAsync(string toEmail)
    {
        try
        {
            var user = await _db.Users
                .FirstOrDefaultAsync(u => u.Email != null && u.Email == toEmail);
            if (user is ApplicationUser { EmailBouncedAtUtc: null } appUser)
            {
                appUser.EmailBouncedAtUtc = DateTime.UtcNow;
                await _db.SaveChangesAsync();
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not mark {Email} bounced — weekly report still lists the bounces.", toEmail);
        }
    }

    // ── Legacy plain-text paths (feature flag off = instant rollback, §7.1) ───

    private async Task SendLegacyAsync(
        string toEmail, string subject, string body, SenderIdentity from, string? entityRef = null)
    {
        var rendered = new RenderedEmail(string.Empty, body);
        await SendAsync(toEmail, subject, rendered, from, template: "legacy", entityRef: entityRef);
    }

    /// <summary>Per-template From identities on one authenticated domain (§4/§5.3):
    /// OTP/invite → security@ (no Reply-To), payment/refund → billing@,
    /// everything else → hello@. All configurable via EmailSender options.</summary>
    private readonly record struct SenderIdentity(string Email, string DisplayName, string? ReplyTo);

    private SenderIdentity SecurityIdentity() => new(_options.GetSecurityFrom(), $"{_brand.AppName} Security", ReplyTo: null);
    private SenderIdentity BillingIdentity() => new(_options.GetBillingFrom(), $"{_brand.AppName} Billing", _brand.SupportEmail);
    private SenderIdentity HelloIdentity() => new(_options.GetHelloFrom(), _brand.AppName, _brand.SupportEmail);
}
