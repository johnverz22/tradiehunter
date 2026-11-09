using FixoApi.Enums;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace FixoApi.Models;

/// <summary>
/// A dispute opened against a job. One dispute per job. Drives the admin
/// review queue and, when resolved with a refund, the refund flow.
/// </summary>
public class Dispute
{
    [Key]
    public int Id { get; set; }

    public int JobId { get; set; }

    [ForeignKey(nameof(JobId))]
    public Job Job { get; set; } = null!;

    [Required]
    [MaxLength(128)]
    public string OpenedBy { get; set; } = string.Empty;

    public DateTime OpenedAtUtc { get; set; } = DateTime.UtcNow;

    public DisputeStatus Status { get; set; } = DisputeStatus.Open;

    public DisputeOutcome Outcome { get; set; } = DisputeOutcome.Null;

    [MaxLength(128)]
    public string? DecidedBy { get; set; }

    public DateTime? DecidedAtUtc { get; set; }

    [MaxLength(2000)]
    public string? DecisionNote { get; set; }

    [MaxLength(2000)]
    public string? OpenReason { get; set; }

    public DateTime? ResolvedAtUtc { get; set; }

    // ── Navigation ───────────────────────────────────────────────────────────

    public ICollection<DisputeEvidence> Evidence { get; set; } = new List<DisputeEvidence>();
}