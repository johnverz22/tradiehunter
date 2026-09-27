using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using FixoApi.Enums;

namespace FixoApi.Models;

/// <summary>
/// Audit trail of every job status transition (M3-05).
/// Append-only — never update or delete rows.
/// </summary>
public class JobStatusHistory
{
    [Key]
    public int Id { get; set; }

    public int JobId { get; set; }

    [ForeignKey(nameof(JobId))]
    public Job Job { get; set; } = null!;

    public JobStatus FromStatus { get; set; }
    public JobStatus ToStatus { get; set; }

    /// <summary>The user who triggered the transition.</summary>
    [Required]
    public string ChangedByUserId { get; set; } = string.Empty;

    public DateTime ChangedAtUtc { get; set; } = DateTime.UtcNow;

    /// <summary>Optional cancellation or admin note.</summary>
    [MaxLength(500)]
    public string? Reason { get; set; }
}
