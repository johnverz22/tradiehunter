using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using FixoApi.Enums;

namespace FixoApi.Models;

/// <summary>
/// Audit trail of every job status transition.
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

    /// <summary>The role of the actor performing the transition.</summary>
    public UserRole ActorRole { get; set; }

    public DateTime ChangedAtUtc { get; set; } = DateTime.UtcNow;

    /// <summary>Structured reason for cancellations or disputes.</summary>
    public ReasonCode? ReasonCode { get; set; }

    /// <summary>Optional cancellation or admin note.</summary>
    [MaxLength(500)]
    public string? Reason { get; set; }
}
