using FixoApi.Options;

namespace FixoApi.Email;

/// <summary>
/// One label/value line in the summary table of an email (amount, reference,
/// deadline…). Values are pre-formatted by the caller — templates never
/// reformat data (EMAIL-TEMPLATE-REVISION-PLAN §3.2, mono right-aligned).
/// </summary>
public sealed record EmailSummaryRow(string Label, string Value, bool Emphasize = false);

/// <summary>Model for the _SummaryRow partial — one mono label/value row.</summary>
public sealed record SummaryRowModel(EmailSummaryRow Row, BrandOptions Brand);

/// <summary>Model for the _CtaButton partial — bulletproof navy button (§3.4).</summary>
public sealed record CtaButtonModel(string Label, string? Url);

/// <summary>Model for the _HeroPanel partial — amber-top urgent panel (§3.3).</summary>
public sealed record HeroPanelModel(string Text, string? SubText = null);

/// <summary>Model for the _FooterNote partial — "why you received this" + support line.</summary>
public sealed record FooterModel(string? Note, BrandOptions Brand);

/// <summary>
/// Shell the renderer fills: templates render their card content, then the
/// layout wraps it (header band + preheader slot + footer) around the result.
/// </summary>
public sealed class EmailLayoutModel
{
    public required string BodyHtml { get; init; }
    public string? Preheader { get; init; }
    public string? FooterNote { get; init; }
    public required BrandOptions Brand { get; init; }
    public required string MarkSrc { get; init; }
}

/// <summary>
/// One structured block of a <see cref="CriticalNoticeModel"/> (E5) — heading,
/// body and an optional callout. Callers pass data, never flattened prose.
/// </summary>
public sealed record EmailSection(string Heading, string Body, string? Callout = null);

/// <summary>
/// Uniform view of a template's content used by <see cref="PlainTextComposer"/>
/// to build the plain-text twin (multipart/alternative, §3.4/§4). Every model
/// implements it so the HTML template and the text part render from the same data.
/// All members are computed lazily — object initializers set the data first.
/// </summary>
public interface IEmailTextModel
{
    /// <summary>Brand config every template needs (names, support email, logo URL).</summary>
    BrandOptions Brand { get; }

    /// <summary>H1 of the email — same as the HTML heading, minus the brand prefix.</summary>
    string TextHeading { get; }

    /// <summary>Inbox preview line (80–95 chars) shown under the subject.</summary>
    string? TextPreheader { get; }

    /// <summary>Urgent hero line (OTP code, amount, deadline) or null when none.</summary>
    string? TextHeroLine { get; }

    /// <summary>Body paragraphs, in order.</summary>
    IReadOnlyList<string> TextBodyLines { get; }

    /// <summary>Summary rows (label/value), in order.</summary>
    IReadOnlyList<EmailSummaryRow> TextSummaryRows { get; }

    /// <summary>CTA button label, or null when the email has no button.</summary>
    string? TextCtaLabel { get; }

    /// <summary>CTA target — always a full absolute URL when present.</summary>
    string? TextCtaUrl { get; }

    /// <summary>"Why you received this" line for the footer, or null for the default.</summary>
    string? TextFooterNote { get; }
}

/// <summary>E1 — OTP / verification code.</summary>
public sealed class OtpModel : IEmailTextModel
{
    public required string Otp { get; init; }
    public required BrandOptions Brand { get; init; }

    public string TextHeading => "Verify your email";
    public string? TextPreheader => $"Code {Otp} — it expires in 10 minutes.";
    public string? TextHeroLine => Otp;
    public IReadOnlyList<string> TextBodyLines =>
    [
        "Enter this code in the TradieHunter app to finish signing in. It expires in 10 minutes.",
        "Didn't request it? Ignore this email — nothing will happen.",
    ];
    public IReadOnlyList<EmailSummaryRow> TextSummaryRows => [];
    public string? TextCtaLabel => null;
    public string? TextCtaUrl => null;
    public string? TextFooterNote => "You received this because someone is signing in to TradieHunter with your email address.";
}

/// <summary>E2 — staff invite (token + activation link, valid 24 h per Q4).</summary>
public sealed class StaffInviteModel : IEmailTextModel
{
    public required string Token { get; init; }
    /// <summary>Full activation URL from BrandOptions.FrontendBaseUrl; empty → CTA omitted (§4.1/Q1).</summary>
    public string? ActivationUrl { get; init; }
    public required int ExpiresInHours { get; init; }
    public required BrandOptions Brand { get; init; }

