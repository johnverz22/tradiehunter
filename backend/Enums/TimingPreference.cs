namespace FixoApi.Enums;

/// <summary>
/// v1.7 (P12-01): when the homeowner wants the job done. Timeframe is now
/// optional — <see cref="Flexible"/> is the default and carries no schedule.
/// Stored as a string in the database.
/// </summary>
public enum TimingPreference
{
    Flexible,
    Asap,
    SpecificDate,
    DateRange
}
