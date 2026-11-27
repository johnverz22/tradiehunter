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
    /// Deprecated — the v2 email header renders a text wordmark (Lexend, white
    /// + hero-gold accent) rather than an image, so no hosted asset is needed.
    /// Retained so existing configuration binding does not break; a future
    /// image-wordmark option can revive it after the formal v2 brand pass.
    /// </summary>
    public string EmailLogoUrl { get; set; } = string.Empty;

    /// <summary>NZ street address for the email footer (§9 Q3 — placeholder until provided).</summary>
    public string PostalAddress { get; set; } = "Auckland, New Zealand";
}