    private string AppName => string.IsNullOrWhiteSpace(Brand.AppName) ? "TradieHunter" : Brand.AppName;

    public string TextHeading => "Set up your staff account";
    public string? TextPreheader => $"Your invitation to the {AppName} admin panel expires in {ExpiresInHours} hours.";
    public string? TextHeroLine => null;
    public IReadOnlyList<string> TextBodyLines
    {
        get
        {
            var lines = new List<string>
            {
                $"An administrator invited you to {AppName}'s staff console. " +
                "Use the button below to choose a password and activate your account.",
            };
            if (string.IsNullOrWhiteSpace(ActivationUrl))
            {
                lines.Add("Enter this activation token where the invitation was shared with you:");
            }
            lines.Add($"The invitation is valid for {ExpiresInHours} hours.");
            return lines;
        }
    }
    public IReadOnlyList<EmailSummaryRow> TextSummaryRows => [];
    public string? TextCtaLabel => string.IsNullOrWhiteSpace(ActivationUrl) ? null : "Set your password";
    public string? TextCtaUrl => ActivationUrl;
    public string? TextFooterNote => $"You received this because an administrator invited you to {AppName}'s staff console.";
}

/// <summary>E3 — payment verified, job booked.</summary>
public sealed class PaymentVerifiedModel : IEmailTextModel
{
    public required string JobTitle { get; init; }
    /// <summary>Invariant-formatted amount with currency placement, e.g. "1234.56 NZD" (§2.3 #10).</summary>
    public required string AmountDisplay { get; init; }
    /// <summary>Tradie display name, or null when unknown → "the TradieHunter team" phrasing.</summary>
    public string? TradieName { get; init; }
    public string? Reference { get; init; }
    /// <summary>Job deep link (absolute URL); empty → CTA omitted (§4.1/Q1).</summary>
    public string? JobUrl { get; init; }
    public required BrandOptions Brand { get; init; }

    private string PaidTo => string.IsNullOrWhiteSpace(TradieName) ? "the TradieHunter team" : TradieName!;

    public string TextHeading => "Your payment is confirmed";
    public string? TextPreheader => $"We matched your {AmountDisplay} transfer. You're booked.";
    public string? TextHeroLine => AmountDisplay;
    public IReadOnlyList<string> TextBodyLines =>
    [
        $"We matched your transfer. {PaidTo} will be in touch to confirm the visit time.",
    ];
    public IReadOnlyList<EmailSummaryRow> TextSummaryRows
    {
        get
        {
            var rows = new List<EmailSummaryRow> { new("Job", JobTitle), new("Amount", AmountDisplay, Emphasize: true) };
            if (!string.IsNullOrWhiteSpace(TradieName)) rows.Add(new("Paid to", TradieName!));
            if (!string.IsNullOrWhiteSpace(Reference)) rows.Add(new("Reference", Reference!));
            return rows;
        }
    }
    public string? TextCtaLabel => string.IsNullOrWhiteSpace(JobUrl) ? null : "View job";
    public string? TextCtaUrl => JobUrl;
    public string? TextFooterNote => "You received this because a payment on your TradieHunter job was verified.";
}

/// <summary>E4 — receipt rejected, new deadline (NZT via NzTime — §4.2 E4).</summary>
public sealed class PaymentRejectedModel : IEmailTextModel
{
    public required string JobTitle { get; init; }
    public required string Reason { get; init; }
    /// <summary>Pre-formatted NZT deadline ("d MMM yyyy, h:mm a").</summary>
    public required string DeadlineDisplay { get; init; }
    /// <summary>Payment screen deep link; empty → CTA omitted.</summary>
    public string? PaymentUrl { get; init; }
    public required BrandOptions Brand { get; init; }

