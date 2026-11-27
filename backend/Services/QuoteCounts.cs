using FixoApi.Enums;
using FixoApi.Models;

namespace FixoApi.Services;

/// <summary>
/// "N of M quotes in" for a Project job (plan 10, D1). Pure functions so the
/// rule is unit-testable without a database, same pattern as <see cref="JobMoney"/>.
/// </summary>
public readonly record struct QuoteCountSummary(int Requested, int Received);

public static class QuoteCounts
{
    /// <summary>
    /// Counts only apply to a homeowner looking at their own Project job that is
    /// still collecting quotes. Everyone else gets null counts on the DTO.
    /// </summary>
    public static bool Applies(Job job, bool isTradie) =>
        !isTradie && job.JobType == JobType.Project && job.Status == JobStatus.Requested;

    /// <summary>
    /// Requested = QuoteRequest offers still live (Pending) or answered with a quote
    /// (Accepted). Declined / TimedOut offers free their slot and are not counted.
    /// Received = the accepted quote, plus Submitted quotes that have not passed
    /// ValidUntilUtc (no quote-expiry job exists yet, so expiry is filtered here).
    /// Requested is never smaller than Received.
    /// </summary>
    public static QuoteCountSummary Compute(
        IEnumerable<OfferResponse> quoteRequestResponses,
        IEnumerable<(QuoteStatus Status, DateTime ValidUntilUtc)> quotes,
        DateTime nowUtc)
    {
        var requested = quoteRequestResponses
            .Count(r => r is OfferResponse.Pending or OfferResponse.Accepted);
        var received = quotes.Count(q =>
            q.Status == QuoteStatus.Accepted ||
            (q.Status == QuoteStatus.Submitted && q.ValidUntilUtc > nowUtc));
        return new QuoteCountSummary(Math.Max(requested, received), received);
    }
}
