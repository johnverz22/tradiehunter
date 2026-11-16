namespace FixoApi.Options;

/// <summary>
/// Base the platform commission on labour only or labour + approved adjustments.
/// v1.7 D5 (resolved 2026-11-16): <see cref="LabourOnly"/> is the default —
/// commissioning a pass-through $400 hardware receipt pushes tradies off-platform.
/// The toggle stays in config so the policy can change without a deploy.
/// </summary>
public enum CommissionBase
{
    LabourOnly,
    LabourAndAdjustments
}

public class PayoutOptions
{
    public decimal CommissionPercent { get; set; } = 12.5m;

    /// <summary>v1.7 (P12-13/D5): commission base. Default LabourOnly.</summary>
    public CommissionBase CommissionAppliesTo { get; set; } = CommissionBase.LabourOnly;

    public string PayoutDay { get; set; } = "Monday";
    public decimal MinimumPayoutAmount { get; set; } = 0m;
    public string PayoutBatchCron { get; set; } = "0 2 * * 1";
}
