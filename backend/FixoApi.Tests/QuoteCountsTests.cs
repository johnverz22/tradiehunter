using FixoApi.Enums;
using FixoApi.Models;
using FixoApi.Services;
using Xunit;

namespace FixoApi.Tests;

/// <summary>
/// Plan 10 (Q1 / Q7.8): "N of M quotes in" rules. Pure, no database.
/// </summary>
public class QuoteCountsTests
{
    private static readonly DateTime Now = new(2026, 11, 27, 9, 0, 0, DateTimeKind.Utc);
    private static readonly DateTime Future = Now.AddHours(24);
    private static readonly DateTime Past = Now.AddHours(-1);

    // Invite-only helper (openToBoard: false).
    private static QuoteCountSummary Count(
        OfferResponse[] offers, (QuoteStatus, DateTime)[] quotes) =>
        QuoteCounts.Compute(openToBoard: false, offers, quotes, Now);

    // Open-board helper (openToBoard: true).
    private static QuoteCountSummary CountBoard((QuoteStatus, DateTime)[] quotes) =>
        QuoteCounts.Compute(openToBoard: true, Array.Empty<OfferResponse>(), quotes, Now);

    [Fact]
    public void No_requests_gives_zero_of_zero()
    {
        var c = Count([], []);
        Assert.Equal(0, c.Requested);   // invite-only: 0 not null
        Assert.Equal(0, c.Received);
    }

    [Fact]
    public void Three_requested_two_submitted()
    {
        var c = Count(
            [OfferResponse.Accepted, OfferResponse.Accepted, OfferResponse.Pending],
            [(QuoteStatus.Submitted, Future), (QuoteStatus.Submitted, Future)]);
        Assert.Equal(3, c.Requested);
        Assert.Equal(2, c.Received);
    }

    [Fact]
    public void Declined_and_timed_out_offers_free_their_slot()
    {
        var c = Count(
            [OfferResponse.Declined, OfferResponse.TimedOut, OfferResponse.Pending],
            []);
        Assert.Equal(1, c.Requested);
        Assert.Equal(0, c.Received);
    }

    [Fact]
    public void Expired_or_withdrawn_quotes_are_not_received()
    {
        var c = Count(
            [OfferResponse.Accepted, OfferResponse.Accepted, OfferResponse.Accepted],
            [(QuoteStatus.Submitted, Past), (QuoteStatus.Withdrawn, Future), (QuoteStatus.Expired, Past)]);
        Assert.Equal(0, c.Received);
        Assert.Equal(3, c.Requested);
    }

    [Fact]
    public void Accepted_quote_counts_even_after_its_window()
    {
        var c = Count([OfferResponse.Accepted], [(QuoteStatus.Accepted, Past)]);
        Assert.Equal(1, c.Received);
    }

    [Fact]
    public void Requested_is_never_smaller_than_received()
    {
        var c = Count([], [(QuoteStatus.Submitted, Future)]);
        Assert.Equal(1, c.Requested);
        Assert.Equal(1, c.Received);
    }

    // ── Q7.8: open-board jobs have null denominator ──────────────────────────

    [Fact]
    public void Open_board_job_requested_is_null()
    {
        var c = CountBoard([(QuoteStatus.Submitted, Future), (QuoteStatus.Submitted, Future)]);
        Assert.Null(c.Requested);
        Assert.Equal(2, c.Received);
    }

    [Fact]
    public void Open_board_job_expired_quotes_not_counted()
    {
        var c = CountBoard([(QuoteStatus.Submitted, Past)]);
        Assert.Null(c.Requested);
        Assert.Equal(0, c.Received);
    }

    [Theory]
    [InlineData(JobType.Project, JobStatus.Requested, false, true)]
    [InlineData(JobType.Project, JobStatus.Requested, true, false)]   // tradie
    [InlineData(JobType.Hourly, JobStatus.Requested, false, false)]   // not a project
    [InlineData(JobType.Project, JobStatus.Booked, false, false)]     // no longer collecting
    public void Applies_only_to_homeowner_project_jobs_still_requested(
        JobType type, JobStatus status, bool isTradie, bool expected)
    {
        var job = new Job { JobType = type, Status = status };
        Assert.Equal(expected, QuoteCounts.Applies(job, isTradie));
    }
}

