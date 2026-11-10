namespace FixoApi.Models;

/// <summary>
/// Manual bank-transfer payment settings, bound from the <c>PaymentInstructions</c>
/// configuration section. Held in configuration (not hardcoded) so a white-label
/// partner can point transfers at their own account without a code change.
/// </summary>
public class PaymentOptions
{
    /// <summary>Account name the homeowner types into their banking app.</summary>
    public string AccountName { get; set; } = "TradieHunter Ltd";

    /// <summary>Account number the funds are transferred to.</summary>
    public string AccountNumber { get; set; } = string.Empty;

    /// <summary>
    /// Template for the job-specific transfer reference. <c>{JobId}</c> is
    /// substituted with the job's identifier, e.g. <c>TH-{JobId}</c> → <c>TH-42</c>.
    /// </summary>
    public string ReferenceFormat { get; set; } = "TH-{JobId}";

    /// <summary>
    /// Hours the homeowner has to pay before the job expires and the tradie is
    /// released (P4-06). Re-baselined each time staff reject a receipt.
    /// Set to 0 to expire immediately — used by scripts/p4-smoke.sh to exercise
    /// the expiry job without waiting out a real window.
    /// </summary>
    public int WindowHours { get; set; } = 2;

    /// <summary>
    /// Private blob container holding receipts. Kept apart from tradie
    /// credentials so access to one class of document can be revoked
    /// independently of the other.
    /// </summary>
    public string PaymentsContainer { get; set; } = "th-payments";

    /// <summary>Render <paramref name="jobId"/> into <see cref="ReferenceFormat"/>.</summary>
    public string BuildReference(int jobId) =>
        ReferenceFormat.Replace("{JobId}", jobId.ToString(), StringComparison.Ordinal);
}
