using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace FixoApi.Services;

/// <summary>
/// Admin service — all read/write operations for the admin dashboard.
/// Follows Controller Purity: controllers call this service; no EF in controllers.
/// </summary>
public class AdminService : IAdminService
{
    private readonly FixoDbContext _db;
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly IOptions<LocaleOptions> _locale;
    private readonly ILogger<AdminService> _logger;

    public AdminService(
        FixoDbContext db,
        UserManager<ApplicationUser> userManager,
        IOptions<LocaleOptions> locale,
        ILogger<AdminService> logger)
    {
        _db = db;
        _userManager = userManager;
        _locale = locale;
        _logger = logger;
    }

    // ── Stats ──────────────────────────────────────────────────────────────────

    public async Task<AdminStatsDto> GetStatsAsync()
    {
        var todayUtc = DateTime.UtcNow.Date;

        var totalUsers = await _db.Users.CountAsync();
        var todaySignups = await _db.Users
            .Where(u => u.CreatedAtUtc >= todayUtc)
            .CountAsync();

        var activeJobStatuses = new[]
        {
            JobStatus.Requested, JobStatus.Matching, JobStatus.Matched,
            JobStatus.Confirmed, JobStatus.InProgress
        };

        var activeJobs = await _db.Jobs
            .Where(j => activeJobStatuses.Contains(j.Status))
            .CountAsync();

        var pendingDisputes = await _db.Jobs
            .Where(j => j.IsFlagged && j.DisputeStatus == "Open")
            .CountAsync();

        // Jobs by status
        var jobsByStatus = await _db.Jobs
            .GroupBy(j => j.Status)
            .Select(g => new { Status = g.Key.ToString(), Count = g.Count() })
            .ToListAsync();

        // Signups over last 30 days
        var thirtyDaysAgo = DateTime.UtcNow.AddDays(-30);
        var signupsRaw = await _db.Users
            .Where(u => u.CreatedAtUtc >= thirtyDaysAgo)
            .GroupBy(u => u.CreatedAtUtc.Date)
            .Select(g => new { Date = g.Key, Count = g.Count() })
            .ToListAsync();

        // Fill in zeroes for days with no signups
        var signupsOverTime = new Dictionary<string, int>();
        for (int i = 29; i >= 0; i--)
        {
            var day = DateTime.UtcNow.AddDays(-i).Date;
            var key = day.ToString("yyyy-MM-dd");
            signupsOverTime[key] = signupsRaw.FirstOrDefault(s => s.Date == day)?.Count ?? 0;
        }

        return new AdminStatsDto
        {
            TotalUsers = totalUsers,
            ActiveJobs = activeJobs,
            PendingDisputes = pendingDisputes,
            TodaySignups = todaySignups,
            JobsByStatus = jobsByStatus.ToDictionary(x => x.Status, x => x.Count),
            SignupsOverTime = signupsOverTime,
        };
    }

    // ── Users ──────────────────────────────────────────────────────────────────

    public async Task<PagedResult<AdminUserListItemDto>> GetUsersAsync(
        string? search, string? role, bool? isActive, int page, int pageSize, string? sortBy, bool sortDesc)
    {
        var query = _db.Users.AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var lower = search.ToLower();
            query = query.Where(u =>
                u.FirstName.ToLower().Contains(lower) ||
                u.LastName.ToLower().Contains(lower) ||
                (u.Email != null && u.Email.ToLower().Contains(lower)));
        }

        if (!string.IsNullOrWhiteSpace(role) && Enum.TryParse<UserRole>(role, true, out var parsedRole))
            query = query.Where(u => u.Role == parsedRole);

        if (isActive.HasValue)
            query = query.Where(u => u.IsActive == isActive.Value);

