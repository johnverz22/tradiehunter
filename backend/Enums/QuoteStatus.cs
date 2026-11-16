namespace FixoApi.Enums;

/// <summary>
/// v1.7 (P12-23): lifecycle of a tradie's quote on a project job.
/// </summary>
public enum QuoteStatus
{
    Submitted,
    Accepted,
    Declined,
    Withdrawn,
    Expired
}
