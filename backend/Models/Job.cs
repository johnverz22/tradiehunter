using NetTopologySuite.Geometries;
using FixoApi.Enums;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace FixoApi.Models;

/// <summary>
/// A job posted by a homeowner. Status transitions must always go through
/// IJobService and be broadcast via the SignalR JobHub (AGENTS.md rule).
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

    /// <summary>Trade category — stored as string in the database (HasConversion).</summary>
    public TradeCategory Category { get; set; }

    [MaxLength(2000)]
    public string Description { get; set; } = string.Empty;

    /// <summary>Urgency level — stored as string in the database (HasConversion).</summary>
    public JobUrgency Urgency { get; set; } = JobUrgency.Medium;

    /// <summary>
    /// Current state of the job. Stored as a string so DB rows are human-readable
    /// and the schema does not break when enum values are reordered.
    /// </summary>
    public JobStatus Status { get; set; } = JobStatus.Draft;

    /// <summary>WGS-84 point (longitude, latitude) — SRID 4326. Indexed with GIST.</summary>
    [Column(TypeName = "geometry(Point, 4326)")]
    public Point? Location { get; set; }

    [MaxLength(300)]
    public string? Address { get; set; }

    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAtUtc { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Confirmed or proposed appointment date (UTC).
    /// Set when either party proposes a schedule via POST /api/jobs/{id}/schedule.
    /// </summary>
    public DateTime? ScheduledDateUtc { get; set; }

    /// <summary>Preferred time window within the scheduled date.</summary>
    public ScheduleTimeSlot? ScheduledTimeSlot { get; set; }

    /// <summary>Lifecycle state of the scheduling proposal (None / Proposed / Confirmed).</summary>
    public ScheduleStatus ScheduleStatus { get; set; } = ScheduleStatus.None;

    /// <summary>
    /// The user who last proposed the schedule (so the other party can confirm/counter).
    /// </summary>
    public string? ScheduleProposedByUserId { get; set; }

    /// <summary>
    /// Hangfire job IDs for the two scheduled reminders.
    /// Stored so they can be cancelled if the job is cancelled or rescheduled.
    /// Format: comma-separated "hangfireJobId24h,hangfireJobId1h".
    /// </summary>
    [MaxLength(200)]
    public string? ReminderJobIds { get; set; }

    /// <summary>Populated once the matching service selects a tradie.</summary>
    public string? MatchedTradieId { get; set; }

    [ForeignKey(nameof(MatchedTradieId))]
    public ApplicationUser? MatchedTradie { get; set; }

    /// <summary>Navigation property for photos attached to this job.</summary>
    public ICollection<JobPhoto> Photos { get; set; } = new List<JobPhoto>();

    /// <summary>Chat messages exchanged between homeowner and tradie for this job.</summary>
    public ICollection<ChatMessage> ChatMessages { get; set; } = new List<ChatMessage>();

    /// <summary>Audit trail of every status transition for this job.</summary>
    public ICollection<JobStatusHistory> StatusHistory { get; set; } = new List<JobStatusHistory>();

    /// <summary>Reviews submitted for this job (up to two: one each direction).</summary>
    public ICollection<Review> Reviews { get; set; } = new List<Review>();

    // ── Dispute / flag ────────────────────────────────────────────────────────

    /// <summary>True when a homeowner or tradie has flagged this job for admin review.</summary>
    public bool IsFlagged { get; set; } = false;

    [MaxLength(1000)]
    public string? FlagReason { get; set; }

    public DateTime? FlaggedAtUtc { get; set; }

    /// <summary>Admin-set dispute lifecycle: Open, Resolved, Escalated.</summary>
    [MaxLength(50)]
    public string DisputeStatus { get; set; } = "None";

    [MaxLength(1000)]
    public string? DisputeNote { get; set; }
}
