using FixoApi.Enums;
using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace FixoApi.Models;

/// <summary>
/// v1.7 (P12-17): an on-demand price change proposed by the tradie during a job
/// (materials bought on the homeowner's behalf, extra work, travel, …).
///
/// NZ guidance (business.govt.nz / Consumer Protection) expects variations to be
/// recorded in writing and agreed BEFORE the extra work is billed — so only
/// <see cref="AdjustmentStatus.Approved"/> adjustments count toward
/// <see cref="Job.AdjustmentsTotal"/> and can ever reach the homeowner's bill.
/// Every proposal/decision is written to the audit log, which is the "in
/// writing" record.
/// </summary>
public class JobPriceAdjustment
{
    [Key]
    public int Id { get; set; }

    public int JobId { get; set; }

    [ForeignKey(nameof(JobId))]
    public Job Job { get; set; } = null!;

    /// <summary>The matched tradie who proposed the adjustment.</summary>
    [Required]
    public string ProposedByTradieId { get; set; } = string.Empty;

    [ForeignKey(nameof(ProposedByTradieId))]
    public ApplicationUser ProposedByTradie { get; set; } = null!;

    /// <summary>What the extra cost is for.</summary>
    public AdjustmentKind Kind { get; set; } = AdjustmentKind.Other;

    /// <summary>Free-text explanation shown to the homeowner (max 500 chars).</summary>
    [Required]
    [MaxLength(500)]
    public string Description { get; set; } = string.Empty;

    /// <summary>Amount requested. Always positive, decimal(18,2) — never float.</summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal Amount { get; set; }

    /// <summary>
    /// Blob key of an attached receipt/photo in the private payments container.
    /// Encouraged (not required) for <see cref="AdjustmentKind.Materials"/> —
    /// never exposed via public URLs.
    /// </summary>
    [MaxLength(300)]
    public string? EvidenceFileKey { get; set; }

    /// <summary>Lifecycle state. Starts as Pending; only Approved counts toward the bill.</summary>
    public AdjustmentStatus Status { get; set; } = AdjustmentStatus.Pending;

    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;

    /// <summary>When the homeowner responded (or the proposal was withdrawn/expired).</summary>
    public DateTime? RespondedAtUtc { get; set; }

    /// <summary>Optional note the homeowner attaches to an Approve/Decline.</summary>
    [MaxLength(500)]
    public string? ResponseNote { get; set; }

    /// <summary>Hangfire job ID for the expiry schedule, cancellable on respond/withdraw.</summary>
    [MaxLength(100)]
    public string? ExpiryJobId { get; set; }

    /// <summary>Hangfire job ID for the 24h reminder (P12-18).</summary>
    [MaxLength(100)]
    public string? ReminderJobId { get; set; }
}
