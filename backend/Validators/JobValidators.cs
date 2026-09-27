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

    public CreateJobRequestValidator()
    {
        RuleFor(x => x.Title)
            .NotEmpty().WithMessage("Title is required.")
            .MaximumLength(200);

        RuleFor(x => x.Description)
            .NotEmpty().WithMessage("Description is required.")
            .MaximumLength(2000);

        RuleFor(x => x.Category)
            .NotEmpty()
            .Must(c => ValidCategories.Contains(c, StringComparer.OrdinalIgnoreCase))
            .WithMessage($"Category must be one of: {string.Join(", ", ValidCategories)}.");

        RuleFor(x => x.Urgency)
            .Must(u => string.IsNullOrEmpty(u) ||
                       ValidUrgencies.Contains(u, StringComparer.OrdinalIgnoreCase))
            .WithMessage($"Urgency must be one of: {string.Join(", ", ValidUrgencies)}.");

        When(x => x.Latitude.HasValue || x.Longitude.HasValue, () =>
        {
            RuleFor(x => x.Latitude)
                .NotNull().InclusiveBetween(-90, 90);
            RuleFor(x => x.Longitude)
                .NotNull().InclusiveBetween(-180, 180);
        });
    }
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

        When(x => x.Latitude.HasValue || x.Longitude.HasValue, () =>
        {
            RuleFor(x => x.Latitude).NotNull().InclusiveBetween(-90, 90);
            RuleFor(x => x.Longitude).NotNull().InclusiveBetween(-180, 180);
        });
    }
}
