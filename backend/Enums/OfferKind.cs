namespace FixoApi.Enums;

/// <summary>
/// v1.7 (P12-23): what a JobOffer represents.
/// <see cref="Instant"/> is the classic hourly request (single pending offer,
/// tradie taps accept). <see cref="QuoteRequest"/> asks a tradie to submit a
/// structured quote for a project job.
/// </summary>
public enum OfferKind
{
    Instant,
    QuoteRequest
}
