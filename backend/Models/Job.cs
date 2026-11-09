using NetTopologySuite.Geometries;
using FixoApi.Enums;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace FixoApi.Models;

/// <summary>
/// A job posted by a homeowner. Status transitions must always go through
/// IJobStatusService and be broadcast via the SignalR JobHub.
/// </summary>
public class Job
{
    [Key]
    public int Id { get; set; }

    [Required]
    public string HomeownerId { get; set; } = string.Empty;

    [ForeignKey(nameof(HomeownerId))]
    public ApplicationUser Homeowner { get; set; } = null!;

    [Required]
    [MaxLength(200)]
    public string Title { get; set; } = string.Empty;

    /// <summary>Trade category — stored as string in the database.</summary>
    public TradeCategory Category { get; set; }

    [MaxLength(2000)]
    public string Description { get; set; } = string.Empty;

    /// <summary>Urgency level — stored as string in the database.</summary>
    public JobUrgency Urgency { get; set; } = JobUrgency.Medium;

    /// <summary>Current state of the job.</summary>
    public JobStatus Status { get; set; } = JobStatus.Requested;

    /// <summary>WGS-84 point (longitude, latitude) — SRID 4326.</summary>
    [Column(TypeName = "geometry(Point, 4326)")]
    public Point? Location { get; set; }

    [MaxLength(300)]
    public string? Address { get; set; }

    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAtUtc { get; set; } = DateTime.UtcNow;

    // ── Scheduling & Financials (v1.2) ───────────────────────────────────────

    /// <summary>Scheduled appointment time, persisted in UTC.</summary>
    public DateTimeOffset ScheduledStartUtc { get; set; }

    /// <summary>
    /// Compatibility projection for the pre-P2 scheduling workflow. New code must
    /// use <see cref="ScheduledStartUtc"/> so API clients receive an explicit UTC offset.
    /// </summary>
    [NotMapped]
    public DateTime? ScheduledStart
    {
        get => ScheduledStartUtc == default ? null : ScheduledStartUtc.UtcDateTime;
        set => ScheduledStartUtc = value is null
            ? default
            : new DateTimeOffset(value.Value.ToUniversalTime());
    }

    public int ServiceId { get; set; }

    public int Hours { get; set; }

    [Column(TypeName = "decimal(18,2)")]
    public decimal HourlyRate { get; set; }

    [Column(TypeName = "decimal(18,2)")]
    public decimal TotalAmount { get; set; }

    [MaxLength(50)]
    public string? ReferenceCode { get; set; }

    public DateTime? StartedAtUtc { get; set; }
    public DateTime? EndedAtUtc { get; set; }

    // ── Legacy Scheduling Fields (To be phased out or kept if still needed) ──
    public ScheduleTimeSlot? ScheduledTimeSlot { get; set; }
    public ScheduleStatus ScheduleStatus { get; set; } = ScheduleStatus.None;
    public string? ScheduleProposedByUserId { get; set; }

    [MaxLength(200)]
    public string? ReminderJobIds { get; set; }

    /// <summary>
    /// Hangfire job ID for the auto-complete background job (P5-04).
    /// Set when job enters AwaitingConfirmation, cleared when confirmed or cancelled.
    /// </summary>
    [MaxLength(100)]
    public string? AutoCompleteJobId { get; set; }

    // ── Matching & Fulfillment ───────────────────────────────────────────────

    public string? MatchedTradieId { get; set; }

    [ForeignKey(nameof(MatchedTradieId))]
    public ApplicationUser? MatchedTradie { get; set; }

    /// <summary>
    /// When an outstanding manual payment must have been verified by (P4-06).
    /// Set on entry to <c>AwaitingPayment</c> and re-baselined whenever staff
    /// reject a receipt, which restarts the homeowner's payment window. The
    /// Hangfire expiry job reads this rather than trusting its own fire time, so
    /// a job enqueued before a rejection is never expired early.
    /// Null when no payment is outstanding.
    /// </summary>
    public DateTime? PaymentDueAtUtc { get; set; }

    public string? CancelledByUserId { get; set; }
    public ReasonCode? CancelReasonCode { get; set; }

    // ── Navigation ───────────────────────────────────────────────────────────

    public ICollection<JobPhoto> Photos { get; set; } = new List<JobPhoto>();
    public ICollection<ChatMessage> ChatMessages { get; set; } = new List<ChatMessage>();
    public ICollection<JobStatusHistory> StatusHistory { get; set; } = new List<JobStatusHistory>();
    public ICollection<JobOffer> Offers { get; set; } = new List<JobOffer>();
    public ICollection<Review> Reviews { get; set; } = new List<Review>();

    /// <summary>The single manual payment attached to this job (P4-01).</summary>
    public Payment? Payment { get; set; }

    /// <summary>The refund record for this job, created on cancellation after payment (P6-01).</summary>
    public Refund? Refund { get; set; }

    // ── Dispute / flag ────────────────────────────────────────────────────────

    public bool IsFlagged { get; set; } = false;

    [MaxLength(1000)]
    public string? FlagReason { get; set; }

    public DateTime? FlaggedAtUtc { get; set; }

    [MaxLength(50)]
    public string DisputeStatus { get; set; } = "None";

    [MaxLength(1000)]
    public string? DisputeNote { get; set; }
}
