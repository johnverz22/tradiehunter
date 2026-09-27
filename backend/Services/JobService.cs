using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Hubs;
using FixoApi.Models;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using NetTopologySuite.Geometries;

namespace FixoApi.Services;

/// <summary>
/// Application-layer implementation of <see cref="IJobService"/> (M2-03, M2-04, M2-05, M2-06).
/// 
/// Responsibilities:
///   • CRUD operations with status-machine enforcement
///   • Calls IMatchingService for rule-based tradie selection
///   • Broadcasts every status transition via IHubContext&lt;JobHub&gt;
///   • Sends FCM push via PushNotificationService after SignalR dispatch
/// </summary>
public class JobService : IJobService
{
    private readonly IJobRepository _jobRepo;
    private readonly IMatchingService _matchingService;
    private readonly IHubContext<JobHub> _hub;
    private readonly PushNotificationService _push;
    private readonly FixoDbContext _context;
    private readonly ILogger<JobService> _logger;

    public JobService(
        IJobRepository jobRepo,
        IMatchingService matchingService,
        IHubContext<JobHub> hub,
        PushNotificationService push,
        FixoDbContext context,
        ILogger<JobService> logger)
    {
        _jobRepo         = jobRepo;
        _matchingService = matchingService;
        _hub             = hub;
        _push            = push;
        _context         = context;
        _logger          = logger;
    }

    // ── CRUD ──────────────────────────────────────────────────────────────────

    public async Task<JobDto> CreateJobAsync(string homeownerId, CreateJobRequest request)
    {
        if (!Enum.TryParse<TradeCategory>(request.Category, ignoreCase: true, out var category))
            throw new ArgumentException($"Invalid category: {request.Category}");

        if (!Enum.TryParse<JobUrgency>(request.Urgency ?? "Medium", ignoreCase: true, out var urgency))
            urgency = JobUrgency.Medium;

        Point? location = null;
        if (request.Latitude.HasValue && request.Longitude.HasValue)
            location = new Point(request.Longitude.Value, request.Latitude.Value) { SRID = 4326 };

        var job = new Job
        {
            HomeownerId     = homeownerId,
            Title           = request.Title,
            Category        = category,
            Description     = request.Description,
            Urgency         = urgency,
            Status          = JobStatus.Requested,
            Location        = location,
            Address         = request.Address,
            ScheduledDateUtc = request.ScheduledDateUtc,
            CreatedAtUtc    = DateTime.UtcNow,
            UpdatedAtUtc    = DateTime.UtcNow,
        };

        var created = await _jobRepo.CreateAsync(job);
        _logger.LogInformation("Job {JobId} created by homeowner {HomeownerId}", created.Id, homeownerId);
        return MapToDto(created);
    }

    public async Task<JobListResponse> GetJobsForUserAsync(
        string userId, bool isTradie, string? status, int page, int pageSize)
    {
        pageSize = Math.Clamp(pageSize, 1, 50);
        page     = Math.Max(1, page);

        JobStatus? statusFilter = null;
        if (!string.IsNullOrEmpty(status) && Enum.TryParse<JobStatus>(status, ignoreCase: true, out var parsed))
            statusFilter = parsed;

        var (items, total) = await _jobRepo.GetForUserAsync(userId, isTradie, statusFilter, page, pageSize);

        return new JobListResponse
        {
            Items      = items.Select(MapToDto).ToList(),
            TotalCount = total,
            Page       = page,
            PageSize   = pageSize,
        };
    }

    public async Task<JobDto?> GetJobByIdAsync(int id, string requestingUserId, bool isTradie)
    {
        var job = await _jobRepo.GetByIdAsync(id, includePhotos: true);
        if (job == null) return null;

        // Authorisation: homeowners see their own; tradies see what's matched to them.
        if (isTradie && job.MatchedTradieId != requestingUserId) return null;
        if (!isTradie && job.HomeownerId     != requestingUserId) return null;

        return MapToDto(job);
    }

