namespace FixoApi.Enums;

/// <summary>
/// v1.7 (P12-17): lifecycle of a single price adjustment proposal.
/// Only <see cref="Approved"/> adjustments count toward Job.AdjustmentsTotal —
/// a tradie can never invoice an unapproved extra.
/// </summary>
public enum AdjustmentStatus
{
    Pending,
    Approved,
    Declined,
    Withdrawn,
    Expired
}
