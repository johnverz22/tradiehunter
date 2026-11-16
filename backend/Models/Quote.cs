using FixoApi.Enums;
using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace FixoApi.Models;

/// <summary>
/// v1.7 (P12-23): a tradie's structured quote on a project job.
///
/// D8: quote prices are final consumer prices — GST-inclusive when the tradie
/// is registered (<c>TradieProfile.IsGstRegistered</c> forces
/// <see cref="GstIncluded"/> true; unregistered tradies cannot charge GST).
///
/// Accepting one quote declines the others and books the job with the agreed
/// pricing model snapshotted onto the job. Payment still happens at completion.
/// </summary>
public class Quote
{
    [Key]
    public int Id { get; set; }

    public int JobId { get; set; }

    [ForeignKey(nameof(JobId))]
    public Job Job { get; set; } = null!;

    [Required]
    public string TradieId { get; set; } = string.Empty;

    [ForeignKey(nameof(TradieId))]
    public ApplicationUser Tradie { get; set; } = null!;

    /// <summary>How this quote is priced.</summary>
    public QuotePricingModel PricingModel { get; set; } = QuotePricingModel.Fixed;

    /// <summary>
    /// Fixed: the agreed total price. HourlyWithCap: the hourly rate.
    /// Null for EstimateRange (use Min/Max). decimal(18,2), never float.
    /// </summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal? Amount { get; set; }

    /// <summary>EstimateRange lower bound (inclusive).</summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal? MinAmount { get; set; }

    /// <summary>EstimateRange upper bound (inclusive).</summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal? MaxAmount { get; set; }

    /// <summary>HourlyWithCap: the total must not exceed this without an approved adjustment.</summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal? Cap { get; set; }

    /// <summary>What is included in this price (new guttering, cleanup, …).</summary>
    [MaxLength(2000)]
    public string? Inclusions { get; set; }

    /// <summary>What is explicitly NOT included (consents, skip hire, …).</summary>
    [MaxLength(2000)]
    public string? Exclusions { get; set; }

    /// <summary>Whether materials are included in the quoted price.</summary>
    public bool MaterialsIncluded { get; set; }

    /// <summary>
    /// D8: must be true for GST-registered tradies; unregistered tradies cannot
    /// charge GST, so their quotes must carry false. Validated server-side.
    /// </summary>
    public bool GstIncluded { get; set; }

    /// <summary>When the tradie could start. Optional.</summary>
    public DateTimeOffset? ProposedStartUtc { get; set; }

    /// <summary>How many working days the tradie expects the project to take. Optional.</summary>
    public int? EstimatedDurationDays { get; set; }

    /// <summary>After this the quote lapses (window configurable, default 72h).</summary>
    public DateTime ValidUntilUtc { get; set; }

    /// <summary>Lifecycle state. Starts as Submitted.</summary>
    public QuoteStatus Status { get; set; } = QuoteStatus.Submitted;

    /// <summary>The pending QuoteRequest offer that asked for this quote (audit link).</summary>
    public int? OfferId { get; set; }

    [ForeignKey(nameof(OfferId))]
    public JobOffer? Offer { get; set; }

    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime? RespondedAtUtc { get; set; }
}