    public async Task<bool> UpdateJobAsync(int id, string homeownerId, UpdateJobRequest request)
    {
        var job = await _jobRepo.GetByIdAsync(id);
        if (job == null || job.HomeownerId != homeownerId) return false;

        // Only Draft or Requested jobs can be edited.
        if (job.Status is not (JobStatus.Draft or JobStatus.Requested)) return false;

        if (request.Title       != null) job.Title       = request.Title;
        if (request.Description != null) job.Description = request.Description;
        if (request.Address     != null) job.Address     = request.Address;
        if (request.ScheduledDateUtc.HasValue) job.ScheduledDateUtc = request.ScheduledDateUtc;

        if (!string.IsNullOrEmpty(request.Urgency) &&
            Enum.TryParse<JobUrgency>(request.Urgency, ignoreCase: true, out var urgency))
            job.Urgency = urgency;

        if (request.Latitude.HasValue && request.Longitude.HasValue)
            job.Location = new Point(request.Longitude.Value, request.Latitude.Value) { SRID = 4326 };

        await _jobRepo.UpdateAsync(job);
        return true;
    }

    public async Task<bool> CancelJobAsync(int id, string requestingUserId)
    {
        var job = await _jobRepo.GetByIdAsync(id);
        if (job == null) return false;

        // Either party can cancel before InProgress.
        var isOwner  = job.HomeownerId    == requestingUserId;
        var isTradie = job.MatchedTradieId == requestingUserId;
        if (!isOwner && !isTradie) return false;

        if (job.Status is JobStatus.Complete or JobStatus.Cancelled) return false;

        await TransitionStatusAsync(job, JobStatus.Cancelled);
        return true;
    }

    // ── Matching ──────────────────────────────────────────────────────────────

    public async Task<MatchResultDto> RunMatchingAsync(int jobId, string homeownerId)
    {
        var job = await _jobRepo.GetByIdAsync(jobId);
        if (job == null || job.HomeownerId != homeownerId)
            return new MatchResultDto();

        // Transition → Matching
        await TransitionStatusAsync(job, JobStatus.Matching);

        var matches = await _matchingService.FindMatchesAsync(job);

        if (matches.Count == 0)
        {
            _logger.LogInformation("Job {JobId}: no tradies matched", jobId);
            // Stay in Matching state — client will show "No tradies found" after timeout.
            return new MatchResultDto { Matches = matches };
        }

        // Transition → Matched (picks the top-ranked tradie as the suggested match)
        job.MatchedTradieId = matches[0].TradieId;
        await TransitionStatusAsync(job, JobStatus.Matched);

        // Notify all matched tradies via SignalR + FCM (M2-05, M2-06).
        await NotifyMatchedTradiesAsync(job, matches);

        return new MatchResultDto { Matches = matches };
    }

    public async Task<MatchResultDto> GetMatchesAsync(int jobId, string requestingUserId)
    {
        var job = await _jobRepo.GetByIdAsync(jobId, includePhotos: false);
        if (job == null || job.HomeownerId != requestingUserId)
            return new MatchResultDto();

        var matches = await _matchingService.FindMatchesAsync(job);
        return new MatchResultDto { Matches = matches };
    }

    public async Task<bool> RequestTradieAsync(int jobId, string homeownerId, string tradieId)
    {
        var job = await _jobRepo.GetByIdAsync(jobId);
        if (job == null || job.HomeownerId != homeownerId) return false;
        if (job.Status is not (JobStatus.Matched or JobStatus.Matching)) return false;

        job.MatchedTradieId = tradieId;
        await TransitionStatusAsync(job, JobStatus.Matched);
        return true;
    }

    public async Task<bool> AcceptJobAsync(int jobId, string tradieId)
    {
        var job = await _jobRepo.GetByIdAsync(jobId);
        if (job == null || job.MatchedTradieId != tradieId) return false;
        if (job.Status != JobStatus.Matched) return false;

        await TransitionStatusAsync(job, JobStatus.Confirmed);
        return true;
    }

