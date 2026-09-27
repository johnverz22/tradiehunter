using FixoApi.Enums;

namespace FixoApi.DTOs;

// ── Request DTOs ─────────────────────────────────────────────────────────────

public class CreateJobRequest
{
    public string Title { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string Urgency { get; set; } = "Medium";
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public string? Address { get; set; }
    public DateTime? ScheduledDateUtc { get; set; }
}

public class UpdateJobRequest
{
    public string? Title { get; set; }
    public string? Description { get; set; }
    public string? Urgency { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public string? Address { get; set; }
    public DateTime? ScheduledDateUtc { get; set; }
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
    public DateTime? ScheduledDateUtc { get; set; }
    public string? MatchedTradieId { get; set; }

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

// ── Match DTOs ────────────────────────────────────────────────────────────────

public class TradieMatchDto
{
    public string TradieId { get; set; } = string.Empty;
    public string Initials { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Trade { get; set; } = string.Empty;
    public bool Verified { get; set; }
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

// ── SignalR hub event payload ──────────────────────────────────────────────────

/// <summary>
/// Payload pushed to matched tradies via the SignalR JobHub.
/// Mirrors the NewJobMatch server-to-client method (M2-05).
/// </summary>
public class NewJobMatchPayload
{
    public int JobId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string Urgency { get; set; } = string.Empty;
    public string? Address { get; set; }
    public string DistanceKm { get; set; } = string.Empty;
}
