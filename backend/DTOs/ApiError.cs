namespace FixoApi.DTOs;

/// <summary>
/// Canonical 4xx business-error response body (QA plan §2C).
///
/// Every conflict / bad-request from a business-rule violation returns:
///   { "code": "snake_case_machine_code", "message": "Human-readable text." }
///
/// Mobile clients switch on <see cref="Code"/> to show localised copy or navigate;
/// <see cref="Message"/> is a safe English fallback for logging and unexpected codes.
///
/// Usage: return Conflict(ApiError.From("offer_expired", "This offer has expired."));
/// </summary>
public sealed record ApiError(string Code, string Message)
{
    /// <summary>Factory method for concise inline use in controller returns.</summary>
    public static ApiError From(string code, string message) => new(code, message);
}

/// <summary>
/// Domain exception for 4xx business-rule violations carrying a machine-readable
/// <see cref="Code"/> alongside the human-readable <see cref="Exception.Message"/>.
/// Subclasses <see cref="InvalidOperationException"/> so existing callers/tests
/// catching InvalidOperationException continue to work unchanged.
/// </summary>
public sealed class BusinessRuleException : InvalidOperationException
{
    public string Code { get; }

    public BusinessRuleException(string code, string message) : base(message)
    {
        Code = code;
    }
}
