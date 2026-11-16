namespace FixoApi.Enums;

/// <summary>
/// v1.7 (P12-23): how a project quote is priced.
/// <list type="bullet">
/// <item><see cref="Fixed"/> — one agreed price for the whole scope.</item>
/// <item><see cref="EstimateRange"/> — min/max range; final validated against it at completion.</item>
/// <item><see cref="HourlyWithCap"/> — hourly billing that must not exceed the cap without an approved adjustment.</item>
/// </list>
/// </summary>
public enum QuotePricingModel
{
    Fixed,
    EstimateRange,
    HourlyWithCap
}
