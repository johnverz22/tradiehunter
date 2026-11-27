using System.ComponentModel.DataAnnotations;

namespace FixoApi.Models;

/// <summary>
/// Persisted in-app alert for a staff/superadmin user (plan 09 N6.1).
/// One row per recipient so each staff member has independent read state.
/// </summary>
public class StaffNotification
{
    [Key]
    public int Id { get; set; }

    [Required]
    [MaxLength(128)]
    public string UserId { get; set; } = string.Empty;

    [Required]
    [MaxLength(64)]
    public string Type { get; set; } = string.Empty;

    [Required]
    [MaxLength(64)]
    public string EntityType { get; set; } = string.Empty;

    [Required]
    [MaxLength(128)]
    public string EntityId { get; set; } = string.Empty;

    [Required]
    [MaxLength(200)]
    public string Title { get; set; } = string.Empty;

    [Required]
    [MaxLength(1000)]
    public string Body { get; set; } = string.Empty;

    [MaxLength(256)]
    public string? AdminPath { get; set; }

    public DateTime CreatedUtc { get; set; } = DateTime.UtcNow;

    public DateTime? ReadUtc { get; set; }
}
