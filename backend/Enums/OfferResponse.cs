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
    TimedOut
}
