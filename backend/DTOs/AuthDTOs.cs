using FixoApi.Enums;

namespace FixoApi.DTOs;

public class RegisterRequest
{
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public UserRole Role { get; set; }
}

public class LoginRequest
{
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

public class AuthResponse
{
    public string Token { get; set; } = string.Empty;
    public string RefreshToken { get; set; } = string.Empty;
}

public class RefreshRequest
{
    public string RefreshToken { get; set; } = string.Empty;
}

public class GoogleAuthRequest
{
    public string IdToken { get; set; } = string.Empty;
}

public class CompleteRegistrationRequest
{
    public UserRole Role { get; set; }
}
