using FluentValidation;
using FixoApi.DTOs;

namespace FixoApi.Validators;

/// <summary>Staff must give the homeowner a reason so they can fix and re-upload (P4-05).</summary>
public class RejectPaymentRequestValidator : AbstractValidator<RejectPaymentRequest>
{
    /// <summary>Matches the ReceiptHash column width and the admin UI's textarea cap.</summary>
    public const int MaxReasonLength = 500;

    public RejectPaymentRequestValidator()
    {
        RuleFor(x => x.Reason)
            .NotEmpty()
            .MaximumLength(MaxReasonLength)
            .WithMessage($"A reason is required when rejecting a payment (max {MaxReasonLength} characters).");
    }
}