        // Sort
        query = sortBy?.ToLower() switch
        {
            "email" => sortDesc ? query.OrderByDescending(u => u.Email) : query.OrderBy(u => u.Email),
            "role" => sortDesc ? query.OrderByDescending(u => u.Role) : query.OrderBy(u => u.Role),
            "createdat" or "created" => sortDesc
                ? query.OrderByDescending(u => u.CreatedAtUtc)
                : query.OrderBy(u => u.CreatedAtUtc),
            _ => sortDesc ? query.OrderByDescending(u => u.CreatedAtUtc) : query.OrderBy(u => u.CreatedAtUtc),
        };

        var total = await query.CountAsync();

        var users = await query
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        // Load tradie profile IsVerified flags in one query
        var userIds = users.Select(u => u.Id).ToList();
        var tradieProfiles = await _db.TradieProfiles
            .Where(tp => userIds.Contains(tp.UserId))
            .ToDictionaryAsync(tp => tp.UserId);

        var jobCounts = await _db.Jobs
            .Where(j => userIds.Contains(j.HomeownerId))
            .GroupBy(j => j.HomeownerId)
            .Select(g => new { UserId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.UserId, x => x.Count);

        var items = users.Select(u =>
        {
            tradieProfiles.TryGetValue(u.Id, out var tp);
            jobCounts.TryGetValue(u.Id, out var jc);
            return MapToListItem(u, tp, jc);
        }).ToList();

        return new PagedResult<AdminUserListItemDto>
        {
            Items = items,
            TotalCount = total,
            Page = page,
            PageSize = pageSize,
        };
    }

    public async Task<AdminUserDetailDto?> GetUserDetailAsync(string userId)
    {
        var user = await _db.Users.FindAsync(userId);
        if (user is null) return null;

        var tradieProfile = await _db.TradieProfiles.FirstOrDefaultAsync(tp => tp.UserId == userId);

        var jobCount = await _db.Jobs.CountAsync(j => j.HomeownerId == userId);

        var recentJobs = await _db.Jobs
            .Include(j => j.MatchedTradie)
            .Where(j => j.HomeownerId == userId || j.MatchedTradieId == userId)
            .OrderByDescending(j => j.CreatedAtUtc)
            .Take(10)
            .ToListAsync();

        var recentReviews = await _db.Reviews
            .Include(r => r.Reviewer)
            .Where(r => r.RevieweeId == userId)
            .OrderByDescending(r => r.CreatedAtUtc)
            .Take(10)
            .ToListAsync();

        var avgRating = recentReviews.Count > 0 ? recentReviews.Average(r => r.Rating) : 0;

        var dto = new AdminUserDetailDto
        {
            Id = user.Id,
            FullName = user.FullName,
            Email = user.Email ?? string.Empty,
            Role = user.Role.ToString(),
            IsActive = user.IsActive,
            IsVerified = tradieProfile?.IsVerified ?? false,
            CreatedAtUtc = user.CreatedAtUtc,
            JobCount = jobCount,
            TradeType = tradieProfile?.TradeType,
            BusinessName = tradieProfile?.BusinessName,
            AverageRating = Math.Round(avgRating, 1),
            ReviewCount = recentReviews.Count,
            RecentJobs = recentJobs.Select(j => new AdminJobSummaryDto
            {
                Id = j.Id,
                Title = j.Title,
                Category = j.Category.ToString(),
                Status = j.Status.ToString(),
                HomeownerName = user.FullName,
                TradeName = j.MatchedTradie?.FullName,
                CreatedAtUtc = j.CreatedAtUtc,
                UpdatedAtUtc = j.UpdatedAtUtc,
            }).ToList(),
            RecentReviews = recentReviews.Select(r => new AdminReviewSummaryDto
            {
                Id = r.Id,
                JobId = r.JobId,
                ReviewerName = r.Reviewer.FullName,
                Rating = r.Rating,
                Comment = r.Comment,
                CreatedAtUtc = r.CreatedAtUtc,
            }).ToList(),
        };

        return dto;
    }

