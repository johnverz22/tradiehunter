using FixoApi.DTOs;
using FixoApi.Enums;

namespace FixoApi.Services;

/// <summary>
/// Application-layer service for Job lifecycle management.
/// All status transitions must go through here — never update Job.Status directly
/// in a controller. Every transition broadcasts via SignalR (per AGENTS.md rule).
/// </summary>
public interface IJobService
{
    Task<JobDto> CreateJobAsync(string homeownerId, CreateJobRequest request);
    Task<JobListResponse> GetJobsForUserAsync(string userId, bool isTradie, string? status, int page, int pageSize);
    Task<JobDto?> GetJobByIdAsync(int id, string requestingUserId, bool isTradie);
    Task<bool> UpdateJobAsync(int id, string homeownerId, UpdateJobRequest request);
    Task<bool> CancelJobAsync(int id, string requestingUserId);

    /// <summary>
    /// Trigger matching: transitions job to Matching, runs IMatchingService,
    /// then transitions to Matched and fires SignalR + FCM to each matched tradie.
    /// </summary>
    Task<MatchResultDto> RunMatchingAsync(int jobId, string homeownerId);

    /// <summary>GET /api/jobs/{id}/matches — re-reads last match result.</summary>
    Task<MatchResultDto> GetMatchesAsync(int jobId, string requestingUserId);

    /// <summary>Homeowner selects a specific tradie from the match list.</summary>
    Task<bool> RequestTradieAsync(int jobId, string homeownerId, string tradieId);

    /// <summary>Tradie accepts the job — transitions to Confirmed.</summary>
    Task<bool> AcceptJobAsync(int jobId, string tradieId);

    /// <summary>Tradie declines — transitions back to Matching (re-match next available).</summary>
    Task<bool> DeclineJobAsync(int jobId, string tradieId);
}
