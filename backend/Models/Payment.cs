using FixoApi.Enums;
using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace FixoApi.Models;

/// <summary>
/// A manual bank-transfer payment against a job (P4-01).
///
/// Fixo has no payment gateway at this phase, so the homeowner transfers funds
/// out of band and uploads the receipt; staff confirm it from the admin queue
/// (<c>AdminController</c> → <c>GET /api/admin/payments/pending</c>). Exactly one
/// <see cref="Payment"/> exists per job, and it is reused across re-uploads —
/// <see cref="ReUploadCount"/> records how many times staff have sent the
/// homeowner back.
/// </summary>
public class Payment
{
    [Key]
    public int Id { get; set; }

    // ── Job reference ─────────────────────────────────────────────────────────

    public int JobId { get; set; }

    [ForeignKey(nameof(JobId))]
    public Job Job { get; set; } = null!;

    // ── Financials ────────────────────────────────────────────────────────────

    /// <summary>Amount the homeowner must transfer. Never a float (see .agent/rules/backend.md).</summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal Amount { get; set; }

    /// <summary>ISO 4217 code, sourced from the <c>Locale:DefaultCurrency</c> setting.</summary>
    [MaxLength(10)]
    public string Currency { get; set; } = "NZD";

    /// <summary>How the funds move. Fixed to <c>BankTransfer</c> for the manual flow.</summary>
    [MaxLength(50)]
    public string Method { get; set; } = "BankTransfer";

    /// <summary>Name of the <c>IPaymentProvider</c> handling this payment.</summary>
    [MaxLength(50)]
    public string Provider { get; set; } = "Manual";

    /// <summary>
    /// Job-specific code the homeowner quotes on the transfer so staff can match
    /// the bank line to this job. Rendered from <c>PaymentInstructions:ReferenceFormat</c>.
    /// </summary>
    [MaxLength(64)]
    public string ProviderReference { get; set; } = string.Empty;

    // ── Review state ──────────────────────────────────────────────────────────

    /// <summary>Current payment state. Starts as Pending.</summary>
    public PaymentStatus Status { get; set; } = PaymentStatus.Pending;

    // ── Receipt ───────────────────────────────────────────────────────────────

    /// <summary>Blob key of the uploaded receipt in the private payments container.</summary>
    [MaxLength(300)]
    public string? ReceiptFileKey { get; set; }

    /// <summary>
    /// SHA-256 of the receipt bytes. A unique index on this column is what catches
    /// a homeowner re-using one bank confirmation screenshot across jobs (P4-03).
    /// </summary>
    [MaxLength(64)]
    public string? ReceiptHash { get; set; }

    // ── Verification (staff) ──────────────────────────────────────────────────

    /// <summary>Staff/admin who confirmed the receipt. Null until verified.</summary>
    public string? VerifiedBy { get; set; }

    [ForeignKey(nameof(VerifiedBy))]
    public ApplicationUser? VerifiedByUser { get; set; }

    public DateTime? VerifiedAtUtc { get; set; }

    /// <summary>Why staff refused the receipt. Shown to the homeowner so they can re-upload correctly.</summary>
    [MaxLength(500)]
    public string? RejectReason { get; set; }

    /// <summary>Number of times this payment has been rejected and sent back.</summary>
    public int ReUploadCount { get; set; }

    // ── Timestamps ────────────────────────────────────────────────────────────

    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;

    public DateTime UpdatedAtUtc { get; set; } = DateTime.UtcNow;

    /// <summary>When the current receipt entered <see cref="PaymentStatus.Submitted"/>.</summary>
    public DateTime? SubmittedAtUtc { get; set; }
}
