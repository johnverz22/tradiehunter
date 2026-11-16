using System.ComponentModel.DataAnnotations;
using FixoApi.Enums;

namespace FixoApi.DTOs;

// ── v1.7 Workstream E: project quotes (P12-23 / P12-24 / P12-25) ──────────────

/// <summary>
/// Body for POST /api/jobs/{id}/quotes — the tradie submits a structured quote
/// for a project job (replaces the one-tap accept, which stays for hourly).
/// </summary>
public class SubmitQuoteRequest
{
    /// <summary>"Fixed" | "EstimateRange" | "HourlyWithCap".</summary>
    [Required]
    public string PricingModel { get; set; } = string.Empty;

    /// <summary>Fixed → required (total price). HourlyWithCap → required (hourly rate).</summary>
    public decimal? Amount { get; set; }

    /// <summary>EstimateRange → required lower bound.</summary>
    public decimal? MinAmount { get; set; }

    /// <summary>EstimateRange → required upper bound.</summary>
    public decimal? MaxAmount { get; set; }

    /// <summary>HourlyWithCap → required total cap.</summary>
    public decimal? Cap { get; set; }

    [MaxLength(2000)]
    public string? Inclusions { get; set; }

    [MaxLength(2000)]
    public string? Exclusions { get; set; }

    public bool MaterialsIncluded { get; set; }

    /// <summary>
    /// D8: required true for GST-registered tradies; unregistered tradies cannot
    /// charge GST (server rejects true when the profile flag is false).
    /// </summary>
    public bool GstIncluded { get; set; }

    public DateTimeOffset? ProposedStartUtc { get; set; }
    public int? EstimatedDurationDays { get; set; }
}

/// <summary>One quote on GET /api/jobs/{id}/quotes (homeowner comparison view).</summary>
public class QuoteDto
{
    public int Id { get; set; }
    public int JobId { get; set; }
    public string TradieId { get; set; } = string.Empty;
    public string TradieName { get; set; } = string.Empty;
    public string? BusinessName { get; set; }
    public string Initials { get; set; } = string.Empty;
    public bool Verified { get; set; }
    public double Rating { get; set; }
    public int ReviewCount { get; set; }

    /// <summary>"Fixed" | "EstimateRange" | "HourlyWithCap".</summary>
    public string PricingModel { get; set; } = string.Empty;
    public decimal? Amount { get; set; }
    public decimal? MinAmount { get; set; }
    public decimal? MaxAmount { get; set; }
    public decimal? Cap { get; set; }
    public string? Inclusions { get; set; }
    public string? Exclusions { get; set; }
    public bool MaterialsIncluded { get; set; }

    /// <summary>D8 label driver: true → "Incl. GST"; false → "No GST charged".</summary>
    public bool GstIncluded { get; set; }

    public DateTimeOffset? ProposedStartUtc { get; set; }
    public int? EstimatedDurationDays { get; set; }
    public DateTime ValidUntilUtc { get; set; }

    /// <summary>"Submitted" | "Accepted" | "Declined" | "Withdrawn" | "Expired".</summary>
    public string Status { get; set; } = string.Empty;
    public DateTime CreatedAtUtc { get; set; }
}

/// <summary>Body for POST /api/jobs/{id}/quotes/{quoteId}/accept.</summary>
public class AcceptQuoteRequest
{
    /// <summary>
    /// P12-25: when the accepted amount is at or above the configured written-
    /// contract threshold, the homeowner must confirm a written contract exists
    /// (or attach one) before the job books. False + over-threshold quote → 409.
    /// </summary>
    public bool ConfirmWrittenContract { get; set; }
}
