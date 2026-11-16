namespace FixoApi.Options;

/// <summary>
/// SMTP relay + email identity configuration (EMAIL-TEMPLATE-REVISION-PLAN §4/§5).
/// Bound from the "EmailSender" config section. SandboxMode keeps the current
/// dev loop (Mailpit on localhost:1025) intact; production flips config only.
/// </summary>
public class EmailSenderOptions
{
    public string Host { get; set; } = "localhost";
    public int Port { get; set; } = 1025;

    /// <summary>Relay credentials — empty for the unauthenticated Mailpit dev relay.</summary>
    public string? Username { get; set; }
    public string? Password { get; set; }

    /// <summary>"None" | "StartTls" | "SslOnConnect" (MailKit SecureSocketOptions).</summary>
    public string TlsMode { get; set; } = "None";

    /// <summary>
    /// Dev default: subjects are stamped with a visible "[SANDBOX]" prefix so
    /// screenshots can't be mistaken for production sends (§5.6).
    /// </summary>
    public bool SandboxMode { get; set; } = true;

    /// <summary>
    /// Feature flag (§7.1): false keeps the legacy plain-text paths for one
    /// release — instant rollback if a template bug appears. Default true in
    /// dev config; production flips when the manual matrix passes.
    /// </summary>
    public bool UseTemplates { get; set; } = true;

    /// <summary>Domain all From identities live on — one SPF/DKIM domain, no subdomain splitting in v1 (§4).</summary>
    public string MailDomain { get; set; } = "tradiehunter.nz";

    /// <summary>security@ — OTP + staff invites. No Reply-To (unmonitored replies would leak codes).</summary>
    public string? SecurityFromEmail { get; set; }

    /// <summary>billing@ — payment + refund emails, Reply-To support@.</summary>
    public string? BillingFromEmail { get; set; }

    /// <summary>hello@ — everything else, Reply-To support@.</summary>
    public string? HelloFromEmail { get; set; }

    /// <summary>Envelope sender for the relay (Return-Path) — bounces land here (§5.3).</summary>
    public string? BounceAddress { get; set; }

    public string GetSecurityFrom() => WithDefaultDomain(SecurityFromEmail, "security");
    public string GetBillingFrom() => WithDefaultDomain(BillingFromEmail, "billing");
    public string GetHelloFrom() => WithDefaultDomain(HelloFromEmail, "hello");
    public string GetBounceAddress() => WithDefaultDomain(BounceAddress, "bounces");

    private static string WithDefaultDomain(string? configured, string localPart)
    {
        if (!string.IsNullOrWhiteSpace(configured)) return configured;
        return $"{localPart}@tradiehunter.nz";
    }
}
