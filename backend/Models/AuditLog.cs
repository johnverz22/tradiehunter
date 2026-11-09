using System.ComponentModel.DataAnnotations;

namespace FixoApi.Models;

/// <summary>
/// Immutable record of a critical system or admin action (P8-01).
/// Written by <see cref="Services.AuditLogService"/>; never updated in place.
/// </summary>
public class AuditLog
{
    [Key]
    public int Id { get; set; }

    /// <summary>Identity user who performed the action (null for system).</summary>
    [MaxLength(128)]
    public string? UserId { get; set; }

    /// <summary>Machine-readable action, e.g. "credential.review", "refund.process".</summary>
    [Required]
    [MaxLength(128)]
    public string Action { get; set; } = string.Empty;

    /// <summary>Entity the action targeted, e.g. "TradieCredential", "Refund", "Job".</summary>
    [MaxLength(128)]
    public string? EntityType { get; set; }

    /// <summary>Primary key of the targeted entity, as a string (int, Guid, or user id).</summary>
    [MaxLength(128)]
    public string? EntityId { get; set; }

    /// <summary>Snapshot before the action (JSON object, nullable).</summary>
    public string? OldValues { get; set; }

    /// <summary>Snapshot after the action (JSON object, nullable).</summary>
    public string? NewValues { get; set; }

    /// <summary>Caller IP when the action came from HTTP (nullable for jobs/workers).</summary>
    [MaxLength(64)]
    public string? IpAddress { get; set; }

    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}
