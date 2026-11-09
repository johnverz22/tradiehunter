using FixoApi.Enums;

namespace FixoApi.DTOs;

// ── Pagination ────────────────────────────────────────────────────────────────

public class PagedResult<T>
{
    public List<T> Items { get; set; } = new();
    public int TotalCount { get; set; }
    public int Page { get; set; }
    public int PageSize { get; set; }
    public int TotalPages => (int)Math.Ceiling((double)TotalCount / PageSize);
}

// ── Stats ─────────────────────────────────────────────────────────────────────

public class AdminStatsDto
{
    public int TotalUsers { get; set; }
    public int ActiveJobs { get; set; }
    public int PendingDisputes { get; set; }
    public int TodaySignups { get; set; }

    /// <summary>Count of jobs per status for the pie / bar chart.</summary>
    public Dictionary<string, int> JobsByStatus { get; set; } = new();

    /// <summary>Daily new-user signups over the last 30 days: ISO date → count.</summary>
    public Dictionary<string, int> SignupsOverTime { get; set; } = new();
}

// ── Users ─────────────────────────────────────────────────────────────────────

public class AdminUserListItemDto
{
    public string Id { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Role { get; set; } = string.Empty;
    public bool IsActive { get; set; }
    public bool IsVerified { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public int JobCount { get; set; }
}

public class AdminUserDetailDto : AdminUserListItemDto
{
    public string? TradeType { get; set; }
    public string? BusinessName { get; set; }
    public double AverageRating { get; set; }
    public int ReviewCount { get; set; }
    public List<AdminJobSummaryDto> RecentJobs { get; set; } = new();
    public List<AdminReviewSummaryDto> RecentReviews { get; set; } = new();
}

public class AdminReviewSummaryDto
{
    public Guid Id { get; set; }
    public int JobId { get; set; }
    public string ReviewerName { get; set; } = string.Empty;
    public int Rating { get; set; }
    public string? Comment { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}

// ── Jobs ──────────────────────────────────────────────────────────────────────

public class AdminJobSummaryDto
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public string HomeownerName { get; set; } = string.Empty;
    public string? TradeName { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime UpdatedAtUtc { get; set; }
}

public class AdminJobDetailDto : AdminJobSummaryDto
{
    public string HomeownerId { get; set; } = string.Empty;
    public string? MatchedTradieId { get; set; }
    public string Description { get; set; } = string.Empty;
    public string Urgency { get; set; } = string.Empty;
    public string? Address { get; set; }
    public DateTime? ScheduledStart { get; set; }
    public string ScheduleStatus { get; set; } = string.Empty;
    public List<JobPhotoDto> Photos { get; set; } = new();
    public List<AdminChatMessageDto> ChatTranscript { get; set; } = new();
    public List<AdminStatusHistoryDto> StatusHistory { get; set; } = new();
}

public class AdminChatMessageDto
{
    public int Id { get; set; }
    public string SenderName { get; set; } = string.Empty;
    public string SenderId { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public DateTime SentAtUtc { get; set; }
    public DateTime? ReadAtUtc { get; set; }
}

public class AdminStatusHistoryDto
{
    public int Id { get; set; }
    public string FromStatus { get; set; } = string.Empty;
    public string ToStatus { get; set; } = string.Empty;
    public string ChangedByUserId { get; set; } = string.Empty;
    public string? ChangedByName { get; set; }
    public DateTime ChangedAtUtc { get; set; }
    public string? Reason { get; set; }
}

// ── Disputes ──────────────────────────────────────────────────────────────────

/// <summary>
/// For MVP, a "dispute" is any job that has been flagged (IsFlagged=true).
/// The flag is set by a user report via POST /api/jobs/{id}/flag.
/// </summary>
public class AdminDisputeListItemDto
{
    public int JobId { get; set; }
    public string JobTitle { get; set; } = string.Empty;
    public string HomeownerName { get; set; } = string.Empty;
    public string? TradieName { get; set; }
    public string Status { get; set; } = string.Empty;
    public string DisputeStatus { get; set; } = string.Empty;
    public string? FlagReason { get; set; }
    public DateTime FlaggedAtUtc { get; set; }
}

public class AdminDisputeDetailDto : AdminDisputeListItemDto
{
    public List<AdminChatMessageDto> ChatTranscript { get; set; } = new();
    public AdminUserDetailDto? HomeownerDetail { get; set; }
    public AdminUserDetailDto? TradieDetail { get; set; }
}

public class ResolveDisputeRequest
{
    /// <summary>One of: "Resolved", "Escalated", "CancelJob".</summary>
    public string Action { get; set; } = string.Empty;
    public string? Note { get; set; }
}

// ── Settings ──────────────────────────────────────────────────────────────────

public class AdminSettingsDto
{
    public string Currency { get; set; } = "NZD";
    public string CurrencySymbol { get; set; } = "$";
    public string Timezone { get; set; } = "Pacific/Auckland";
    public string PhoneFormat { get; set; } = "+64";
    public decimal DefaultMatchRadiusKm { get; set; } = 25m;
    public bool FeatureChatEnabled { get; set; } = true;
    public bool FeatureReviewsEnabled { get; set; } = true;
    public bool FeatureSchedulingEnabled { get; set; } = true;
}

// ── Staff invites (P1-05) ─────────────────────────────────────────────────────

public class StaffInviteRequest
{
    public string Email { get; set; } = string.Empty;
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;

    /// <summary>Staff or Superadmin. Defaults to Staff.</summary>
    public UserRole Role { get; set; } = UserRole.Staff;
}

public class SetStaffPasswordRequest
{
    public string Email { get; set; } = string.Empty;

    /// <summary>Base64Url-encoded Identity password-reset token from the invite email.</summary>
    public string Token { get; set; } = string.Empty;
    public string NewPassword { get; set; } = string.Empty;
}

public class StaffInviteResult
{
    public bool Succeeded { get; set; }
    public string? Error { get; set; }
    public bool Conflict { get; set; }
}

public class SetStaffPasswordResult
{
    public bool Succeeded { get; set; }
    public string? Error { get; set; }
    public string? Token { get; set; }
}

// ── Credential verification (P1-07) ───────────────────────────────────────────

public class PendingCredentialDto
{
    public int Id { get; set; }
    public string Type { get; set; } = string.Empty;
    public string TradieUserId { get; set; } = string.Empty;
    public string TradieName { get; set; } = string.Empty;
    public string TradieEmail { get; set; } = string.Empty;
    public string? TradeType { get; set; }
    public string? BusinessName { get; set; }
    public string OriginalFileName { get; set; } = string.Empty;

    /// <summary>Short-lived (15 min) SAS URL to view the private document.</summary>
    public string DownloadUrl { get; set; } = string.Empty;
}

public class ReviewCredentialRequest
{
    /// <summary>"Approved" or "Rejected" (case-insensitive).</summary>
    public string Status { get; set; } = string.Empty;

    /// <summary>Required when Status is Rejected.</summary>
    public string? RejectReason { get; set; }
}

public class ReviewedCredentialDto : PendingCredentialDto
{
    public string Status { get; set; } = string.Empty;
    public string? RejectReason { get; set; }
    public string? ReviewedById { get; set; }
    public DateTime? ReviewedAtUtc { get; set; }
    public bool TradieIsVerified { get; set; }
}

public class ReviewCredentialResult
{
    public bool Succeeded { get; set; }
    public bool NotFound { get; set; }
    public string? Error { get; set; }
    public ReviewedCredentialDto? Credential { get; set; }
}

// ── Refunds (P6-04 / P6-05) ──────────────────────────────────────────────────

public class RefundSummaryDto
{
    public Guid Id { get; set; }
    public int JobId { get; set; }
    public string JobTitle { get; set; } = string.Empty;
    public string HomeownerName { get; set; } = string.Empty;
    public string HomeownerEmail { get; set; } = string.Empty;
    public int? PaymentId { get; set; }
    public decimal SuggestedAmount { get; set; }
    public decimal FinalAmount { get; set; }
    public decimal Penalty { get; set; }
    public decimal HoursWorked { get; set; }
    public decimal HoursWorkedAmount { get; set; }
    public string Status { get; set; } = string.Empty;
    public string? CancelReasonCode { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? ProcessedAtUtc { get; set; }
    public string? TransferReference { get; set; }

    /// <summary>P8-03: short-lived signed URL for the proof-of-transfer file (private bucket).</summary>
    public string? ProofDownloadUrl { get; set; }
}

/// <summary>Request body for POST /api/admin/refunds/{id}/process (P6-05).</summary>
public class ProcessRefundRequest
{
    public decimal FinalAmount { get; set; }
    public decimal Penalty { get; set; }
    public decimal HoursWorked { get; set; }
    public string TransferReference { get; set; } = string.Empty;
}

/// <summary>
/// Multipart form binding for the refund process endpoint.
/// Standard fields come as form values; the optional proof file arrives as a file upload.
/// </summary>
public class ProcessRefundForm
{
    public decimal FinalAmount { get; set; }
    public decimal Penalty { get; set; }
    public decimal HoursWorked { get; set; }
    public string TransferReference { get; set; } = string.Empty;

    /// <summary>Optional proof-of-transfer file (e.g. bank receipt screenshot). Max 10 MB.</summary>
    public IFormFile? Proof { get; set; }
}

public class ProcessRefundResult
{
    public bool Succeeded { get; set; }
    public bool NotFound { get; set; }
    public bool Conflict { get; set; }
    public string? Error { get; set; }
    public RefundSummaryDto? Refund { get; set; }
}

// ── Metrics ───────────────────────────────────────────────────────────────────

public class AdminMetricsDto
{
    public MetricsWindowDto Last7Days { get; set; } = new();
    public MetricsWindowDto Last30Days { get; set; } = new();
    public MetricsWindowDto AllTime { get; set; } = new();
}

public class MetricsWindowDto
{
    /// <summary>% of signups that posted their first job within 24h.</summary>
    public double ActivationRatePct { get; set; }

    /// <summary>Average hours from job-created to Confirmed status.</summary>
    public double AvgMatchToConfirmationHours { get; set; }

    /// <summary>P8-08: average hours from job-created to AwaitingPayment (offer accepted).</summary>
    public double AvgMatchToAwaitingPaymentHours { get; set; }

    /// <summary>P8-08: average hours a receipt spends in PaymentReview before verify/reject.</summary>
    public double AvgPaymentVerificationHours { get; set; }

    /// <summary>% of match notifications that received accept or decline within 1h.</summary>
    public double TradieResponseRatePct { get; set; }

    /// <summary>% of completed jobs where both parties left reviews.</summary>
    public double ReviewCompletionRatePct { get; set; }

    /// <summary>Total jobs in window.</summary>
    public int TotalJobs { get; set; }

    /// <summary>Total new users in window.</summary>
    public int TotalSignups { get; set; }
}
