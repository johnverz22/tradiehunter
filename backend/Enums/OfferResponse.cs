namespace FixoApi.Enums;

/// <summary>
/// The tradie's response to a job offer, or a system-driven outcome.
/// Stored as string in the database via EF HasConversion.
/// </summary>
public enum OfferResponse
{
    Pending,
    Accepted,
    Declined,
    TimedOut,

    /// <summary>Homeowner withdrew the request before the tradie responded.</summary>
    Withdrawn,

    /// <summary>
    /// Another tradie accepted the same job, so this pending offer is closed.
    /// Used for project jobs where multiple concurrent offers exist.
    /// </summary>
    Superseded,

    /// <summary>Job was cancelled or expired while this offer was still pending.</summary>
    JobClosed,
}
