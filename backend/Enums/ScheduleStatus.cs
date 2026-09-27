namespace FixoApi.Enums;

/// <summary>Lifecycle state for a job's scheduling proposal.</summary>
public enum ScheduleStatus
{
    None,      // No schedule proposed yet
    Proposed,  // One party has suggested a date/time slot
    Confirmed, // Both parties agree on the schedule
}
