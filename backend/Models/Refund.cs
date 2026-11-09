using FixoApi.Enums;
using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace FixoApi.Models;

/// <summary>
/// Records the calculation and manual processing of a refund for a cancelled job (P6-01).
///
/// A Refund is created (Status = Pending) whenever a job is cancelled after
/// payment has been collected. Admin staff process it from the Refund Queue
/// (POST /api/admin/refunds/{id}/process), uploading a transfer proof and
/// recording the final amount returned to the homeowner.
/// </summary>
public class Refund
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    // ── Job & Payment reference ───────────────────────────────────────────────

    public int JobId { get; set; }

    [ForeignKey(nameof(JobId))]
    public Job Job { get; set; } = null!;

    /// <summary>The Payment whose collected funds are being refunded.</summary>
    public int? PaymentId { get; set; }

    [ForeignKey(nameof(PaymentId))]
    public Payment? Payment { get; set; }

    // ── Calculated amounts ────────────────────────────────────────────────────

    /// <summary>
    /// Suggested refund amount calculated from the cancellation policy
    /// (total paid minus any applicable penalty).
    /// </summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal SuggestedAmount { get; set; }

    /// <summary>Final refund amount confirmed and entered by admin when processing.</summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal FinalAmount { get; set; }

    /// <summary>Cancellation penalty withheld from the refund.</summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal Penalty { get; set; }

    /// <summary>Hours the tradie had already worked at time of cancellation.</summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal HoursWorked { get; set; }

    /// <summary>Amount payable to the tradie for hours already worked (rate × hours).</summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal HoursWorkedAmount { get; set; }

    // ── Status ────────────────────────────────────────────────────────────────

    public RefundStatus Status { get; set; } = RefundStatus.Pending;

    // ── Processing (admin) ────────────────────────────────────────────────────

    /// <summary>Admin who processed (finalized) this refund. Null until processed.</summary>
    public Guid? ProcessedBy { get; set; }

    /// <summary>Bank transfer reference provided by admin as proof of payment.</summary>
    [MaxLength(200)]
    public string? TransferReference { get; set; }

    /// <summary>Blob key for the proof file (e.g. bank receipt screenshot).</summary>
    [MaxLength(500)]
    public string? ProofFileKey { get; set; }

    // ── Timestamps ────────────────────────────────────────────────────────────

    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;

    public DateTime? ProcessedAtUtc { get; set; }
}
