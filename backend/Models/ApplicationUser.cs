using Microsoft.AspNetCore.Identity;
using FixoApi.Enums;
using System;

namespace FixoApi.Models;

public class ApplicationUser : IdentityUser
{
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    
    public UserRole Role { get; set; }
    
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public bool IsActive { get; set; } = true;

    /// <summary>Display name used in chat bubbles and FCM push copy.</summary>
    public string FullName => $"{FirstName} {LastName}".Trim();
}
