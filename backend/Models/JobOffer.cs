using FixoApi.Enums;
using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace FixoApi.Models;

/// <summary>
/// Records a single offer sent to a tradie as part of sequential matching (P3-01).
/// One offer is active at a time per job; after a response (or timeout) the next
/// ranked tradie receives their offer.
/// </summary>
public class JobOffer
{
    [Key]
    public int Id { get; set; }

    // ── Job reference ─────────────────────────────────────────────────────────

    public int JobId { get; set; }

    [ForeignKey(nameof(JobId))]
    public Job Job { get; set; } = null!;

    // ── Tradie reference ──────────────────────────────────────────────────────

    [Required]
    public string TradieId { get; set; } = string.Empty;

    [ForeignKey(nameof(TradieId))]
    public ApplicationUser Tradie { get; set; } = null!;

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    /// <summary>UTC timestamp when this offer was sent.</summary>
    public DateTime OfferedAtUtc { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// UTC deadline for the tradie to respond. The Hangfire timeout job fires
    /// at or just after this time.
    /// </summary>
    public DateTime ExpiresAtUtc { get; set; }

    /// <summary>Current response state. Starts as Pending.</summary>
    public OfferResponse Response { get; set; } = OfferResponse.Pending;

    /// <summary>Matching stage at the time this offer was created.</summary>
    public OfferStage Stage { get; set; } = OfferStage.Auto;

    // ── v1.7 (P12-01 / P12-08 / P12-23) ──────────────────────────────────────

    /// <summary>
    /// v1.7 (P12-08): the tradie's hourly rate for the job's service, copied at
    /// request time. On accept the value is copied to <see cref="Job.HourlyRate"/>
    /// so the rate the homeowner saw is the rate the job bills at.
    /// </summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal HourlyRateSnapshot { get; set; }

    /// <summary>
    /// v1.7 (P12-08/D3): the homeowner's optional one-way message with the
    /// request. The ONLY pre-acceptance contact channel — chat stays gated to
    /// Booked and later (P5-08 unchanged).
    /// </summary>
    [MaxLength(1000)]
    public string? Message { get; set; }

    /// <summary>v1.7 (P12-23): Instant = hourly accept/decline; QuoteRequest = asks the tradie to submit a quote.</summary>
    public OfferKind Kind { get; set; } = OfferKind.Instant;

    // ── Hangfire integration ──────────────────────────────────────────────────

    /// <summary>
    /// The Hangfire background job ID for the timeout handler, stored so we
    /// can cancel it if the tradie responds before <see cref="ExpiresAtUtc"/>.
    /// </summary>
    [MaxLength(100)]
    public string? HangfireJobId { get; set; }
}