    public async Task<bool> VerifyUserAsync(string userId)
    {
        var tp = await _db.TradieProfiles.FirstOrDefaultAsync(t => t.UserId == userId);
        if (tp is null)
        {
            _logger.LogWarning("Verify: no TradieProfile found for user {UserId}", userId);
            return false;
        }

        tp.IsVerified = true;
        await _db.SaveChangesAsync();
        _logger.LogInformation("User {UserId} verified by admin", userId);
        return true;
    }

    public async Task<bool> DeactivateUserAsync(string userId)
    {
        var user = await _db.Users.FindAsync(userId);
        if (user is null) return false;

        user.IsActive = false;

        // Revoke all refresh tokens by locking the account via ASP.NET Identity
        await _userManager.SetLockoutEnabledAsync(user, true);
        await _userManager.SetLockoutEndDateAsync(user, DateTimeOffset.MaxValue);

        await _db.SaveChangesAsync();
        _logger.LogInformation("User {UserId} deactivated by admin", userId);
        return true;
    }

    // ── Jobs ───────────────────────────────────────────────────────────────────

    public async Task<PagedResult<AdminJobSummaryDto>> GetJobsAsync(
        string? status, string? search, int page, int pageSize, string? sortBy, bool sortDesc)
    {
        var query = _db.Jobs
            .Include(j => j.Homeowner)
            .Include(j => j.MatchedTradie)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<JobStatus>(status, true, out var parsedStatus))
            query = query.Where(j => j.Status == parsedStatus);

        if (!string.IsNullOrWhiteSpace(search))
        {
            var lower = search.ToLower();
            query = query.Where(j =>
                j.Title.ToLower().Contains(lower) ||
                (j.Address != null && j.Address.ToLower().Contains(lower)));
        }

        query = sortBy?.ToLower() switch
        {
            "status" => sortDesc ? query.OrderByDescending(j => j.Status) : query.OrderBy(j => j.Status),
            "category" => sortDesc ? query.OrderByDescending(j => j.Category) : query.OrderBy(j => j.Category),
            "updatedat" => sortDesc ? query.OrderByDescending(j => j.UpdatedAtUtc) : query.OrderBy(j => j.UpdatedAtUtc),
            _ => sortDesc ? query.OrderByDescending(j => j.CreatedAtUtc) : query.OrderBy(j => j.CreatedAtUtc),
        };

        var total = await query.CountAsync();

