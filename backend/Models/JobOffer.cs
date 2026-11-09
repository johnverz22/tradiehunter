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

    // ── Hangfire integration ──────────────────────────────────────────────────

    /// <summary>
    /// The Hangfire background job ID for the timeout handler, stored so we
    /// can cancel it if the tradie responds before <see cref="ExpiresAtUtc"/>.
    /// </summary>
    [MaxLength(100)]
    public string? HangfireJobId { get; set; }
}
