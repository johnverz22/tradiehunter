using FixoApi.DTOs;
using FluentValidation;

namespace FixoApi.Validators;

public class SubmitReviewRequestValidator : AbstractValidator<SubmitReviewRequest>
{
    public SubmitReviewRequestValidator()
    {
        RuleFor(r => r.RevieweeId)
            .NotEmpty().WithMessage("RevieweeId is required.");

        RuleFor(r => r.Rating)
            .InclusiveBetween(1, 5).WithMessage("Rating must be between 1 and 5.");

        RuleFor(r => r.Comment)
            .MaximumLength(1000).WithMessage("Comment must not exceed 1000 characters.")
            .When(r => r.Comment != null);
    }
}

public class ScheduleJobRequestValidator : AbstractValidator<ScheduleJobRequest>
{
    public ScheduleJobRequestValidator()
    {
        RuleFor(r => r.ProposedDateUtc)
            .GreaterThan(DateTime.UtcNow.Date).WithMessage("Scheduled date must be in the future.");

        RuleFor(r => r.TimeSlot)
            .NotEmpty().WithMessage("TimeSlot is required.")
            .Must(slot => slot is "Morning" or "Afternoon" or "Evening")
            .WithMessage("TimeSlot must be Morning, Afternoon, or Evening.");
    }
}
