using FixoApi.Enums;
using FixoApi.Services;
using Xunit;

namespace FixoApi.Tests;

/// <summary>
/// P12-10 / P12-28: one test per edge of the §4.2 status flow, plus rejection
/// tests for the removed edges. The table is pure (JobFlowTransitions), so
/// these run without a database.
/// </summary>
public class JobFlowTransitionTests
{
    // ── v2 (pay-at-completion) happy path ─────────────────────────────────────

    [Theory]
    [InlineData(JobStatus.Requested, JobStatus.Booked, UserRole.Tradie, true)]          // tradie accepts → Booked
    [InlineData(JobStatus.Requested, JobStatus.Booked, UserRole.Homeowner, true)]      // homeowner accepts quote → Booked
    [InlineData(JobStatus.Booked, JobStatus.InProgress, UserRole.Tradie, true)]        // check-in
    [InlineData(JobStatus.InProgress, JobStatus.AwaitingConfirmation, UserRole.Tradie, true)] // check-out
    [InlineData(JobStatus.AwaitingConfirmation, JobStatus.AwaitingPayment, UserRole.Homeowner, true)] // Approve & pay
    [InlineData(JobStatus.AwaitingConfirmation, JobStatus.AwaitingPayment, UserRole.Tradie, false)]
    [InlineData(JobStatus.AwaitingConfirmation, JobStatus.Disputed, UserRole.Homeowner, true)] // dispute amount
    [InlineData(JobStatus.AwaitingPayment, JobStatus.PaymentReview, UserRole.Homeowner, true)] // receipt uploaded
    [InlineData(JobStatus.PaymentReview, JobStatus.Completed, UserRole.Staff, true)]   // verify → Completed
    [InlineData(JobStatus.PaymentReview, JobStatus.Completed, UserRole.Superadmin, true)]
    [InlineData(JobStatus.PaymentReview, JobStatus.AwaitingPayment, UserRole.Staff, true)] // reject
    [InlineData(JobStatus.PaymentReview, JobStatus.Booked, UserRole.Staff, false)]     // REMOVED edge
    [InlineData(JobStatus.Booked, JobStatus.Cancelled, UserRole.Homeowner, true)]
    [InlineData(JobStatus.Booked, JobStatus.Cancelled, UserRole.Tradie, true)]
    [InlineData(JobStatus.InProgress, JobStatus.Cancelled, UserRole.Homeowner, true)]
    [InlineData(JobStatus.Requested, JobStatus.Cancelled, UserRole.Staff, true)]       // matching exhausted
    [InlineData(JobStatus.Requested, JobStatus.Cancelled, UserRole.Tradie, false)]
    [InlineData(JobStatus.Disputed, JobStatus.AwaitingConfirmation, UserRole.Staff, true)] // dispute resolved
    [InlineData(JobStatus.Disputed, JobStatus.AwaitingPayment, UserRole.Staff, true)]
    [InlineData(JobStatus.Disputed, JobStatus.Cancelled, UserRole.Staff, true)]
    public void V2_edges_match_the_specification(
        JobStatus from, JobStatus to, UserRole actor, bool expected)
    {
        Assert.Equal(expected, JobFlowTransitions.IsValid(from, to, actor, flowVersion: 2));
    }

    [Fact]
    public void V2_requested_to_awaiting_payment_is_removed()
    {
        // The core P12-10 change: payment is no longer the step after accept.
        Assert.False(JobFlowTransitions.IsValid(
            JobStatus.Requested, JobStatus.AwaitingPayment, UserRole.Tradie, flowVersion: 2));
    }

    [Fact]
    public void V2_has_no_expiry_cancels()
    {
        // P12-12: finished work is never expired — overdue policy instead.
        Assert.False(JobFlowTransitions.IsValid(
            JobStatus.AwaitingPayment, JobStatus.Expired, UserRole.Staff, flowVersion: 2));
        Assert.False(JobFlowTransitions.IsValid(
            JobStatus.PaymentReview, JobStatus.Expired, UserRole.Staff, flowVersion: 2));
    }

    [Fact]
    public void V2_confirm_to_completed_is_removed()
    {
        // Under v2 the homeowner must go through AwaitingPayment; a plain
        // confirm would complete an unpaid job.
        Assert.False(JobFlowTransitions.IsValid(
            JobStatus.AwaitingConfirmation, JobStatus.Completed, UserRole.Homeowner, flowVersion: 2));
    }

    // ── v1 (legacy upfront payment) keeps the old table ──────────────────────

    [Theory]
    [InlineData(JobStatus.Requested, JobStatus.AwaitingPayment, UserRole.Tradie, true)]  // old accept edge
    [InlineData(JobStatus.AwaitingPayment, JobStatus.PaymentReview, UserRole.Homeowner, true)]
    [InlineData(JobStatus.PaymentReview, JobStatus.Booked, UserRole.Staff, true)]        // old verify edge
    [InlineData(JobStatus.PaymentReview, JobStatus.AwaitingPayment, UserRole.Staff, true)]
    [InlineData(JobStatus.AwaitingPayment, JobStatus.Expired, UserRole.Staff, true)]     // old expiry edge
    [InlineData(JobStatus.AwaitingConfirmation, JobStatus.Completed, UserRole.Homeowner, true)] // old confirm
    [InlineData(JobStatus.Requested, JobStatus.Booked, UserRole.Tradie, false)]          // NOT a v1 edge
    [InlineData(JobStatus.PaymentReview, JobStatus.Completed, UserRole.Staff, false)]    // NOT a v1 edge
    [InlineData(JobStatus.AwaitingConfirmation, JobStatus.AwaitingPayment, UserRole.Homeowner, false)] // NOT v1
    public void V1_edges_are_preserved(
        JobStatus from, JobStatus to, UserRole actor, bool expected)
    {
        Assert.Equal(expected, JobFlowTransitions.IsValid(from, to, actor, flowVersion: 1));
    }
}
