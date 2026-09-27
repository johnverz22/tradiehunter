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

    Task<bool> VerifyUserAsync(string userId);

    Task<bool> DeactivateUserAsync(string userId);

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

    Task<AdminSettingsDto> UpdateSettingsAsync(AdminSettingsDto dto);

    // Metrics
    Task<AdminMetricsDto> GetMetricsAsync();
}
