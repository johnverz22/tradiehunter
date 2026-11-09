using System;
using System.IO;

namespace FixoApi.DTOs;

// ── Homeowner-facing (P4-04) ─────────────────────────────────────────────────

/// <summary>
/// Everything the homeowner needs to pay a job and see where that payment
/// stands: the amount, the transfer details, the job-specific reference, and the
/// current review state.
/// </summary>
public class PaymentStatusDto
{
    public int PaymentId { get; set; }
    public int JobId { get; set; }
    public string JobTitle { get; set; } = string.Empty;

    /// <summary>The job's status, so the client can render the matching stepper.</summary>
    public string JobStatus { get; set; } = string.Empty;

    public decimal Amount { get; set; }
    public string Currency { get; set; } = string.Empty;
    public string Method { get; set; } = string.Empty;
    public string Provider { get; set; } = string.Empty;

    /// <summary>The code to quote on the transfer — must match <see cref="Amount"/> exactly.</summary>
    public string Reference { get; set; } = string.Empty;

    /// <summary>Payment status: Pending, Submitted, Verified, Rejected or Expired.</summary>
    public string Status { get; set; } = string.Empty;

    /// <summary>Where to send the funds. Null once the payment is Verified.</summary>
    public BankDetailsDto? BankDetails { get; set; }

    /// <summary>Deadline before the job expires and the tradie is released (P4-06).</summary>
    public DateTime DueAtUtc { get; set; }

    public DateTime? SubmittedAtUtc { get; set; }
    public DateTime? VerifiedAtUtc { get; set; }

    /// <summary>Set when staff refused the receipt — shown verbatim to the homeowner.</summary>
    public string? RejectReason { get; set; }

    /// <summary>How many times staff have sent this payment back.</summary>
    public int ReUploadCount { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    /// <summary>True when the client should offer the receipt picker right now.</summary>
    public bool CanUploadReceipt { get; set; }
}

/// <summary>Manual transfer destination, sourced from the <c>PaymentInstructions</c> config.</summary>
public class BankDetailsDto
{
    public string AccountName { get; set; } = string.Empty;
    public string AccountNumber { get; set; } = string.Empty;
}

/// <summary>
/// An uploaded receipt crossing the API boundary.
/// <see cref="IFormFile"/> is an ASP.NET Core type, so the controller unwraps
/// the upload into this transport object and the service layer stays free of
/// web-runtime types (see .agent/rules/backend.md).
/// </summary>
public class ReceiptUpload
{
    public required Stream Content { get; init; }
    public required string FileName { get; init; }
    public required string ContentType { get; init; }
    public required long Length { get; init; }
}

// ── Admin queue (P4-05) ──────────────────────────────────────────────────────

/// <summary>One row in the admin payment queue (P4-05).</summary>
public class PendingPaymentDto
{
    public int Id { get; set; }
    public int JobId { get; set; }
    public string JobTitle { get; set; } = string.Empty;
    public string HomeownerName { get; set; } = string.Empty;
    public string HomeownerEmail { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string Currency { get; set; } = string.Empty;

    /// <summary>Transfer reference to check against the trader's bank statement.</summary>
    public string Reference { get; set; } = string.Empty;

    public string Status { get; set; } = string.Empty;
    public string? Method { get; set; }
    public DateTime? SubmittedAtUtc { get; set; }
    public int ReUploadCount { get; set; }

    // P10-16: SLA indicator
    public int MinutesSinceSubmission { get; set; }

    /// <summary>Short-lived (15 min) SAS URL to view the receipt in the private container.</summary>
    public string ReceiptUrl { get; set; } = string.Empty;
}

/// <summary>Body for <c>POST /api/admin/payments/{id}/reject</c>.</summary>
public class RejectPaymentRequest
{
    /// <summary>Required — surfaced to the homeowner so they can fix and re-upload.</summary>
    public string Reason { get; set; } = string.Empty;
}

/// <summary>Outcome of a staff verify/reject action, mirroring the credential queue.</summary>
public class PaymentActionResult
{
    public bool Succeeded { get; set; }
    public bool NotFound { get; set; }
    public bool Conflict { get; set; }
    public string? Error { get; set; }
    public PaymentStatusDto? Payment { get; set; }
}