    public string TextHeading => "We need a different receipt";
    public string? TextPreheader => $"Upload a new receipt by {DeadlineDisplay} to keep this booking.";
    public string? TextHeroLine => $"New deadline: {DeadlineDisplay}";
    public IReadOnlyList<string> TextBodyLines =>
    [
        $"Our team couldn't accept the receipt you uploaded for \"{JobTitle}\".",
        $"Reason: {Reason}",
        $"Please upload a corrected receipt by {DeadlineDisplay} so we can confirm your tradie.",
    ];
    public IReadOnlyList<EmailSummaryRow> TextSummaryRows => [];
    public string? TextCtaLabel => string.IsNullOrWhiteSpace(PaymentUrl) ? null : "Upload new receipt";
    public string? TextCtaUrl => PaymentUrl;
    public string? TextFooterNote => "You received this because a receipt you uploaded for a TradieHunter job needs correcting.";
}

/// <summary>E5 — generic critical notice with structured sections.</summary>
public sealed class CriticalNoticeModel : IEmailTextModel
{
    public required string Heading { get; init; }
    public string? Preheader { get; init; }
    public IReadOnlyList<EmailSection> Sections { get; init; } = [];
    public string? CtaLabel { get; init; }
    public string? CtaUrl { get; init; }
    public required BrandOptions Brand { get; init; }

    public string TextHeading => Heading;
    public string? TextPreheader => Preheader;
    public string? TextHeroLine => null;
    public IReadOnlyList<string> TextBodyLines =>
        Sections.Select(s => string.IsNullOrWhiteSpace(s.Callout)
            ? s.Body
            : $"{s.Body} {s.Callout}")
            .ToList();
    public IReadOnlyList<EmailSummaryRow> TextSummaryRows => [];
    public string? TextCtaLabel => CtaLabel;
    public string? TextCtaUrl => CtaUrl;
    public string? TextFooterNote => null;
}

/// <summary>E6 — refund processed (money moved).</summary>
public sealed class RefundProcessedModel : IEmailTextModel
{
    public required string JobTitle { get; init; }
    public required string AmountDisplay { get; init; }
    public required string Reference { get; init; }
    /// <summary>Payment screen deep link; empty → CTA omitted.</summary>
    public string? PaymentUrl { get; init; }
    public required BrandOptions Brand { get; init; }

    public string TextHeading => "Your refund is on its way";
    public string? TextPreheader => $"{AmountDisplay} has been transferred back to your account.";
    public string? TextHeroLine => AmountDisplay;
    public IReadOnlyList<string> TextBodyLines =>
    [
        $"The refund for \"{JobTitle}\" has been processed from our account.",
        "Your bank will show the money within 1–2 business days.",
    ];
    public IReadOnlyList<EmailSummaryRow> TextSummaryRows =>
    [
        new EmailSummaryRow("Job", JobTitle),
        new EmailSummaryRow("Amount", AmountDisplay, Emphasize: true),
        new EmailSummaryRow("Reference", Reference),
        new EmailSummaryRow("Expected", "1–2 business days"),
    ];
    public string? TextCtaLabel => string.IsNullOrWhiteSpace(PaymentUrl) ? null : "View payment";
    public string? TextCtaUrl => PaymentUrl;
    public string? TextFooterNote => "You received this because a refund was processed for your TradieHunter job.";
}

/// <summary>E7 — account suspended by staff (warm, factual, always a recourse).</summary>
public sealed class AccountSuspendedModel : IEmailTextModel
{
    public required string Name { get; init; }
    public required BrandOptions Brand { get; init; }

    private string AppName => string.IsNullOrWhiteSpace(Brand.AppName) ? "TradieHunter" : Brand.AppName;
    private string SupportEmail => string.IsNullOrWhiteSpace(Brand.SupportEmail) ? "support@tradiehunter.nz" : Brand.SupportEmail;
    private string SupportHours => string.IsNullOrWhiteSpace(Brand.SupportHoursDisplay) ? "8am - 6pm NZT, Mon-Fri" : Brand.SupportHoursDisplay;

    public string TextHeading => "Your account has been suspended";
    public string? TextPreheader => "What happened, and how to get it reviewed.";
    public string? TextHeroLine => null;
    public IReadOnlyList<string> TextBodyLines =>
    [
        $"Hi {Name}, our team has suspended your {AppName} account.",
        "If you believe this is a mistake, reply to this email or contact " +
        $"{SupportEmail} ({SupportHours}) and we'll review it.",
    ];
    public IReadOnlyList<EmailSummaryRow> TextSummaryRows => [];
    public string? TextCtaLabel => $"Email {SupportEmail}";
    public string? TextCtaUrl => $"mailto:{SupportEmail}";
    public string? TextFooterNote => $"You received this because your {AppName} account was suspended by our team.";
}

