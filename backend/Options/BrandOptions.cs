namespace FixoApi.Options;

public class BrandOptions
{
    public string AppName { get; set; } = "TradieHunter";
    public string SupportEmail { get; set; } = "support@tradiehunter.nz";
    public string SupportHoursDisplay { get; set; } = "8am - 6pm NZT, Mon-Fri";

    /// <summary>
    /// Web host used to build email CTA deep links (EMAIL-TEMPLATE-REVISION-PLAN §4.1).
    /// There is no universal-link fallback web app yet (§9 Q1): when empty —
    /// the shipped default — every CTA button is omitted and the body stands alone.
    /// Set to e.g. "https://app.tradiehunter.nz" once links resolve.
    /// </summary>
    public string FrontendBaseUrl { get; set; } = string.Empty;

    /// <summary>
    /// <summary>
    /// Optional HTTPS PNG URL for the email header emblem. When empty,
    /// <see cref="Email.EmailTemplateRenderer"/> embeds <c>cid:th-mark</c>
    /// as an inline MIME linked resource.
    /// </summary>
    public string EmailLogoUrl { get; set; } = string.Empty;

    /// <summary>NZ street address for the email footer (§9 Q3 — placeholder until provided).</summary>
    public string PostalAddress { get; set; } = "Auckland, New Zealand";
}
