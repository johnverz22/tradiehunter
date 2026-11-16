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
    /// Wordmark image for the email header band, hosted on the brand CDN
    /// (§3.4 — never hard-coded in Razor). The @2x asset from
    /// docs/design/v1.6.1/assets/brand/png/wordmark-on-light.png is uploaded
    /// there; see docs/email-ops.md §Assets.
    /// </summary>
    public string EmailLogoUrl { get; set; } = "https://cdn.tradiehunter.nz/email/wordmark-on-light@2x.png";

    /// <summary>NZ street address for the email footer (§9 Q3 — placeholder until provided).</summary>
    public string PostalAddress { get; set; } = "Auckland, New Zealand";
}