/// <summary>E8 — job closed or expired (wired from the expiry worker and cancel paths).</summary>
public sealed class JobClosedModel : IEmailTextModel
{
    public required string JobTitle { get; init; }
    public required string Reason { get; init; }
    /// <summary>"Post a job again" deep link; empty → CTA omitted.</summary>
    public string? PostAgainUrl { get; init; }
    public required BrandOptions Brand { get; init; }

    public string TextHeading => $"Your job \"{JobTitle}\" has been closed";
    public string? TextPreheader => $"Reason: {Reason}";
    public string? TextHeroLine => null;
    public IReadOnlyList<string> TextBodyLines =>
    [
        $"Reason: {Reason}",
        "Your job details are saved — post it again any time from the app.",
    ];
    public IReadOnlyList<EmailSummaryRow> TextSummaryRows => [];
    public string? TextCtaLabel => string.IsNullOrWhiteSpace(PostAgainUrl) ? null : "Post a job again";
    public string? TextCtaUrl => PostAgainUrl;
    public string? TextFooterNote => "You received this because your TradieHunter job was closed.";
}

/// <summary>
/// E9 — staff alert: something needs the admin team (receipt waiting, credential
/// to review, SLA breach, flag threshold, payout batch). One template for every
/// staff event; the caller supplies heading, body, summary rows and the admin
/// page to open, so there is no per-event layout to maintain.
/// </summary>
public sealed class StaffAlertModel : IEmailTextModel
{
    private const int PreheaderMax = 110;

    public required string Heading { get; init; }
    public required string Body { get; init; }
    /// <summary>Inbox preview line; defaults to the body, trimmed to fit one line.</summary>
    public string? Preheader { get; init; }
    public IReadOnlyList<EmailSummaryRow> Rows { get; init; } = [];
    /// <summary>Absolute admin URL (FrontendBaseUrl + path); empty → CTA omitted.</summary>
    public string? AdminUrl { get; init; }
    public required BrandOptions Brand { get; init; }

    public string TextHeading => Heading;
    public string? TextPreheader => string.IsNullOrWhiteSpace(Preheader) ? Trim(Body) : Preheader;
    public string? TextHeroLine => null;
    public IReadOnlyList<string> TextBodyLines => [Body];
    public IReadOnlyList<EmailSummaryRow> TextSummaryRows => Rows;
    public string? TextCtaLabel => string.IsNullOrWhiteSpace(AdminUrl) ? null : "Open in admin";
    public string? TextCtaUrl => AdminUrl;
    public string? TextFooterNote => "You received this because you are a TradieHunter staff member.";

    private static string Trim(string text) =>
        text.Length <= PreheaderMax ? text : text[..(PreheaderMax - 1)].TrimEnd() + "…";
}

/// <summary>E10 — credential approved or rejected.</summary>
public sealed class CredentialDecisionModel : IEmailTextModel
{
    public required string CredentialType { get; init; }
    public required bool Approved { get; init; }
    public string? RejectReason { get; init; }
    /// <summary>Credentials screen deep link; empty → CTA omitted.</summary>
    public string? CredentialsUrl { get; init; }
    public required BrandOptions Brand { get; init; }

    public string TextHeading => Approved
        ? $"{CredentialType} credential approved"
        : $"{CredentialType} credential rejected";

    public string? TextPreheader => Approved
        ? $"Your {CredentialType} credential has been approved."
        : $"Your {CredentialType} credential was rejected — see details.";

    public string? TextHeroLine => null;

    public IReadOnlyList<string> TextBodyLines => Approved
        ? [$"Great news — our team reviewed and approved your {CredentialType} credential."]
        : string.IsNullOrWhiteSpace(RejectReason)
            ? [$"Our team couldn't approve your {CredentialType} credential. Please upload an updated document."]
            : [$"Our team couldn't approve your {CredentialType} credential.", $"Reason: {RejectReason}", "Please upload an updated document."];

    public IReadOnlyList<EmailSummaryRow> TextSummaryRows => [];
    public string? TextCtaLabel => string.IsNullOrWhiteSpace(CredentialsUrl) ? null : "View credentials";
    public string? TextCtaUrl => CredentialsUrl;
    public string? TextFooterNote => "You received this because you uploaded a credential on TradieHunter.";
}
