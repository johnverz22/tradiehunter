using System.Text.Json.Serialization;
using System.ComponentModel.DataAnnotations;
using FixoApi.Enums;

namespace FixoApi.DTOs;

// ── Request DTOs ─────────────────────────────────────────────────────────────

public class CreateJobRequest
{
    public string Title { get; set; } = string.Empty;
    // Derived from ServiceId server-side. Kept optional for older clients.
    public string? Category { get; set; }
    public string Description { get; set; } = string.Empty;
    public string Urgency { get; set; } = "Medium";
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public string? Address { get; set; }
    public int ServiceId { get; set; }

    // ── v1.7 (P12-02): timing is optional; rate is chosen at request time ────

    /// <summary>"Flexible" | "Asap" | "SpecificDate" | "DateRange". Default Flexible.</summary>
    public string? TimingPreference { get; set; }

    /// <summary>Optional since v1.7 — required only for SpecificDate/DateRange. Must be UTC.</summary>
    public DateTimeOffset? ScheduledStartUtc { get; set; }

    /// <summary>Range end for DateRange. Must be UTC, after ScheduledStartUtc.</summary>
    public DateTimeOffset? ScheduledEndUtc { get; set; }

    /// <summary>Was <c>Hours</c> — now the homeowner's optional guess. Null = "total confirmed on completion".</summary>
    public int? EstimatedHours { get; set; }

    /// <summary>
    /// Removed in v1.7 (rate is chosen on the Choose-a-Tradie screen and
    /// snapshotted at request time). Kept on the wire for old clients but
    /// IGNORED — see JobService.CreateJobAsync (P12-02).
    /// </summary>
    public decimal HourlyRate { get; set; }

    /// <summary>v1.7 (P12-21): "Hourly" | "Project". Default Hourly.</summary>
    public string? JobType { get; set; }

    /// <summary>v1.7 (P12-21): project-only, optional budget range.</summary>
    public decimal? BudgetMin { get; set; }

    /// <summary>v1.7 (P12-21): project-only, optional budget range.</summary>
    public decimal? BudgetMax { get; set; }

    /// <summary>v1.7 (P12-21): "Tradie" | "Homeowner" | "Undecided". Default Undecided.</summary>
    public string? MaterialsBy { get; set; }

    /// <summary>v1.7 (P12-21): homeowner welcomes on-site visits before quoting.</summary>
    public bool SiteVisitWelcome { get; set; }

    /// <summary>v1.7 (P12-21): project scope notes beyond the shared description.</summary>
    public string? ScopeNotes { get; set; }

    /// <summary>
    /// Plan 10 (Q7.3): project-only. true = open to nearby tradies (board); absent or false =
    /// invite-only, today's behaviour, so older clients are unaffected.
    /// </summary>
    public bool? OpenToBoard { get; set; }
}

public class UpdateJobRequest
{
    public string? Title { get; set; }
    public string? Description { get; set; }
    public string? Urgency { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public string? Address { get; set; }
    public DateTimeOffset? ScheduledStartUtc { get; set; }

    /// <summary>v1.7: optional timing preference update (P12-02).</summary>
    public string? TimingPreference { get; set; }

    /// <summary>v1.7: optional range end update (P12-02).</summary>
    public DateTimeOffset? ScheduledEndUtc { get; set; }

    /// <summary>v1.7: optional estimated-hours update (P12-02).</summary>
    public int? EstimatedHours { get; set; }
}

/// <summary>Request body for POST /api/jobs/{id}/cancel (P6-02).</summary>
public class CancelJobRequest
{
    /// <summary>
    /// Machine-readable reason for the cancellation.
    /// Must match a value in the <see cref="FixoApi.Enums.ReasonCode"/> enum.
    /// Accepts the snake_case name (e.g. "homeowner_changed_mind") or its
    /// numeric value — the mobile repository sends the name.
    /// </summary>
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public ReasonCode ReasonCode { get; set; }

