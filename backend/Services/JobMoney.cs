namespace FixoApi.Services;

/// <summary>
/// v1.7 (P12-11): server-side money math for the pay-at-completion flow.
/// Pure functions so every rule is unit-testable without a database.
/// All amounts are decimal(18,2) — never float (AGENTS.md).
/// </summary>
public static class JobMoney
{
    /// <summary>Labour = final hours × rate, rounded to cents, banker-safe (away from zero).</summary>
    public static decimal ComputeLabourAmount(decimal finalHours, decimal hourlyRate) =>
        Math.Round(finalHours * hourlyRate, 2, MidpointRounding.AwayFromZero);

    /// <summary>Final = labour + approved adjustments. Adjustments never negative (validated > 0).</summary>
    public static decimal ComputeFinalAmount(decimal labourAmount, decimal adjustmentsTotal) =>
        Math.Round(labourAmount + adjustmentsTotal, 2, MidpointRounding.AwayFromZero);

    /// <summary>
    /// P12-11: is the final amount far enough above the estimate to trigger the
    /// "higher than estimate" banner (and refuse auto-approve)?
    /// Tolerance is a percentage of the estimate, e.g. 15 = +15% (Consumer NZ
    /// estimate guidance). When no estimate was given the configured no-estimate
    /// cap applies instead.
    /// </summary>
    public static bool ExceedsTolerance(
        decimal finalAmount, decimal? estimatedTotal,
        decimal tolerancePercent, decimal noEstimateCap)
    {
        if (estimatedTotal.HasValue)
        {
            var budget = estimatedTotal.Value * (1 + tolerancePercent / 100m);
            return finalAmount > Math.Round(budget, 2, MidpointRounding.AwayFromZero);
        }

        // No estimate: anything above the configured cap needs a human look.
        return finalAmount > noEstimateCap;
    }

    /// <summary>
    /// P12-12: may this completion be auto-approved? Only when nothing is
    /// pending and the amount is inside tolerance (or under the no-estimate cap).
    /// </summary>
    public static bool CanAutoApprove(
        decimal finalAmount, decimal? estimatedTotal, bool hasPendingAdjustments,
        decimal tolerancePercent, decimal noEstimateCap) =>
        !hasPendingAdjustments &&
        !ExceedsTolerance(finalAmount, estimatedTotal, tolerancePercent, noEstimateCap);

    /// <summary>Commission for a payout, honoring the configured base (D5).</summary>
    public static decimal ComputeCommission(
        decimal grossAmount, decimal labourAmount, decimal commissionPercent,
        FixoApi.Options.CommissionBase base_)
    {
        var effective = base_ == FixoApi.Options.CommissionBase.LabourOnly
            ? labourAmount
            : grossAmount;
        return Math.Round(effective * (commissionPercent / 100m), 2, MidpointRounding.AwayFromZero);
    }
}
