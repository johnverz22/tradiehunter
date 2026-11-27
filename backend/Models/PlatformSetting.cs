using System.ComponentModel.DataAnnotations;

namespace FixoApi.Models;

/// <summary>
/// Plan 10 (Q7.1): one admin-editable platform setting, stored as a string
/// keyed by a dotted name (e.g. <c>Quotes.BoardWindowHours</c>). A missing
/// row means "use the appsettings default", so nothing needs seeding.
/// </summary>
public class PlatformSetting
{
    [Key]
    [MaxLength(100)]
    public string Key { get; set; } = string.Empty;

    [Required]
    [MaxLength(1000)]
    public string Value { get; set; } = string.Empty;

    public DateTime UpdatedAtUtc { get; set; } = DateTime.UtcNow;

    [MaxLength(128)]
    public string? UpdatedByUserId { get; set; }
}
