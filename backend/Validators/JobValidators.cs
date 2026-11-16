using FluentValidation;
using FixoApi.DTOs;
using FixoApi.Enums;

namespace FixoApi.Validators;

public class CreateJobRequestValidator : AbstractValidator<CreateJobRequest>
{
    private static readonly string[] ValidCategories =
        Enum.GetNames<TradeCategory>();

    private static readonly string[] ValidUrgencies =
        Enum.GetNames<JobUrgency>();

    private static readonly string[] ValidTimingPreferences =
        Enum.GetNames<TimingPreference>();

    private static readonly string[] ValidJobTypes =
        Enum.GetNames<JobType>();

    private static readonly string[] ValidMaterialsBy =
        Enum.GetNames<MaterialsResponsibility>();

    public CreateJobRequestValidator()
    {
        RuleFor(x => x.Title)
            .NotEmpty().WithMessage("Title is required.")
            .MaximumLength(200);

        RuleFor(x => x.Description)
            .NotEmpty().WithMessage("Description is required.")
            .MaximumLength(2000);

        RuleFor(x => x.ServiceId).GreaterThan(0);

        // v1.7 (P12-02): timing is optional. SpecificDate/DateRange must carry a
        // future start; Flexible/Asap must NOT carry dates.
        RuleFor(x => x.TimingPreference)
            .Must(t => string.IsNullOrEmpty(t) ||
                       ValidTimingPreferences.Contains(t, StringComparer.OrdinalIgnoreCase))
            .WithMessage($"TimingPreference must be one of: {string.Join(", ", ValidTimingPreferences)}.");

        RuleFor(x => x)
            .Must(x => ParseTiming(x.TimingPreference) is TimingPreference.SpecificDate or TimingPreference.DateRange
                ? x.ScheduledStartUtc.HasValue
                : !x.ScheduledStartUtc.HasValue)
            .WithMessage("SpecificDate and DateRange require a start date; Flexible and Asap must not have one.");

        RuleFor(x => x)
            .Must(x => ParseTiming(x.TimingPreference) is TimingPreference.DateRange
                ? x.ScheduledEndUtc.HasValue
                : !x.ScheduledEndUtc.HasValue)
            .WithMessage("DateRange requires an end date; other timings must not have one.");

        RuleFor(x => x.ScheduledStartUtc)
            .Must(x => !x.HasValue || x.Value.Offset == TimeSpan.Zero)
            .WithMessage("Scheduled start must be supplied in UTC.");

        RuleFor(x => x.ScheduledEndUtc)
            .Must(x => !x.HasValue || x.Value.Offset == TimeSpan.Zero)
            .WithMessage("Scheduled end must be supplied in UTC.");

        RuleFor(x => x)
            .Must(x => !x.ScheduledStartUtc.HasValue || x.ScheduledStartUtc.Value.UtcDateTime > DateTime.UtcNow)
            .WithMessage("Scheduled start must be in the future.")
            .Must(x => !x.ScheduledStartUtc.HasValue || !x.ScheduledEndUtc.HasValue
                || x.ScheduledEndUtc.Value.UtcDateTime > x.ScheduledStartUtc.Value.UtcDateTime)
            .WithMessage("Scheduled end must be after the scheduled start.");

        // v1.7 (P12-02): the homeowner's guess is optional, but if given it must
        // be plausible. HourlyRate is intentionally NOT validated — it is ignored.
        RuleFor(x => x.EstimatedHours)
            .InclusiveBetween(1, 500)
            .When(x => x.EstimatedHours.HasValue);

        RuleFor(x => x.Urgency)
            .Must(u => string.IsNullOrEmpty(u) ||
                       ValidUrgencies.Contains(u, StringComparer.OrdinalIgnoreCase))
            .WithMessage($"Urgency must be one of: {string.Join(", ", ValidUrgencies)}.");

        // v1.7 (P12-21): job type + project-only fields.
        RuleFor(x => x.JobType)
            .Must(t => string.IsNullOrEmpty(t) ||
                       ValidJobTypes.Contains(t, StringComparer.OrdinalIgnoreCase))
            .WithMessage($"JobType must be one of: {string.Join(", ", ValidJobTypes)}.");

        RuleFor(x => x.MaterialsBy)
            .Must(m => string.IsNullOrEmpty(m) ||
                       ValidMaterialsBy.Contains(m, StringComparer.OrdinalIgnoreCase))
            .WithMessage($"MaterialsBy must be one of: {string.Join(", ", ValidMaterialsBy)}.");

        RuleFor(x => x.BudgetMin)
            .GreaterThan(0).When(x => x.BudgetMin.HasValue);
        RuleFor(x => x.BudgetMax)
            .GreaterThan(0).When(x => x.BudgetMax.HasValue);

        RuleFor(x => x)
            .Must(x => !x.BudgetMin.HasValue || !x.BudgetMax.HasValue || x.BudgetMax >= x.BudgetMin)
            .WithMessage("BudgetMax must be greater than or equal to BudgetMin.");

        RuleFor(x => x.ScopeNotes)
            .MaximumLength(5000).When(x => x.ScopeNotes != null);

        When(x => x.Latitude.HasValue || x.Longitude.HasValue, () =>
        {
            RuleFor(x => x.Latitude)
                .NotNull().InclusiveBetween(-90, 90);
            RuleFor(x => x.Longitude)
                .NotNull().InclusiveBetween(-180, 180);
        });
    }

