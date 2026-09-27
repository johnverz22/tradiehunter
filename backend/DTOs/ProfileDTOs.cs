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
    public bool? IsAvailable { get; set; }
    public string? Address { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public decimal? ServiceRadiusKm { get; set; }
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
}

public class DeviceTokenRequest
{
    public string Token { get; set; } = string.Empty;
    public string Platform { get; set; } = string.Empty;
}
