using FluentValidation;
using FixoApi.DTOs;
using FixoApi.Enums;

namespace FixoApi.Validators;

public class ReviewCredentialRequestValidator : AbstractValidator<ReviewCredentialRequest>
{
    public ReviewCredentialRequestValidator()
    {
        RuleFor(x => x.Status)
            .NotEmpty()
            .Must(s => Enum.TryParse<CredentialStatus>(s, true, out var parsed)
                       && parsed != CredentialStatus.Pending)
            .WithMessage("Status must be Approved or Rejected.");

        RuleFor(x => x.RejectReason)
            .NotEmpty()
            .MaximumLength(500)
            .When(x => string.Equals(x.Status, nameof(CredentialStatus.Rejected),
                StringComparison.OrdinalIgnoreCase))
            .WithMessage("RejectReason is required when rejecting a credential.");
    }
}