    /// <summary>Optional free-text note the user supplies alongside the reason code.</summary>
    public string? Notes { get; set; }
}

// ── Response DTOs ─────────────────────────────────────────────────────────────

public class JobDto
{
    public int Id { get; set; }
    public string HomeownerId { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string Urgency { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public string? Address { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime UpdatedAtUtc { get; set; }
    public int ServiceId { get; set; }

    // ── v1.7 timing (P12-02) ──────────────────────────────────────────────────

    /// <summary>"Flexible" | "Asap" | "SpecificDate" | "DateRange".</summary>
    public string TimingPreference { get; set; } = "Flexible";

    /// <summary>Null when the job is flexible — clients must show "date TBC".</summary>
    public DateTimeOffset? ScheduledStartUtc { get; set; }

    /// <summary>Range end for DateRange jobs.</summary>
    public DateTimeOffset? ScheduledEndUtc { get; set; }

    /// <summary>The homeowner's optional guess; null = confirmed on completion.</summary>
    public int? EstimatedHours { get; set; }

    /// <summary>Rate snapshot (request-time under v2). Null for projects without an hourly quote.</summary>
    public decimal HourlyRate { get; set; }

    /// <summary>Display-only estimate (rate × estimated hours or accepted quote); null when unknown.</summary>
    public decimal? EstimatedTotal { get; set; }

    // ── v1.7 money at completion (P12-11) ─────────────────────────────────────

    public decimal? FinalHours { get; set; }
    public decimal? LabourAmount { get; set; }

    /// <summary>Σ approved adjustments — grows live as the homeowner approves extras.</summary>
    public decimal? AdjustmentsTotal { get; set; }

    /// <summary>What the homeowner pays: LabourAmount + AdjustmentsTotal.</summary>
    public decimal? FinalAmount { get; set; }

    public DateTime? CompletionSubmittedAtUtc { get; set; }

    /// <summary>
    /// DEPRECATED alias kept for one release (P12-02): FinalAmount ?? EstimatedTotal ?? 0.
    /// New clients must stop reading this and use the explicit fields above.
    /// </summary>
    public decimal TotalAmount => FinalAmount ?? EstimatedTotal ?? 0m;

    // ── v1.7 job type / flow ──────────────────────────────────────────────────

    /// <summary>"Hourly" | "Project" (P12-21).</summary>
    public string JobType { get; set; } = "Hourly";

    /// <summary>"Fixed" | "EstimateRange" | "HourlyWithCap" when a project quote was accepted (P12-23).</summary>
    public string? AgreedPricingModel { get; set; }

    /// <summary>Flow rules this job runs under: 1 = legacy upfront, 2 = pay-at-completion (P12-27).</summary>
    public int FlowVersion { get; set; } = 1;

    /// <summary>True when FinalAmount exceeds EstimatedTotal beyond the configured tolerance (P12-11 banner).</summary>
    public bool IsAboveEstimateTolerance { get; set; }

    public string? ReferenceCode { get; set; }
    public string? MatchedTradieId { get; set; }
    public string? MatchedTradieName { get; set; }

    /// <summary>Open/Resolved dispute flag; null when no dispute exists.</summary>
    public string? DisputeStatus { get; set; }

    /// <summary>Stage index 0-3 for the mobile JobStepper widget.</summary>
    public int Stage { get; set; }

    /// <summary>Suburb/locality extracted from Address for the mobile card.</summary>
    public string? Suburb { get; set; }

    public List<JobPhotoDto> Photos { get; set; } = new();

    // ── Quote progress (plan 10) ──────────────────────────────────────────────

    /// <summary>
    /// Quote requests still live or answered ("M" in "N of M quotes in"). Null unless
    /// the caller is the homeowner of a Project job in status Requested.
    /// </summary>
    public int? QuotesRequested { get; set; }

    /// <summary>
    /// Quotes the homeowner can act on ("N"): Submitted and not past ValidUntilUtc,
    /// plus the Accepted one. Null under the same conditions as <see cref="QuotesRequested"/>.
    /// </summary>
    public int? QuotesReceived { get; set; }

    /// <summary>Plan 10 (Q7.3): project is open to the tradie board (not invite-only).</summary>
    public bool OpenToBoard { get; set; }

    /// <summary>Plan 10 (Q7.3): when an open project stops accepting new quotes (UTC); null for invite-only jobs.</summary>
    public DateTime? QuotesCloseAtUtc { get; set; }
}

public class JobPhotoDto
{
    public int Id { get; set; }
    public string Url { get; set; } = string.Empty;
    public string? OriginalFileName { get; set; }
}

public class JobListResponse
{
    public List<JobDto> Items { get; set; } = new();
    public int TotalCount { get; set; }
    public int Page { get; set; }
    public int PageSize { get; set; }
}

// ── Plan 10 Q7.4: Available-jobs board ───────────────────────────────────────

/// <summary>
/// One open project job on the tradie "Available jobs" board (plan 10 Q7.4).
/// Full detail per D7: scope, notes, budget range, materials-by, site-visit,
/// timing, all photo URLs, suburb and distance.
/// Address is masked to suburb until <c>Booked</c> (P5-01 privacy rule).
/// </summary>
public class AvailableJobDto
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string Urgency { get; set; } = string.Empty;
    public int ServiceId { get; set; }

    /// <summary>Suburb-only (P5-01: address masked until Booked).</summary>
    public string? Suburb { get; set; }

    /// <summary>Straight-line distance from the tradie's registered location (km).</summary>
    public double? DistanceKm { get; set; }

    // ── Project details (D7) ──────────────────────────────────────────────────

    public string? ScopeNotes { get; set; }
    public decimal? BudgetMin { get; set; }
    public decimal? BudgetMax { get; set; }

    /// <summary>"Tradie" | "Homeowner" | "Undecided".</summary>
    public string MaterialsBy { get; set; } = string.Empty;
    public bool SiteVisitWelcome { get; set; }

    // ── Timing ───────────────────────────────────────────────────────────────

    /// <summary>"Flexible" | "Asap" | "SpecificDate" | "DateRange".</summary>
    public string TimingPreference { get; set; } = "Flexible";
    public DateTimeOffset? ScheduledStartUtc { get; set; }
    public DateTimeOffset? ScheduledEndUtc { get; set; }

    // ── Board state ───────────────────────────────────────────────────────────

    /// <summary>How many quotes the homeowner has already received (from any tradie).</summary>
    public int QuotesReceived { get; set; }

    /// <summary>When the board stops accepting new quotes (UTC).</summary>
    public DateTime QuotesCloseAtUtc { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public List<JobPhotoDto> Photos { get; set; } = new();
}

/// <summary>Paged response for GET /api/tradie/available-jobs.</summary>
public class AvailableJobsResponse
{
    public List<AvailableJobDto> Items { get; set; } = new();
    public int TotalCount { get; set; }
    public int Page { get; set; }
    public int PageSize { get; set; }
}

/// <summary>
/// Counterparty contact for a booked-or-later job (V15-15). Only the job's
/// homeowner or matched tradie can read this, and only while the job is in a
/// contactable status. PhoneNumber is null when the user never set one —
/// the client must hide the Call action rather than invent a number.
/// </summary>
public class JobContactDto
{
    public string UserId { get; set; } = string.Empty;
    public string FirstName { get; set; } = string.Empty;
    public string? PhoneNumber { get; set; }
}

/// <summary>A verified nearby tradie who offers the requested service.</summary>
public class ServiceSearchResultDto
{
    public string TradieId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string? BusinessName { get; set; }
    public decimal HourlyRate { get; set; }
    public double DistanceKm { get; set; }
}

// ── Match DTOs ────────────────────────────────────────────────────────────────

/// <summary>
/// v1.7 (P12-05): one row of the Choose-a-Tradie screen — everything needed to
/// compare tradies for THIS job, server-ranked. <see cref="HourlyRate"/> is the
/// final consumer price for the job's service; <see cref="IsGstRegistered"/>
/// drives the "Incl. GST" / "No GST charged" label (D8).
/// </summary>
public class TradieListDto
{
    public string TradieId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string? BusinessName { get; set; }
    public string Initials { get; set; } = string.Empty;
    public bool Verified { get; set; }
    public bool Insured { get; set; }
    public bool Available { get; set; }
    public bool Online { get; set; }
    public DateTime? LastSeenAtUtc { get; set; }
    public double Rating { get; set; }
    public int ReviewCount { get; set; }
    public int CompletedJobs { get; set; }
    public double DistanceKm { get; set; }
    public string Distance { get; set; } = string.Empty;

    /// <summary>Hourly rate for the job's service — final consumer price (D8).</summary>
    public decimal HourlyRate { get; set; }

    /// <summary>D8: true → "Incl. GST"; false → "No GST charged".</summary>
    public bool IsGstRegistered { get; set; }

    /// <summary>Server-computed composite score; sort=best orders by this.</summary>
    public double Score { get; set; }

    public string? Bio { get; set; }
}

/// <summary>Query parameters for GET /api/jobs/{id}/tradies (P12-05).</summary>
public class TradieListQuery
{
    /// <summary>"best" (default, server score) | "rating" | "distance" | "rate".</summary>
    public string? Sort { get; set; }

    /// <summary>Keep only verified tradies when true.</summary>
    public bool? Verified { get; set; }

    /// <summary>Keep only insured tradies when true.</summary>
    public bool? Insured { get; set; }

    /// <summary>Keep only currently-available tradies when true.</summary>
    public bool? AvailableNow { get; set; }
}

public class TradieMatchDto
{
    public string TradieId { get; set; } = string.Empty;
    public string Initials { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Trade { get; set; } = string.Empty;
    public bool Verified { get; set; }
    public bool HasInsurance { get; set; }
    public string Distance { get; set; } = string.Empty;
    public double DistanceKm { get; set; }
    public double Rating { get; set; }
    public int ReviewCount { get; set; }
    public string? Bio { get; set; }
}

public class MatchResultDto
{
    public List<TradieMatchDto> Matches { get; set; } = new();
}

/// <summary>Payload pushed to matched tradies via the SignalR JobHub.</summary>
public class NewJobMatchPayload
{
    public int JobId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string Urgency { get; set; } = string.Empty;
    public string? Address { get; set; }
    public string DistanceKm { get; set; } = string.Empty;
}

/// <summary>
/// Payload for the JobStatusChanged hub event. Every status transition flows
/// through this so web and mobile stay in sync (see AGENTS.md — no REST-only
/// side channel for status).
/// </summary>
public class JobStatusChangedPayload
{
    public int JobId { get; set; }

    /// <summary>New status name, e.g. "Requested", "AwaitingPayment", "Cancelled".</summary>
    public string Status { get; set; } = string.Empty;

    /// <summary>Previous status name, so clients can detect a regression.</summary>
    public string PreviousStatus { get; set; } = string.Empty;

    /// <summary>Machine-readable reason for system transitions (e.g. no_tradie_found).</summary>
    public string? ReasonCode { get; set; }

    public string? Reason { get; set; }
}

// ── P3: Ranking + Offer DTOs ──────────────────────────────────────────────────

/// <summary>
/// A tradie candidate with a composite match score used by the ranking engine (P3-02).
/// Higher score = better match.
/// </summary>
public class RankedTradieDto
{
    public string TradieId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public double Score { get; set; }
    public double DistanceKm { get; set; }
    public double Rating { get; set; }
    public bool ScheduleMatch { get; set; }
}

/// <summary>Response payload for a single offer (P3-07).</summary>
public class OfferDto
{
    public int Id { get; set; }
    public int JobId { get; set; }
    public string TradieId { get; set; } = string.Empty;
    public DateTime OfferedAtUtc { get; set; }
    public DateTime ExpiresAtUtc { get; set; }
    public string Response { get; set; } = string.Empty;
    public string Stage { get; set; } = string.Empty;

    // ── v1.7 (P12-08) ─────────────────────────────────────────────────────────

    /// <summary>"Instant" (hourly accept) | "QuoteRequest" (project quote).</summary>
    public string Kind { get; set; } = "Instant";

    /// <summary>Rate snapshotted at request time — what the job bills at when accepted.</summary>
    public decimal HourlyRateSnapshot { get; set; }

    /// <summary>The homeowner's optional one-way message (D3 — the only pre-acceptance channel).</summary>
    public string? Message { get; set; }

    /// <summary>Tradie display name, so the request-sent screen can show who was asked.</summary>
    public string? TradieName { get; set; }

    /// <summary>Job title, for the tradie's request-detail header.</summary>
    public string? JobTitle { get; set; }

    /// <summary>
    /// Server clock at response time (UTC). Clients compute a clock offset from it so
    /// the offer countdown does not drift with a wrong device clock (QA plan §3).
    /// </summary>
    public DateTime ServerNowUtc { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// v1.7 (P12-08): request body for POST /api/jobs/{id}/request — the homeowner
/// asks a specific tradie (replaces the unused tradieId path of old
/// POST /api/jobs/{id}/requests). Message is optional (D3).
/// </summary>
public class RequestTradieRequest
{
    public string TradieId { get; set; } = string.Empty;

    [MaxLength(1000)]
    public string? Message { get; set; }
}

/// <summary>Request body for POST /api/jobs/{id}/offers/{offerId}/respond (P3-07).</summary>
public class RespondToOfferRequest
{
    /// <summary>Must be "Accepted" or "Declined".</summary>
    public string Response { get; set; } = string.Empty;
}

/// <summary>
/// SignalR payload for offer lifecycle events (OfferCreated, OfferExpired,
/// OfferAccepted, OfferDeclined) pushed to homeowner + relevant tradie (P3-10).
/// </summary>
public class OfferLifecyclePayload
{
    public string EventType { get; set; } = string.Empty; // "OfferCreated" | "OfferExpired" | "OfferAccepted" | "OfferDeclined"
    public int JobId { get; set; }
    public int OfferId { get; set; }
    public string TradieId { get; set; } = string.Empty;
    public DateTime ExpiresAtUtc { get; set; }
    public string? JobTitle { get; set; }
    /// <summary>
    /// Sequential index of this offer within the current job's matching run
    /// (1-based). Homeowner screen uses this to display "Contacting Tradie N…".
    /// </summary>
    public int OfferIndex { get; set; }
}
