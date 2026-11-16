using FixoApi.DTOs;
using FixoApi.Validators;
using FluentValidation.TestHelper;
using Xunit;

namespace FixoApi.Tests;

/// <summary>
/// P12-02 / P12-28: the create-job contract — timing optional but consistent,
/// rate ignored, project fields validated. Pure FluentValidation tests.
/// </summary>
public class JobValidatorTests
{
    private readonly CreateJobRequestValidator _validator = new();

    private static CreateJobRequest ValidRequest() => new()
    {
        Title = "Fix a dripping tap",
        Description = "Kitchen mixer tap drips constantly.",
        ServiceId = 1,
        TimingPreference = "Flexible",
    };

    [Fact]
    public void Flexible_timing_needs_no_dates()
    {
        var request = ValidRequest();
        _validator.TestValidate(request).ShouldNotHaveAnyValidationErrors();
    }

    [Fact]
    public void Minimal_post_is_valid_without_rate_hours_or_dates()
    {
        // The headline P12-02 acceptance: a job can be posted with no rate,
        // no hours and no schedule.
        var request = ValidRequest();
        request.EstimatedHours = null;
        request.HourlyRate = 0m; // legacy wire field, ignored
        _validator.TestValidate(request).ShouldNotHaveAnyValidationErrors();
    }

    [Fact]
    public void Specific_date_requires_a_future_start()
    {
        var request = ValidRequest();
        request.TimingPreference = "SpecificDate";
        _validator.TestValidate(request).ShouldHaveValidationErrorFor(x => x.ScheduledStartUtc);

        request.ScheduledStartUtc = DateTimeOffset.UtcNow.AddDays(2);
        _validator.TestValidate(request).ShouldNotHaveValidationErrorFor(x => x.ScheduledStartUtc);
    }

    [Fact]
    public void Flexible_must_not_carry_dates()
    {
        var request = ValidRequest();
        request.ScheduledStartUtc = DateTimeOffset.UtcNow.AddDays(2);
        _validator.TestValidate(request).ShouldHaveValidationErrorFor(x => x.ScheduledStartUtc);
    }

    [Fact]
    public void Date_range_requires_start_and_end_in_order()
    {
        var request = ValidRequest();
        request.TimingPreference = "DateRange";
        request.ScheduledStartUtc = DateTimeOffset.UtcNow.AddDays(2);
        // End missing → invalid.
        _validator.TestValidate(request).ShouldHaveValidationErrorFor(x => x.ScheduledEndUtc);

        request.ScheduledEndUtc = DateTimeOffset.UtcNow.AddDays(1);
        // End before start → invalid.
        _validator.TestValidate(request).ShouldHaveValidationErrorFor(x => x.ScheduledEndUtc);

        request.ScheduledEndUtc = DateTimeOffset.UtcNow.AddDays(3);
        _validator.TestValidate(request).ShouldNotHaveValidationErrorFor(x => x.ScheduledEndUtc);
    }

    [Fact]
    public void Past_start_is_rejected()
    {
        var request = ValidRequest();
        request.TimingPreference = "SpecificDate";
        request.ScheduledStartUtc = DateTimeOffset.UtcNow.AddDays(-1);
        _validator.TestValidate(request).ShouldHaveValidationErrorFor(x => x.ScheduledStartUtc);
    }

    [Fact]
    public void Estimated_hours_must_be_plausible_when_given()
    {
        var request = ValidRequest();
        request.EstimatedHours = 0;
        _validator.TestValidate(request).ShouldHaveValidationErrorFor(x => x.EstimatedHours);

        request.EstimatedHours = 6;
        _validator.TestValidate(request).ShouldNotHaveValidationErrorFor(x => x.EstimatedHours);
    }

    [Fact]
    public void Project_budget_range_must_be_ordered()
    {
        var request = ValidRequest();
        request.JobType = "Project";
        request.BudgetMin = 500m;
        request.BudgetMax = 200m;
        _validator.TestValidate(request).ShouldHaveValidationErrorFor(x => x.BudgetMax);

        request.BudgetMax = 2000m;
        _validator.TestValidate(request).ShouldNotHaveAnyValidationErrors();
    }

    [Fact]
    public void Invalid_timing_name_is_rejected()
    {
        var request = ValidRequest();
        request.TimingPreference = "Whenever";
        _validator.TestValidate(request).ShouldHaveValidationErrorFor(x => x.TimingPreference);
    }
}

/// <summary>
/// P12-17 / P12-23 / P12-28: adjustment and quote request validators.
/// </summary>
public class AdjustmentAndQuoteValidatorTests
{
    private readonly CreateAdjustmentRequestValidator _adjustmentValidator = new();
    private readonly SubmitQuoteRequestValidator _quoteValidator = new();

    [Fact]
    public void Adjustment_amount_must_be_positive()
    {
        var request = new CreateAdjustmentRequest
        {
            Kind = "Materials",
            Description = "Replacing the mixer cartridge",
            Amount = 0m,
        };
        _adjustmentValidator.TestValidate(request).ShouldHaveValidationErrorFor(x => x.Amount);

        request.Amount = 42.50m;
        _adjustmentValidator.TestValidate(request).ShouldNotHaveValidationErrorFor(x => x.Amount);
    }

    [Fact]
    public void Adjustment_requires_a_known_kind_and_description()
    {
        var request = new CreateAdjustmentRequest
        {
            Kind = "Discount",
            Description = "",
            Amount = 10m,
        };
        var result = _adjustmentValidator.TestValidate(request);
        result.ShouldHaveValidationErrorFor(x => x.Kind);
        result.ShouldHaveValidationErrorFor(x => x.Description);
    }

    [Fact]
    public void Fixed_quote_requires_amount()
    {
        var request = new SubmitQuoteRequest
        {
            PricingModel = "Fixed",
            GstIncluded = true,
        };
        _quoteValidator.TestValidate(request).ShouldHaveValidationErrorFor(x => x.Amount);

        request.Amount = 4500m;
        _quoteValidator.TestValidate(request).ShouldNotHaveValidationErrorFor(x => x.Amount);
    }

    [Fact]
    public void Estimate_range_requires_min_and_max_in_order()
    {
        var request = new SubmitQuoteRequest
        {
            PricingModel = "EstimateRange",
            MinAmount = 1000m,
            MaxAmount = 500m,
            GstIncluded = true,
        };
        _quoteValidator.TestValidate(request).ShouldHaveValidationErrorFor(x => x.MaxAmount);

        request.MaxAmount = 1500m;
        _quoteValidator.TestValidate(request).ShouldNotHaveAnyValidationErrors();
    }

    [Fact]
    public void Hourly_with_cap_requires_rate_and_cap()
    {
        var request = new SubmitQuoteRequest
        {
            PricingModel = "HourlyWithCap",
            GstIncluded = true,
        };
        _quoteValidator.TestValidate(request).ShouldHaveValidationErrorFor(x => x.Amount);

        request.Amount = 65m;
        _quoteValidator.TestValidate(request).ShouldHaveValidationErrorFor(x => x.Cap);

        request.Cap = 2000m;
        _quoteValidator.TestValidate(request).ShouldNotHaveAnyValidationErrors();
    }
}
