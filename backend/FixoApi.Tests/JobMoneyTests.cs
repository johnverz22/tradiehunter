using FixoApi.Options;
using FixoApi.Services;
using Xunit;

namespace FixoApi.Tests;

/// <summary>
/// P12-11 / P12-13 / P12-28: money-math tests — rounding, adjustments,
/// cap/tolerance and the commission base (D5). All decimal, never float.
/// </summary>
public class JobMoneyTests
{
    // ── Labour ────────────────────────────────────────────────────────────────

    [Theory]
    [InlineData(3.5, 45.00, 157.50)]
    [InlineData(1, 33.33, 33.33)]
    [InlineData(2.25, 80.00, 180.00)]
    [InlineData(0.5, 45.115, 22.56)] // rounds away from zero at the cent
    public void Labour_is_rate_times_hours_rounded_to_cents(
        decimal hours, decimal rate, decimal expected)
    {
        Assert.Equal(expected, JobMoney.ComputeLabourAmount(hours, rate));
    }

    // ── Final amount ──────────────────────────────────────────────────────────

    [Fact]
    public void Final_amount_is_labour_plus_approved_adjustments()
    {
        var final = JobMoney.ComputeFinalAmount(157.50m, 42.50m);
        Assert.Equal(200.00m, final);
    }

    [Fact]
    public void Final_amount_with_no_adjustments_equals_labour()
    {
        Assert.Equal(157.50m, JobMoney.ComputeFinalAmount(157.50m, 0m));
    }

    // ── Tolerance (P12-11: default 15%, Consumer NZ estimate guidance) ───────

    [Fact]
    public void Within_tolerance_is_not_flagged()
    {
        // 300 estimate, 15% tolerance → up to 345 allowed.
        Assert.False(JobMoney.ExceedsTolerance(345m, 300m, 15m, 800m));
        Assert.False(JobMoney.ExceedsTolerance(300m, 300m, 15m, 800m));
    }

    [Fact]
    public void Beyond_tolerance_is_flagged()
    {
        Assert.True(JobMoney.ExceedsTolerance(345.01m, 300m, 15m, 800m));
        Assert.True(JobMoney.ExceedsTolerance(400m, 300m, 15m, 800m));
    }

    [Fact]
    public void Under_estimate_is_never_flagged()
    {
        Assert.False(JobMoney.ExceedsTolerance(100m, 300m, 15m, 800m));
    }

    [Fact]
    public void No_estimate_uses_the_no_estimate_cap()
    {
        Assert.False(JobMoney.ExceedsTolerance(800m, null, 15m, 800m));
        Assert.True(JobMoney.ExceedsTolerance(800.01m, null, 15m, 800m));
    }

    // ── Auto-approve (P12-12) ────────────────────────────────────────────────

    [Fact]
    public void Auto_approve_requires_no_pending_adjustments()
    {
        Assert.False(JobMoney.CanAutoApprove(300m, 300m, hasPendingAdjustments: true, 15m, 800m));
        Assert.True(JobMoney.CanAutoApprove(300m, 300m, hasPendingAdjustments: false, 15m, 800m));
    }

    [Fact]
    public void Auto_approve_refuses_out_of_tolerance_amounts()
    {
        // A higher bill must escalate to staff, never silently approve.
        Assert.False(JobMoney.CanAutoApprove(500m, 300m, hasPendingAdjustments: false, 15m, 800m));
    }

    [Fact]
    public void Auto_approve_refuses_over_cap_when_no_estimate()
    {
        Assert.False(JobMoney.CanAutoApprove(900m, null, hasPendingAdjustments: false, 15m, 800m));
        Assert.True(JobMoney.CanAutoApprove(500m, null, hasPendingAdjustments: false, 15m, 800m));
    }

    // ── Commission (P12-13 / D5: LabourOnly default) ─────────────────────────

    [Fact]
    public void Commission_on_labour_only_ignores_adjustments()
    {
        // 157.50 labour + 342.50 materials = 500 gross; 12.5% of labour only.
        var commission = JobMoney.ComputeCommission(
            500m, 157.50m, 12.5m, CommissionBase.LabourOnly);
        Assert.Equal(19.69m, commission); // 157.50 × 0.125 = 19.6875 → 19.69
    }

    [Fact]
    public void Commission_on_labour_and_adjustments_uses_gross()
    {
        var commission = JobMoney.ComputeCommission(
            500m, 157.50m, 12.5m, CommissionBase.LabourAndAdjustments);
        Assert.Equal(62.50m, commission); // 500 × 0.125
    }

    [Fact]
    public void Commission_is_zero_for_zero_labour_on_labour_only()
    {
        var commission = JobMoney.ComputeCommission(
            100m, 0m, 12.5m, CommissionBase.LabourOnly);
        Assert.Equal(0m, commission);
    }
}
