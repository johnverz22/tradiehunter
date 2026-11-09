using Microsoft.AspNetCore.Identity;
using FixoApi.Enums;
using System;
using System.ComponentModel.DataAnnotations;

namespace FixoApi.Models;

public class ApplicationUser : IdentityUser
{
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    
    public UserRole Role { get; set; }
    
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public bool IsActive { get; set; } = true;

    [MaxLength(50)]
    public string AuthProvider { get; set; } = "password";
    
    public bool EmailVerified { get; set; } = false;
    
    public DateTime? EmailVerifiedAtUtc { get; set; }

    public string? RegistrationToken { get; set; }
    public DateTime? RegistrationTokenExpiresAtUtc { get; set; }

    /// <summary>Display name used in chat bubbles and FCM push copy.</summary>
    public string FullName => $"{FirstName} {LastName}".Trim();
}
