namespace FixoApi.Enums;

/// <summary>
/// v1.7 (P12-17): what kind of on-demand price change the tradie is proposing.
/// </summary>
public enum AdjustmentKind
{
    Materials,
    ExtraLabour,
    Travel,
    Other
}
