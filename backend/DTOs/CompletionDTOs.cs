using System.ComponentModel.DataAnnotations;

namespace FixoApi.DTOs;

// ── v1.7 Workstream C: completion summary + approval (P12-11) ─────────────────

/// <summary>
/// Body for POST /api/jobs/{id}/check-out under the v2 flow: the tradie submits
/// the final hours instead of the server assuming them. Server computes
/// LabourAmount / FinalAmount from the request-time rate snapshot plus approved
/// adjustments — money math is server-side only (decimal, never float).
/// </summary>
public class CheckOutRequest
{
    /// <summary>Actual hours worked. 0.25–500, one decimal place is enough.</summary>
    public decimal FinalHours { get; set; }

    /// <summary>Optional completion notes shown to the homeowner.</summary>
    [MaxLength(2000)]
    public string? Notes { get; set; }
}

/// <summary>
/// The itemised summary returned to both sides at check-out and shown to the
/// homeowner for the Approve & pay / Dispute decision.
/// </summary>
public class CompletionSummaryDto
{
    public int JobId { get; set; }
    public decimal FinalHours { get; set; }
    public decimal HourlyRate { get; set; }
    public decimal LabourAmount { get; set; }

    /// <summary>Σ approved adjustments included in the total.</summary>
    public decimal AdjustmentsTotal { get; set; }

    /// <summary>LabourAmount + AdjustmentsTotal — what the homeowner pays.</summary>
    public decimal FinalAmount { get; set; }

    /// <summary>The homeowner's original estimate; null when they skipped hours.</summary>
    public decimal? EstimatedTotal { get; set; }

    /// <summary>
    /// P12-11: true when FinalAmount exceeds EstimatedTotal by more than the
    /// configured tolerance — the client must show the "higher than estimate"
    /// banner. Also true when there was no estimate and the amount exceeds the
    /// configured no-estimate cap.
    /// </summary>
    public bool ExceedsTolerance { get; set; }

    /// <summary>Human-readable reason for the banner, e.g. "15% above the $300 estimate".</summary>
    public string? ToleranceNote { get; set; }

    public DateTime CompletionSubmittedAtUtc { get; set; }
}

/// <summary>Body for POST /api/jobs/{id}/approve (P12-11) — homeowner accepts the final amount.</summary>
public class ApproveCompletionRequest
{
    /// <summary>Optional note recorded with the approval.</summary>
    [MaxLength(500)]
    public string? Note { get; set; }
}
