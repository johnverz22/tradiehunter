using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using FixoApi.Models;
using Microsoft.IdentityModel.Tokens;

namespace FixoApi.Services;

public class TokenService
{
    // P9-06: Refresh tokens expire after 30 days.
    public static readonly TimeSpan RefreshTokenLifetime = TimeSpan.FromDays(30);

    private readonly IConfiguration _config;

    public TokenService(IConfiguration config)
    {
        _config = config;
    }

    public string CreateToken(ApplicationUser user)
    {
        var claims = new List<Claim>
        {
            new Claim(JwtRegisteredClaimNames.Sub, user.Id),
            new Claim(JwtRegisteredClaimNames.Email, user.Email!),
            new Claim(ClaimTypes.Role, user.Role.ToString()),
            new Claim(ClaimTypes.Name, $"{user.FirstName} {user.LastName}")
        };

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_config["Jwt:Secret"]!));
        // P9-13: use the JWT short-name constant ("HS256") — this is what the library
        // writes into the JWT "alg" header and what ValidAlgorithms in Program.cs pins to.
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Expires = DateTime.UtcNow.AddMinutes(double.Parse(_config["Jwt:ExpiryMinutes"]!)),
            SigningCredentials = creds,
            Issuer = _config["Jwt:Issuer"],
            Audience = _config["Jwt:Audience"]
        };

        var tokenHandler = new JwtSecurityTokenHandler();
        var token = tokenHandler.CreateToken(tokenDescriptor);

        return tokenHandler.WriteToken(token);
    }

    /// <summary>
    /// P9-06: Generates a 96-byte cryptographically random refresh token
    /// (base64url-encoded) and returns it alongside its SHA-256 hash (hex)
    /// for DB storage. Only the hash is persisted; the plaintext is returned
    /// to the client once and never stored.
    /// </summary>
    public static (string plaintext, string hash) GenerateRefreshToken()
    {
        var bytes = RandomNumberGenerator.GetBytes(96);
        var plaintext = Convert.ToBase64String(bytes)
            .Replace('+', '-').Replace('/', '_').TrimEnd('='); // base64url safe
        return (plaintext, HashToken(plaintext));
    }

    /// <summary>SHA-256 hex hash of a token string.</summary>
    public static string HashToken(string token)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(token));
        return Convert.ToHexString(bytes);
    }
}
