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
    }
}
