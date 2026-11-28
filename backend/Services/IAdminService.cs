using FixoApi.DTOs;

namespace FixoApi.Services;

public interface IAdminService
{
    // Stats
    Task<AdminStatsDto> GetStatsAsync();

    // Users
    Task<PagedResult<AdminUserListItemDto>> GetUsersAsync(
        string? search, string? role, bool? isActive, int page, int pageSize, string? sortBy, bool sortDesc);

    Task<AdminUserDetailDto?> GetUserDetailAsync(string userId);

    Task<bool> VerifyUserAsync(string userId, string? adminUserId = null);

    /// <summary>Deactivates the user, recording <paramref name="reason"/>; null when the user does not exist.</summary>
    Task<UserStatusChangeResult?> DeactivateUserAsync(string userId, string reason, string? adminUserId = null);

    /// <summary>Restores a deactivated user's access, recording <paramref name="note"/>; null when the user does not exist.</summary>
    Task<UserStatusChangeResult?> ReactivateUserAsync(string userId, string note, string? adminUserId = null);

    // Jobs
    Task<PagedResult<AdminJobSummaryDto>> GetJobsAsync(
        string? status, string? search, int page, int pageSize, string? sortBy, bool sortDesc);

    Task<AdminJobDetailDto?> GetJobDetailAsync(int jobId);

    // Disputes
    Task<PagedResult<AdminDisputeListItemDto>> GetDisputesAsync(string? disputeStatus, int page, int pageSize);

    Task<AdminDisputeDetailDto?> GetDisputeDetailAsync(int jobId);

    Task<bool> ResolveDisputeAsync(int jobId, ResolveDisputeRequest request, string adminUserId);

    // Settings
    Task<AdminSettingsDto> GetSettingsAsync();

    Task<AdminSettingsDto> UpdateSettingsAsync(AdminSettingsDto dto, string? adminUserId = null);

    // Staff invites (P1-05)
    Task<StaffInviteResult> InviteStaffAsync(StaffInviteRequest request);

    Task<SetStaffPasswordResult> SetStaffPasswordAsync(SetStaffPasswordRequest request);

    // Credentials (P1-07)
    Task<PagedResult<PendingCredentialDto>> GetPendingCredentialsAsync(int page, int pageSize);

    Task<ReviewCredentialResult> ReviewCredentialAsync(
        int credentialId, ReviewCredentialRequest request, string adminUserId);

    // Metrics
    Task<AdminMetricsDto> GetMetricsAsync();

    // Refunds (P6-04 / P6-05)
    Task<PagedResult<RefundSummaryDto>> GetPendingRefundsAsync(int page, int pageSize);

    Task<ProcessRefundResult> ProcessRefundAsync(
        Guid refundId, ProcessRefundRequest request, Stream? proofFile, string? proofFileContentType, string adminUserId);

    // Audit log (P8-04 / P8-07)
    Task<PagedResult<AuditLogDto>> GetAuditLogsAsync(
        DateTime? fromUtc, DateTime? toUtc, string? action, string? userId, int page, int pageSize);

    // Staff notifications (plan 09 N6)
    Task<StaffNotificationListDto> GetStaffNotificationsAsync(
        string userId, bool unreadOnly = false, int limit = 20, CancellationToken ct = default);

    Task<bool> MarkStaffNotificationReadAsync(int id, string userId, CancellationToken ct = default);

    Task<int> MarkAllStaffNotificationsReadAsync(string userId, CancellationToken ct = default);
}
