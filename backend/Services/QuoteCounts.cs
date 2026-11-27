using FixoApi.Enums;
using FixoApi.Models;

namespace FixoApi.Services;

/// <summary>
/// "N of M quotes in" for a Project job (plan 10, D1). Pure functions so the
/// rule is unit-testable without a database, same pattern as <see cref="JobMoney"/>.
/// </summary>
public readonly record struct QuoteCountSummary(int? Requested, int Received);

public static class QuoteCounts
{
    /// <summary>
    /// Counts only apply to a homeowner looking at their own Project job that is
    /// still collecting quotes. Everyone else gets null counts on the DTO.
    /// Plan 10 (Q7.8): also applies to open-board jobs (counts differ — see Compute).
    /// </summary>
    public static bool Applies(Job job, bool isTradie) =>
        !isTradie && job.JobType == JobType.Project && job.Status == JobStatus.Requested;

    /// <summary>
    /// Invite-only: Requested = QuoteRequest offers still live (Pending) or answered with
    /// a quote (Accepted). Declined / TimedOut offers free their slot and are not counted.
    /// Open-board (Q7.8): <c>Requested</c> is null — the homeowner sees "N quotes in", no "of M".
    ///
    /// Received = the accepted quote, plus Submitted quotes that have not passed
    /// ValidUntilUtc (no quote-expiry job exists yet, so expiry is filtered here).
    /// Requested (when not null) is never smaller than Received.
    /// </summary>
    public static QuoteCountSummary Compute(
        bool openToBoard,
        IEnumerable<OfferResponse> quoteRequestResponses,
        IEnumerable<(QuoteStatus Status, DateTime ValidUntilUtc)> quotes,
        DateTime nowUtc)
    {
        var received = quotes.Count(q =>
            q.Status == QuoteStatus.Accepted ||
            (q.Status == QuoteStatus.Submitted && q.ValidUntilUtc > nowUtc));

        if (openToBoard)
        {
            // Q7.8: no denominator for open-board jobs.
            return new QuoteCountSummary(null, received);
        }

        var requested = quoteRequestResponses
            .Count(r => r is OfferResponse.Pending or OfferResponse.Accepted);
        return new QuoteCountSummary(Math.Max(requested, received), received);
    }
}
