using System.ComponentModel.DataAnnotations;
using FixoApi.Enums;

namespace FixoApi.DTOs;

// ── v1.7 Workstream D: on-demand price adjustments (P12-17) ───────────────────

/// <summary>Body for POST /api/jobs/{id}/adjustments (tradie proposes an extra cost).</summary>
public class CreateAdjustmentRequest
{
    /// <summary>"Materials" | "ExtraLabour" | "Travel" | "Other".</summary>
    [Required]
    public string Kind { get; set; } = string.Empty;

    /// <summary>What the money is for — shown to the homeowner. Max 500 chars.</summary>
    [Required]
    [MaxLength(500)]
    public string Description { get; set; } = string.Empty;

    /// <summary>Strictly positive, decimal(18,2).</summary>
    public decimal Amount { get; set; }

    /// <summary>
    /// Blob key of an uploaded receipt/photo. Evidence upload goes through the
    /// standard blob upload endpoint first; encouraged for Materials.
    /// </summary>
    [MaxLength(300)]
    public string? EvidenceFileKey { get; set; }
}

/// <summary>Body for POST /api/jobs/{id}/adjustments/{adjId}/respond (homeowner decides).</summary>
public class RespondAdjustmentRequest
{
    /// <summary>true = approve (counts toward the bill), false = decline.</summary>
    public bool Approve { get; set; }

    /// <summary>Optional note recorded with the decision ("in writing" record).</summary>
    [MaxLength(500)]
    public string? Note { get; set; }
}

/// <summary>One row of GET /api/jobs/{id}/adjustments.</summary>
public class AdjustmentDto
{
    public int Id { get; set; }
    public int JobId { get; set; }
    public string ProposedByTradieId { get; set; } = string.Empty;
    public string? ProposedByTradieName { get; set; }

    /// <summary>"Materials" | "ExtraLabour" | "Travel" | "Other".</summary>
    public string Kind { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public decimal Amount { get; set; }

    /// <summary>Read URL for the evidence document (short-lived, private container); null when none.</summary>
    public string? EvidenceUrl { get; set; }

    /// <summary>"Pending" | "Approved" | "Declined" | "Withdrawn" | "Expired".</summary>
    public string Status { get; set; } = string.Empty;
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? RespondedAtUtc { get; set; }
    public string? ResponseNote { get; set; }

    /// <summary>When a Pending adjustment will expire (P12-18); null when decided.</summary>
    public DateTime? ExpiresAtUtc { get; set; }
}
