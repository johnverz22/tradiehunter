using FixoApi.Enums;

namespace FixoApi.DTOs;

public class ProfileDto
{
    public string Id { get; set; } = string.Empty;
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string? Email { get; set; }
    public string? PhoneNumber { get; set; }
    public UserRole Role { get; set; }

    // ── Aggregated review stats (M4-03) ───────────────────────────────────
    /// <summary>Average rating received as reviewee. 0 if no reviews yet.</summary>
    public decimal AverageRating { get; set; }
    /// <summary>Total reviews received as reviewee.</summary>
    public int ReviewCount { get; set; }
    
    // Tradie specific
    public string? TradeType { get; set; }
    public string? BusinessName { get; set; }
    public bool? IsVerified { get; set; }
    public bool? HasInsurance { get; set; }
    public bool? IsAvailable { get; set; }
    public string? Address { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public decimal? ServiceRadiusKm { get; set; }

    // ── Payout details — owner-only, never serialized on the public view ──
    public string? BankAccountName { get; set; }
    /// <summary>Full account number, owner-only. The public view leaves this null.</summary>
    public string? BankAccountNumber { get; set; }
    /// <summary>Staff-verified flag; resets when the owner changes the number.</summary>
    public bool? BankAccountVerified { get; set; }
}

public class ProfileUpdateDto
{
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string? PhoneNumber { get; set; }
    
    // Tradie specific
    public string? TradeType { get; set; }
    public string? BusinessName { get; set; }
    public bool? IsAvailable { get; set; }
    public string? Address { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public decimal? ServiceRadiusKm { get; set; }

    // Tradie payout details (owner-editable). BankAccountVerified is not
    // settable here — changing the number clears it server-side.
    public string? BankAccountName { get; set; }
    public string? BankAccountNumber { get; set; }
}

public class DeviceTokenRequest
{
    public string Token { get; set; } = string.Empty;
    public string Platform { get; set; } = string.Empty;
}

// ── Tradie onboarding (P1-06) ───────────────────────────────────────────────

public class TradieScheduleDto
{
    /// <summary>0 = Sunday … 6 = Saturday.</summary>
    public int Weekday { get; set; }
    public TimeSpan StartTime { get; set; }
    public TimeSpan EndTime { get; set; }
}

public class UpdateScheduleRequest
{
    /// <summary>Full replacement set for the tradie's weekly schedule.</summary>
    public List<TradieScheduleDto> Schedule { get; set; } = new();
}

public class TradieRateDto
{
    public int ServiceId { get; set; }
    public string ServiceName { get; set; } = string.Empty;

    /// <summary>Hourly rate in the configured currency. Decimal, never float.</summary>
    public decimal HourlyRate { get; set; }
}

public class RateInputDto
{
    public int ServiceId { get; set; }
    public decimal HourlyRate { get; set; }
}

public class UpdateRatesRequest
{
    /// <summary>Full replacement set for the tradie's per-service rates.</summary>
    public List<RateInputDto> Rates { get; set; } = new();
}

public class ServiceCatalogDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
}

public class TradieCredentialDto
{
    public int Id { get; set; }
    public string Type { get; set; } = string.Empty;
    public string OriginalFileName { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public string? RejectReason { get; set; }
    public DateTime? ReviewedAtUtc { get; set; }

    /// <summary>Short-lived read URL so the owner can preview the upload.</summary>
    public string? DownloadUrl { get; set; }
}

public class CredentialUploadResult
{
    public TradieCredentialDto? Credential { get; set; }
    /// <summary>One of: NotTradie, InvalidType, InvalidFile.</summary>
    public string? Error { get; set; }
    public bool Succeeded => Credential is not null;
}