    public async Task<bool> DeclineJobAsync(int jobId, string tradieId)
    {
        var job = await _jobRepo.GetByIdAsync(jobId);
        if (job == null || job.MatchedTradieId != tradieId) return false;
        if (job.Status != JobStatus.Matched) return false;

        // Clear matched tradie and go back to Matching so another can be found.
        job.MatchedTradieId = null;
        await TransitionStatusAsync(job, JobStatus.Matching);
        return true;
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /// <summary>
    /// Transitions <paramref name="job"/> to <paramref name="newStatus"/>, persists,
    /// then broadcasts a JobStatusChanged event to the job's SignalR group.
    /// Always call this instead of setting Job.Status directly.
    /// </summary>
    private async Task TransitionStatusAsync(Job job, JobStatus newStatus)
    {
        var prev = job.Status;
        job.Status = newStatus;
        await _jobRepo.UpdateAsync(job);

        _logger.LogInformation("Job {JobId} status: {Prev} → {New}", job.Id, prev, newStatus);

        // Broadcast to any clients subscribed to this job's group.
        await _hub.Clients
            .Group(JobHub.GroupName(job.Id))
            .SendAsync("JobStatusChanged", job.Id, newStatus.ToString());
    }

    /// <summary>
    /// Sends SignalR NewJobMatch then FCM push to each matched tradie (M2-05, M2-06).
    /// FCM failures are logged but never throw — they must not abort the matching flow.
    /// </summary>
    private async Task NotifyMatchedTradiesAsync(Job job, List<TradieMatchDto> matches)
    {
        foreach (var match in matches)
        {
            var payload = new NewJobMatchPayload
            {
                JobId      = job.Id,
                Title      = job.Title,
                Category   = job.Category.ToString(),
                Urgency    = job.Urgency.ToString(),
                Address    = job.Address,
                DistanceKm = match.Distance,
            };

            // SignalR — user-targeted (only this tradie's connections).
            await _hub.Clients
                .User(match.TradieId)
                .SendAsync("NewJobMatch", payload);

            // FCM — fire-and-forget; failures are caught and logged inside SendMulticastAsync.
            _ = SendFcmToTradieAsync(match.TradieId, job);
        }
    }

    private async Task SendFcmToTradieAsync(string tradieId, Job job)
    {
        try
        {
            var tokens = await _context.DeviceTokens
                .Where(dt => dt.UserId == tradieId)
                .Select(dt => dt.Token)
                .ToListAsync();

            if (tokens.Count == 0) return;

            var staleTokens = await _push.SendMulticastAsync(
                tokens,
                title: "New Job Match",
                body:  $"{job.Category}: {job.Title}",
                data: new Dictionary<string, string>
                {
                    { "jobId",    job.Id.ToString()    },
                    { "category", job.Category.ToString() },
                    { "urgency",  job.Urgency.ToString()  },
                });

            // Clean up stale tokens so we don't retry them.
            if (staleTokens.Count > 0)
            {
                var toRemove = await _context.DeviceTokens
                    .Where(dt => dt.UserId == tradieId && staleTokens.Contains(dt.Token))
                    .ToListAsync();
                _context.DeviceTokens.RemoveRange(toRemove);
                await _context.SaveChangesAsync();
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "FCM dispatch failed for tradie {TradieId} job {JobId}", tradieId, job.Id);
            // Deliberately swallowed — push failure must not break the matching flow.
        }
    }

    // ── Mapping ───────────────────────────────────────────────────────────────

    private static JobDto MapToDto(Job job)
    {
        var stage = job.Status switch
        {
            JobStatus.Requested or JobStatus.Matching => 0,
            JobStatus.Matched                          => 1,
            JobStatus.Confirmed or JobStatus.InProgress => 2,
            JobStatus.Complete                         => 3,
            _                                          => 0,
        };

        // Extract suburb as the first comma-separated segment of the address.
        var suburb = job.Address?.Split(',').FirstOrDefault()?.Trim() ?? "";

        return new JobDto
        {
            Id               = job.Id,
            HomeownerId      = job.HomeownerId,
            Title            = job.Title,
            Category         = job.Category.ToString(),
            Description      = job.Description,
            Urgency          = job.Urgency.ToString(),
            Status           = job.Status.ToString(),
            Address          = job.Address,
            Suburb           = suburb,
            Latitude         = job.Location?.Y,
            Longitude        = job.Location?.X,
            CreatedAtUtc     = job.CreatedAtUtc,
            UpdatedAtUtc     = job.UpdatedAtUtc,
            ScheduledDateUtc = job.ScheduledDateUtc,
            MatchedTradieId  = job.MatchedTradieId,
            Stage            = stage,
            Photos           = job.Photos.Select(p => new JobPhotoDto
            {
                Id               = p.Id,
                Url              = BuildPhotoUrl(p.S3Key),
                OriginalFileName = p.OriginalFileName,
            }).ToList(),
        };
    }

    /// <summary>
    /// In production this would generate a pre-signed URL via the S3 client.
    /// For now return a relative path the Flutter client can resolve.
    /// </summary>
    private static string BuildPhotoUrl(string s3Key) =>
        $"/api/photos/{s3Key}";
}