    private static TimingPreference ParseTiming(string? raw) =>
        Enum.TryParse<TimingPreference>(raw, ignoreCase: true, out var parsed)
            ? parsed
            : TimingPreference.Flexible;
}

public class UpdateJobRequestValidator : AbstractValidator<UpdateJobRequest>
{
    private static readonly string[] ValidUrgencies = Enum.GetNames<JobUrgency>();

    public UpdateJobRequestValidator()
    {
        RuleFor(x => x.Title).MaximumLength(200).When(x => x.Title != null);
        RuleFor(x => x.Description).MaximumLength(2000).When(x => x.Description != null);

        RuleFor(x => x.Urgency)
            .Must(u => u == null || ValidUrgencies.Contains(u, StringComparer.OrdinalIgnoreCase))
            .WithMessage($"Urgency must be one of: {string.Join(", ", ValidUrgencies)}.");

        RuleFor(x => x.EstimatedHours)
            .InclusiveBetween(1, 500)
            .When(x => x.EstimatedHours.HasValue);

        RuleFor(x => x.ScheduledStartUtc)
            .Must(x => !x.HasValue || x.Value.Offset == TimeSpan.Zero)
            .WithMessage("Scheduled start must be supplied in UTC.");
        RuleFor(x => x.ScheduledEndUtc)
            .Must(x => !x.HasValue || x.Value.Offset == TimeSpan.Zero)
            .WithMessage("Scheduled end must be supplied in UTC.");

        When(x => x.Latitude.HasValue || x.Longitude.HasValue, () =>
        {
            RuleFor(x => x.Latitude).NotNull().InclusiveBetween(-90, 90);
            RuleFor(x => x.Longitude).NotNull().InclusiveBetween(-180, 180);
        });
    }
}

// ── v1.7 validators (P12-17 adjustments, P12-23 quotes) ───────────────────────

public class CreateAdjustmentRequestValidator : AbstractValidator<CreateAdjustmentRequest>
{
    private static readonly string[] ValidKinds = Enum.GetNames<AdjustmentKind>();

    public CreateAdjustmentRequestValidator()
    {
        RuleFor(x => x.Kind)
            .NotEmpty()
            .Must(k => ValidKinds.Contains(k, StringComparer.OrdinalIgnoreCase))
            .WithMessage($"Kind must be one of: {string.Join(", ", ValidKinds)}.");

        RuleFor(x => x.Description)
            .NotEmpty().WithMessage("Description is required.")
            .MaximumLength(500);

        RuleFor(x => x.Amount)
            .GreaterThan(0).WithMessage("Amount must be greater than 0.")
            .LessThanOrEqualTo(100000m).WithMessage("Amount must be 100,000 or less.");

        RuleFor(x => x.EvidenceFileKey)
            .MaximumLength(300).When(x => x.EvidenceFileKey != null);
    }
}

public class SubmitQuoteRequestValidator : AbstractValidator<SubmitQuoteRequest>
{
    private static readonly string[] ValidPricingModels = Enum.GetNames<QuotePricingModel>();

    public SubmitQuoteRequestValidator()
    {
        RuleFor(x => x.PricingModel)
            .NotEmpty()
            .Must(m => ValidPricingModels.Contains(m, StringComparer.OrdinalIgnoreCase))
            .WithMessage($"PricingModel must be one of: {string.Join(", ", ValidPricingModels)}.");

        // Fixed: one agreed total.
        RuleFor(x => x.Amount)
            .NotNull().GreaterThan(0)
            .When(x => Matches(x.PricingModel, QuotePricingModel.Fixed))
            .WithMessage("Fixed quotes require Amount.");

        // EstimateRange: min + max, ordered.
        RuleFor(x => x.MinAmount)
            .NotNull().GreaterThan(0)
            .When(x => Matches(x.PricingModel, QuotePricingModel.EstimateRange))
            .WithMessage("EstimateRange quotes require MinAmount.");
        RuleFor(x => x.MaxAmount)
            .NotNull().GreaterThan(0)
            .When(x => Matches(x.PricingModel, QuotePricingModel.EstimateRange))
            .WithMessage("EstimateRange quotes require MaxAmount.");
        RuleFor(x => x)
            .Must(x => !x.MinAmount.HasValue || !x.MaxAmount.HasValue || x.MaxAmount >= x.MinAmount)
            .WithMessage("MaxAmount must be greater than or equal to MinAmount.")
            .When(x => Matches(x.PricingModel, QuotePricingModel.EstimateRange));

        // HourlyWithCap: hourly rate + total cap.
        RuleFor(x => x.Amount)
            .NotNull().GreaterThan(0)
            .When(x => Matches(x.PricingModel, QuotePricingModel.HourlyWithCap))
            .WithMessage("HourlyWithCap quotes require the hourly rate in Amount.");
        RuleFor(x => x.Cap)
            .NotNull().GreaterThan(0)
            .When(x => Matches(x.PricingModel, QuotePricingModel.HourlyWithCap))
            .WithMessage("HourlyWithCap quotes require Cap.");

        RuleFor(x => x.Inclusions).MaximumLength(2000).When(x => x.Inclusions != null);
        RuleFor(x => x.Exclusions).MaximumLength(2000).When(x => x.Exclusions != null);
        RuleFor(x => x.EstimatedDurationDays)
            .InclusiveBetween(1, 3650)
            .When(x => x.EstimatedDurationDays.HasValue);
    }

    private static bool Matches(string? raw, QuotePricingModel model) =>
        Enum.TryParse<QuotePricingModel>(raw, ignoreCase: true, out var parsed) && parsed == model;
}
