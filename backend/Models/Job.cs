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

    /// <summary>
    /// v1.7 (P12-01): when the homeowner wants the job done. Default
    /// <see cref="TimingPreference.Flexible"/>; only SpecificDate/DateRange carry dates.
    /// </summary>
    public TimingPreference TimingPreference { get; set; } = TimingPreference.Flexible;

    /// <summary>
    /// Scheduled appointment start, persisted in UTC. Nullable since v1.7 —
    /// flexible jobs have no fixed start (P12-01). Every consumer must handle null.
    /// </summary>
    public DateTimeOffset? ScheduledStartUtc { get; set; }

    /// <summary>v1.7 (P12-01): optional range end for <see cref="TimingPreference.DateRange"/> jobs.</summary>
    public DateTimeOffset? ScheduledEndUtc { get; set; }

    /// <summary>
    /// Compatibility projection for the pre-P2 scheduling workflow. New code must
    /// use <see cref="ScheduledStartUtc"/> so API clients receive an explicit UTC offset.
    /// </summary>
    [NotMapped]
    public DateTime? ScheduledStart
    {
        get => ScheduledStartUtc?.UtcDateTime;
        set => ScheduledStartUtc = value is null
            ? null
            : new DateTimeOffset(value.Value.ToUniversalTime());
    }

    public int ServiceId { get; set; }

    /// <summary>v1.7 (P12-01): was <c>Hours</c> — the homeowner's optional guess; null means "total confirmed on completion".</summary>
    public int? EstimatedHours { get; set; }

    /// <summary>
    /// Snapshot of the tradie's rate. Under the v2 flow it is copied from
    /// <see cref="JobOffer.HourlyRateSnapshot"/> when the tradie accepts (P12-08);
    /// under v1 it is still the rate picked on the Post Job screen.
    /// </summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal HourlyRate { get; set; }

    /// <summary>v1.7 (P12-01): was <c>TotalAmount</c> — display-only estimate, null when the homeowner skipped hours. Never the billed amount.</summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal? EstimatedTotal { get; set; }

    /// <summary>v1.7 (P12-11): hours the tradie submits at check-out.</summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal? FinalHours { get; set; }

    /// <summary>v1.7 (P12-11): FinalHours × HourlyRate, computed server-side at check-out.</summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal? LabourAmount { get; set; }

    /// <summary>v1.7 (P12-11): running total of Approved price adjustments (P12-17).</summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal? AdjustmentsTotal { get; set; }

    /// <summary>v1.7 (P12-11): LabourAmount + AdjustmentsTotal — what the homeowner actually pays.</summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal? FinalAmount { get; set; }

    /// <summary>v1.7 (P12-11): when the tradie submitted the completion summary.</summary>
    public DateTime? CompletionSubmittedAtUtc { get; set; }

    // ── Job type & project fields (v1.7 P12-21) ──────────────────────────────

    /// <summary>v1.7 (P12-21): Hourly (default) or Project. One table, one lifecycle.</summary>
    public JobType JobType { get; set; } = JobType.Hourly;

    /// <summary>v1.7 (P12-21): project-only, optional budget lower bound.</summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal? BudgetMin { get; set; }

    /// <summary>v1.7 (P12-21): project-only, optional budget upper bound.</summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal? BudgetMax { get; set; }

    /// <summary>v1.7 (P12-21): who buys materials on a project job.</summary>
    public MaterialsResponsibility MaterialsBy { get; set; } = MaterialsResponsibility.Undecided;

    /// <summary>v1.7 (P12-21): homeowner is happy for tradies to visit and quote on site.</summary>
    public bool SiteVisitWelcome { get; set; }

    /// <summary>v1.7 (P12-21): project scope notes beyond the shared description.</summary>
    [MaxLength(5000)]
    public string? ScopeNotes { get; set; }

    /// <summary>v1.7 (P12-23): pricing model agreed with the accepted quote (projects only).</summary>
    public QuotePricingModel? AgreedPricingModel { get; set; }

    /// <summary>v1.7 (P12-23): the accepted quote, kept for history/audit.</summary>
    public int? AcceptedQuoteId { get; set; }

    /// <summary>v1.7 (P12-25): homeowner confirmed a written contract exists (≥ threshold quotes).</summary>
    public bool WrittenContractConfirmed { get; set; }

    /// <summary>v1.7 (P12-27): flow rules this job was posted under — 1 = legacy upfront payment, 2 = pay-at-completion. Behaviour branches on this, never on the global flag alone.</summary>
    public int FlowVersion { get; set; } = 1;

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

    /// <summary>v1.7 (P12-17): on-demand price adjustments proposed during the job.</summary>
    public ICollection<JobPriceAdjustment> Adjustments { get; set; } = new List<JobPriceAdjustment>();

    /// <summary>v1.7 (P12-23): quotes submitted by tradies for project jobs.</summary>
    public ICollection<Quote> Quotes { get; set; } = new List<Quote>();

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
