namespace FixoApi.DTOs;

// ── Review request DTOs ───────────────────────────────────────────────────────

public class SubmitReviewRequest
{
    public string RevieweeId { get; set; } = string.Empty;
    public int Rating { get; set; }
    public string? Comment { get; set; }
}

// ── Review response DTOs ──────────────────────────────────────────────────────

public class ReviewDto
{
    public Guid Id { get; set; }
    public int JobId { get; set; }
    public string ReviewerId { get; set; } = string.Empty;
    public string ReviewerName { get; set; } = string.Empty;
    public string RevieweeId { get; set; } = string.Empty;
    public int Rating { get; set; }
    public string? Comment { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}

public class ReviewListResponse
{
    public List<ReviewDto> Items { get; set; } = new();
    public int TotalCount { get; set; }
    public int Page { get; set; }
    public int PageSize { get; set; }
}

// ── Schedule request/response DTOs ────────────────────────────────────────────

public class ScheduleJobRequest
{
    /// <summary>Proposed date in UTC (time component is ignored; slot sets the window).</summary>
    public DateTime ProposedDateUtc { get; set; }

    /// <summary>Morning | Afternoon | Evening</summary>
    public string TimeSlot { get; set; } = string.Empty;
}

public class ScheduleDto
{
    public int JobId { get; set; }
    public DateTime? ScheduledDateUtc { get; set; }
    public string? ScheduledTimeSlot { get; set; }

    /// <summary>None | Proposed | Confirmed</summary>
    public string ScheduleStatus { get; set; } = string.Empty;
    public string? ProposedByUserId { get; set; }
}