        var jobs = await query
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        return new PagedResult<AdminJobSummaryDto>
        {
            Items = jobs.Select(j => new AdminJobSummaryDto
            {
                Id = j.Id,
                Title = j.Title,
                Category = j.Category.ToString(),
                Status = j.Status.ToString(),
                HomeownerName = j.Homeowner.FullName,
                TradeName = j.MatchedTradie?.FullName,
                CreatedAtUtc = j.CreatedAtUtc,
                UpdatedAtUtc = j.UpdatedAtUtc,
            }).ToList(),
            TotalCount = total,
            Page = page,
            PageSize = pageSize,
        };
    }

    public async Task<AdminJobDetailDto?> GetJobDetailAsync(int jobId)
    {
        var job = await _db.Jobs
            .Include(j => j.Homeowner)
            .Include(j => j.MatchedTradie)
            .Include(j => j.Photos)
            .Include(j => j.ChatMessages).ThenInclude(m => m.Sender)
            .Include(j => j.StatusHistory)
            .FirstOrDefaultAsync(j => j.Id == jobId);

        if (job is null) return null;

        // Load changedBy names for status history
        var changedByIds = job.StatusHistory.Select(h => h.ChangedByUserId).Distinct().ToList();
        var changedByUsers = await _db.Users
            .Where(u => changedByIds.Contains(u.Id))
            .ToDictionaryAsync(u => u.Id, u => u.FullName);

        return new AdminJobDetailDto
        {
            Id = job.Id,
            Title = job.Title,
            Category = job.Category.ToString(),
            Status = job.Status.ToString(),
            HomeownerName = job.Homeowner.FullName,
            HomeownerId = job.HomeownerId,
            TradeName = job.MatchedTradie?.FullName,
            MatchedTradieId = job.MatchedTradieId,
            Description = job.Description,
            Urgency = job.Urgency.ToString(),
            Address = job.Address,
            ScheduledDateUtc = job.ScheduledDateUtc,
            ScheduleStatus = job.ScheduleStatus.ToString(),
            CreatedAtUtc = job.CreatedAtUtc,
            UpdatedAtUtc = job.UpdatedAtUtc,
            Photos = job.Photos.Select(p => new JobPhotoDto
            {
                Id = p.Id,
                Url = $"/api/photos/{p.S3Key}",
                OriginalFileName = p.OriginalFileName,
            }).ToList(),
            ChatTranscript = job.ChatMessages
                .OrderBy(m => m.SentAtUtc)
                .Select(m => new AdminChatMessageDto
                {
                    Id = m.Id,
                    SenderId = m.SenderId,
                    SenderName = m.Sender.FullName,
                    Content = m.Content,
                    SentAtUtc = m.SentAtUtc,
                    ReadAtUtc = m.ReadAtUtc,
                }).ToList(),
            StatusHistory = job.StatusHistory
                .OrderBy(h => h.ChangedAtUtc)
                .Select(h => new AdminStatusHistoryDto
                {
                    Id = h.Id,
                    FromStatus = h.FromStatus.ToString(),
                    ToStatus = h.ToStatus.ToString(),
                    ChangedByUserId = h.ChangedByUserId,
                    ChangedByName = changedByUsers.GetValueOrDefault(h.ChangedByUserId),
                    ChangedAtUtc = h.ChangedAtUtc,
                    Reason = h.Reason,
                }).ToList(),
        };
    }

    // ── Disputes ───────────────────────────────────────────────────────────────

    public async Task<PagedResult<AdminDisputeListItemDto>> GetDisputesAsync(
        string? disputeStatus, int page, int pageSize)
    {
        var query = _db.Jobs
            .Include(j => j.Homeowner)
            .Include(j => j.MatchedTradie)
            .Where(j => j.IsFlagged)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(disputeStatus) && disputeStatus != "All")
            query = query.Where(j => j.DisputeStatus == disputeStatus);

        var total = await query.CountAsync();

        var jobs = await query
            .OrderByDescending(j => j.FlaggedAtUtc)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        return new PagedResult<AdminDisputeListItemDto>
        {
            Items = jobs.Select(j => new AdminDisputeListItemDto
            {
                JobId = j.Id,
                JobTitle = j.Title,
                HomeownerName = j.Homeowner.FullName,
                TradieName = j.MatchedTradie?.FullName,
                Status = j.Status.ToString(),
                DisputeStatus = j.DisputeStatus,
                FlagReason = j.FlagReason,
                FlaggedAtUtc = j.FlaggedAtUtc ?? j.UpdatedAtUtc,
            }).ToList(),
            TotalCount = total,
            Page = page,
            PageSize = pageSize,
        };
    }

    public async Task<AdminDisputeDetailDto?> GetDisputeDetailAsync(int jobId)
    {
        var job = await _db.Jobs
            .Include(j => j.Homeowner)
            .Include(j => j.MatchedTradie)
            .Include(j => j.ChatMessages).ThenInclude(m => m.Sender)
            .FirstOrDefaultAsync(j => j.Id == jobId && j.IsFlagged);

        if (job is null) return null;

        var dto = new AdminDisputeDetailDto
        {
            JobId = job.Id,
            JobTitle = job.Title,
            HomeownerName = job.Homeowner.FullName,
            TradieName = job.MatchedTradie?.FullName,
            Status = job.Status.ToString(),
            DisputeStatus = job.DisputeStatus,
            FlagReason = job.FlagReason,
            FlaggedAtUtc = job.FlaggedAtUtc ?? job.UpdatedAtUtc,
            ChatTranscript = job.ChatMessages
                .OrderBy(m => m.SentAtUtc)
                .Select(m => new AdminChatMessageDto
                {
                    Id = m.Id,
                    SenderId = m.SenderId,
                    SenderName = m.Sender.FullName,
                    Content = m.Content,
                    SentAtUtc = m.SentAtUtc,
                    ReadAtUtc = m.ReadAtUtc,
                }).ToList(),
        };

        dto.HomeownerDetail = await GetUserDetailAsync(job.HomeownerId);
        if (job.MatchedTradieId is not null)
            dto.TradieDetail = await GetUserDetailAsync(job.MatchedTradieId);

        return dto;
    }

    public async Task<bool> ResolveDisputeAsync(int jobId, ResolveDisputeRequest request, string adminUserId)
    {
        var job = await _db.Jobs.FindAsync(jobId);
        if (job is null || !job.IsFlagged) return false;

        switch (request.Action)
        {
            case "Resolved":
                job.DisputeStatus = "Resolved";
                break;
            case "Escalated":
                job.DisputeStatus = "Escalated";
                break;
            case "CancelJob":
                var previousStatus = job.Status;
                job.DisputeStatus = "Resolved";
                job.Status = JobStatus.Cancelled;
                _db.JobStatusHistory.Add(new JobStatusHistory
                {
                    JobId = job.Id,
                    FromStatus = previousStatus,
                    ToStatus = JobStatus.Cancelled,
                    ChangedByUserId = adminUserId,
                    Reason = $"[Admin dispute resolution] {request.Note}",
                    ChangedAtUtc = DateTime.UtcNow,
                });
                break;
            default:
                _logger.LogWarning("Unknown dispute action {Action}", request.Action);
                return false;
        }

        job.DisputeNote = request.Note;
        job.UpdatedAtUtc = DateTime.UtcNow;

        await _db.SaveChangesAsync();
        _logger.LogInformation("Dispute for job {JobId} resolved with action {Action} by admin {AdminId}",
            jobId, request.Action, adminUserId);
        return true;
    }

    // ── Settings ───────────────────────────────────────────────────────────────

    public Task<AdminSettingsDto> GetSettingsAsync()
    {
        var locale = _locale.Value;
        return Task.FromResult(new AdminSettingsDto
        {
            Currency = locale.DefaultCurrency,
            CurrencySymbol = locale.CurrencySymbol,
            Timezone = locale.DefaultTimezone,
            PhoneFormat = locale.PhoneCountryCode,
            DefaultMatchRadiusKm = 25m,
            FeatureChatEnabled = true,
            FeatureReviewsEnabled = true,
            FeatureSchedulingEnabled = true,
        });
    }

    public async Task<AdminSettingsDto> UpdateSettingsAsync(AdminSettingsDto dto)
    {
        var locale = _locale.Value;
        locale.DefaultCurrency = dto.Currency;
        locale.CurrencySymbol = dto.CurrencySymbol;
        locale.DefaultTimezone = dto.Timezone;
        locale.PhoneCountryCode = dto.PhoneFormat;

        await Task.CompletedTask;
        _logger.LogInformation("Admin updated locale settings: currency={Currency}, tz={Tz}",
            dto.Currency, dto.Timezone);

        return dto;
    }

    // ── Metrics ────────────────────────────────────────────────────────────────

    public async Task<AdminMetricsDto> GetMetricsAsync()
    {
        return new AdminMetricsDto
        {
            Last7Days  = await CalculateMetricsAsync(DateTime.UtcNow.AddDays(-7)),
            Last30Days = await CalculateMetricsAsync(DateTime.UtcNow.AddDays(-30)),
            AllTime    = await CalculateMetricsAsync(DateTime.MinValue),
        };
    }

    private async Task<MetricsWindowDto> CalculateMetricsAsync(DateTime windowStart)
    {
        // ── Total signups in window ────────────────────────────────────────────
        var signups = await _db.Users
            .Where(u => u.CreatedAtUtc >= windowStart)
            .ToListAsync();

        var signupIds = signups.Select(u => u.Id).ToHashSet();
        int totalSignups = signups.Count;

        // ── Activation rate: signups → first job within 24h ───────────────────
        int activatedCount = 0;
        if (signupIds.Count > 0)
        {
            var firstJobTimes = await _db.Jobs
                .Where(j => signupIds.Contains(j.HomeownerId))
                .GroupBy(j => j.HomeownerId)
                .Select(g => new { UserId = g.Key, FirstJobAt = g.Min(j => j.CreatedAtUtc) })
                .ToListAsync();

            var signupTimeByUser = signups.ToDictionary(u => u.Id, u => u.CreatedAtUtc);

            activatedCount = firstJobTimes.Count(x =>
                signupTimeByUser.TryGetValue(x.UserId, out var signupAt) &&
                (x.FirstJobAt - signupAt).TotalHours <= 24);
        }

        double activationRate = totalSignups > 0
            ? Math.Round((double)activatedCount / totalSignups * 100, 1)
            : 0;

        // ── Match-to-confirmation time ────────────────────────────────────────
        // Find jobs created in window that reached Confirmed status
        var confirmedTransitions = await _db.JobStatusHistory
            .Include(h => h.Job)
            .Where(h =>
                h.ToStatus == JobStatus.Confirmed &&
                h.ChangedAtUtc >= windowStart &&
                h.Job.CreatedAtUtc >= windowStart)
            .ToListAsync();

        double avgMatchToConfirmHours = 0;
        if (confirmedTransitions.Count > 0)
        {
            var totalHours = confirmedTransitions
                .Sum(h => (h.ChangedAtUtc - h.Job.CreatedAtUtc).TotalHours);
            avgMatchToConfirmHours = Math.Round(totalHours / confirmedTransitions.Count, 1);
        }

        // ── Tradie response rate ──────────────────────────────────────────────
        // Jobs that reached Matched status (notification sent) in window
        var matchedJobs = await _db.Jobs
            .Where(j => j.Status != JobStatus.Draft &&
                        j.Status != JobStatus.Requested &&
                        j.CreatedAtUtc >= windowStart)
            .ToListAsync();

        int totalMatched = matchedJobs.Count;
        // A response is when job moved past Matched to Confirmed or Cancelled
        int responded = matchedJobs.Count(j =>
            j.Status == JobStatus.Confirmed ||
            j.Status == JobStatus.InProgress ||
            j.Status == JobStatus.Complete ||
            j.Status == JobStatus.Cancelled);

        double tradieResponseRate = totalMatched > 0
            ? Math.Round((double)responded / totalMatched * 100, 1)
            : 0;

        // ── Review completion rate ─────────────────────────────────────────────
        var completedJobs = await _db.Jobs
            .Include(j => j.Reviews)
            .Where(j => j.Status == JobStatus.Complete && j.CreatedAtUtc >= windowStart)
            .ToListAsync();

        int totalCompleted = completedJobs.Count;
        int bothReviewed = completedJobs.Count(j => j.Reviews.Count >= 2);

        double reviewCompletionRate = totalCompleted > 0
            ? Math.Round((double)bothReviewed / totalCompleted * 100, 1)
            : 0;

        // ── Total jobs in window ──────────────────────────────────────────────
        var totalJobs = await _db.Jobs.CountAsync(j => j.CreatedAtUtc >= windowStart);

        return new MetricsWindowDto
        {
            ActivationRatePct = activationRate,
            AvgMatchToConfirmationHours = avgMatchToConfirmHours,
            TradieResponseRatePct = tradieResponseRate,
            ReviewCompletionRatePct = reviewCompletionRate,
            TotalJobs = totalJobs,
            TotalSignups = totalSignups,
        };
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    private static AdminUserListItemDto MapToListItem(
        ApplicationUser u, TradieProfile? tp, int jobCount) =>
        new()
        {
            Id = u.Id,
            FullName = u.FullName,
            Email = u.Email ?? string.Empty,
            Role = u.Role.ToString(),
            IsActive = u.IsActive,
            IsVerified = tp?.IsVerified ?? false,
            CreatedAtUtc = u.CreatedAtUtc,
            JobCount = jobCount,
        };
}
