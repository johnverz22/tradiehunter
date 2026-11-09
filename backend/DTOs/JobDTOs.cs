using System.Text.Json.Serialization;
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
    public DateTimeOffset ScheduledStartUtc { get; set; }
    public int Hours { get; set; }
    public decimal HourlyRate { get; set; }
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
    public DateTimeOffset ScheduledStartUtc { get; set; }
    public int Hours { get; set; }
    public decimal HourlyRate { get; set; }
    public decimal TotalAmount { get; set; }
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
