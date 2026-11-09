using FluentValidation;
using FixoApi.DTOs;

namespace FixoApi.Validators;

public class ProfileUpdateValidator : AbstractValidator<ProfileUpdateDto>
{
    public ProfileUpdateValidator()
    {
        RuleFor(x => x.FirstName).NotEmpty();
        RuleFor(x => x.LastName).NotEmpty();
        
        RuleFor(x => x.Latitude)
            .InclusiveBetween(-90, 90)
            .When(x => x.Latitude.HasValue);
            
        RuleFor(x => x.Longitude)
            .InclusiveBetween(-180, 180)
            .When(x => x.Longitude.HasValue);
            
        RuleFor(x => x.Latitude)
            .NotNull()
            .When(x => x.Longitude.HasValue)
            .WithMessage("Latitude is required when Longitude is provided.");
            
        RuleFor(x => x.Longitude)
            .NotNull()
            .When(x => x.Latitude.HasValue)
            .WithMessage("Longitude is required when Latitude is provided.");

        // NZ bank account format — mirrors the onboarding wizard's check.
        RuleFor(x => x.BankAccountNumber)
            .Matches(@"^\d{2}-\d{4}-\d{7}-\d{2,3}$")
            .When(x => !string.IsNullOrEmpty(x.BankAccountNumber))
            .WithMessage("Bank account number must be in format XX-XXXX-XXXXXXX-XX");
    }
}

public class UpdateScheduleRequestValidator : AbstractValidator<UpdateScheduleRequest>
{
    public UpdateScheduleRequestValidator()
    {
        RuleForEach(x => x.Schedule).ChildRules(slot =>
        {
            slot.RuleFor(s => s.Weekday).InclusiveBetween(0, 6);
            slot.RuleFor(s => s.StartTime).LessThan(s => s.EndTime)
                .WithMessage("StartTime must be before EndTime.");
            slot.RuleFor(s => s.EndTime).LessThanOrEqualTo(TimeSpan.FromHours(24));
        });
        RuleFor(x => x.Schedule)
            .Must(s => s.Select(e => e.Weekday).Distinct().Count() == s.Count)
            .WithMessage("Duplicate weekdays are not allowed.");
    }
}

public class UpdateRatesRequestValidator : AbstractValidator<UpdateRatesRequest>
{
    public UpdateRatesRequestValidator()
    {
        RuleForEach(x => x.Rates).ChildRules(rate =>
        {
            rate.RuleFor(r => r.ServiceId).GreaterThan(0);
            rate.RuleFor(r => r.HourlyRate).GreaterThan(0).LessThanOrEqualTo(10000);
        });
        RuleFor(x => x.Rates)
            .Must(r => r.Select(e => e.ServiceId).Distinct().Count() == r.Count)
            .WithMessage("Duplicate services are not allowed.");
    }
}
