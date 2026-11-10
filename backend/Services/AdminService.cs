using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using System.Text;

namespace FixoApi.Services;

/// <summary>
/// Admin service — all read/write operations for the admin dashboard.
/// Follows Controller Purity: controllers call this service; no EF in controllers.
/// </summary>
public class AdminService : IAdminService
{
    private readonly FixoDbContext _db;
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly IEmailSender _emailSender;
    private readonly TokenService _tokenService;
    private readonly IBlobStorageService _blob;
    private readonly string _credentialsContainer;
    private readonly IOptions<LocaleOptions> _locale;
    private readonly PushNotificationService _pushNotifications;
    private readonly IAuditLogService _audit;
    private readonly ILogger<AdminService> _logger;

    public AdminService(
        FixoDbContext db,
        UserManager<ApplicationUser> userManager,
        IEmailSender emailSender,
        TokenService tokenService,
        IBlobStorageService blob,
        IConfiguration config,
        IOptions<LocaleOptions> locale,
        PushNotificationService pushNotifications,
        IAuditLogService audit,
        ILogger<AdminService> logger)
    {
        _db = db;
        _userManager = userManager;
        _emailSender = emailSender;
        _tokenService = tokenService;
        _blob = blob;
        _credentialsContainer = config["AzureBlob:CredentialsContainer"] ?? "th-credentials";
        _locale = locale;
        _pushNotifications = pushNotifications;
        _audit = audit;
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
            JobStatus.Requested, JobStatus.Requested, JobStatus.AwaitingPayment,
            JobStatus.Booked, JobStatus.InProgress
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

    public async Task<bool> VerifyUserAsync(string userId, string? adminUserId = null)
    {
        var tp = await _db.TradieProfiles.FirstOrDefaultAsync(t => t.UserId == userId);
        if (tp is null)
        {
            _logger.LogWarning("Verify: no TradieProfile found for user {UserId}", userId);
            return false;
        }

        var before = new { tp.UserId, tp.IsVerified };
        tp.IsVerified = true;
        await _db.SaveChangesAsync();
        await _audit.LogAsync(adminUserId, "user.verify", "TradieProfile", userId, before, new { tp.UserId, tp.IsVerified });
        _logger.LogInformation("User {UserId} verified by admin", userId);
        return true;
    }

    public async Task<bool> DeactivateUserAsync(string userId, string? adminUserId = null)
    {
        var user = await _db.Users.FindAsync(userId);
        if (user is null) return false;

        var before = new { user.Id, user.IsActive };
        user.IsActive = false;

        // Revoke all refresh tokens by locking the account via ASP.NET Identity
        await _userManager.SetLockoutEnabledAsync(user, true);
        await _userManager.SetLockoutEndDateAsync(user, DateTimeOffset.MaxValue);

        await _db.SaveChangesAsync();
        await _audit.LogAsync(adminUserId, "user.deactivate", "ApplicationUser", userId, before, new { user.Id, user.IsActive });

        // P8-06: account suspension is critical — email fallback even without push.
        if (!string.IsNullOrWhiteSpace(user.Email))
        {
            try
            {
                await _emailSender.SendAccountSuspendedAsync(user.Email!, user.FullName);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Suspension email to {Email} failed.", user.Email);
            }
        }
        _logger.LogInformation("User {UserId} deactivated by admin", userId);
        return true;
    }

    // ── Staff invites (P1-05) ─────────────────────────────────────────────────

    public async Task<StaffInviteResult> InviteStaffAsync(StaffInviteRequest request)
    {
        if (request.Role is not (UserRole.Staff or UserRole.Superadmin))
            return new StaffInviteResult { Succeeded = false, Error = "Role must be Staff or Superadmin." };

        var existing = await _userManager.FindByEmailAsync(request.Email);
        if (existing is not null)
        {
            // Already active (or already has a password) — not inviteable.
            if (existing.IsActive || await _userManager.HasPasswordAsync(existing))
                return new StaffInviteResult { Succeeded = false, Conflict = true, Error = "A user with this email already exists." };

            // Pending invite that never completed — rotate the token and resend.
            await SendInviteTokenAsync(existing);
            _logger.LogInformation("Staff invite re-sent to {Email}", request.Email);
            return new StaffInviteResult { Succeeded = true };
        }

        var user = new ApplicationUser
        {
            UserName = request.Email,
            Email = request.Email,
            FirstName = request.FirstName,
            LastName = request.LastName,
            Role = request.Role,
            AuthProvider = "password",
            EmailVerified = false,
            IsActive = false, // activated on set-password
        };

        var result = await _userManager.CreateAsync(user);
        if (!result.Succeeded)
            return new StaffInviteResult
            {
                Succeeded = false,
                Error = string.Join(", ", result.Errors.Select(e => e.Description)),
            };

        await SendInviteTokenAsync(user);
        _logger.LogInformation("Staff invite sent to {Email} with role {Role}", request.Email, request.Role);
        return new StaffInviteResult { Succeeded = true };
    }

    public async Task<SetStaffPasswordResult> SetStaffPasswordAsync(SetStaffPasswordRequest request)
    {
        var user = await _userManager.FindByEmailAsync(request.Email);
        if (user is null)
            return new SetStaffPasswordResult { Succeeded = false, Error = "Invalid email or token." };

        if (user.Role is not (UserRole.Staff or UserRole.Superadmin))
            return new SetStaffPasswordResult { Succeeded = false, Error = "Invalid email or token." };

        if (await _userManager.HasPasswordAsync(user))
            return new SetStaffPasswordResult { Succeeded = false, Error = "Account is already activated. Please log in." };

        string rawToken;
        try
        {
            rawToken = Encoding.UTF8.GetString(WebEncoders.Base64UrlDecode(request.Token));
        }
        catch
        {
            return new SetStaffPasswordResult { Succeeded = false, Error = "Invalid email or token." };
        }

        var result = await _userManager.ResetPasswordAsync(user, rawToken, request.NewPassword);
        if (!result.Succeeded)
            return new SetStaffPasswordResult
            {
                Succeeded = false,
                Error = string.Join(", ", result.Errors.Select(e => e.Description)),
            };

        user.EmailVerified = true;
        user.EmailVerifiedAtUtc = DateTime.UtcNow;
        user.IsActive = true;
        await _userManager.UpdateAsync(user);

        _logger.LogInformation("Staff account activated for {Email}", request.Email);
        return new SetStaffPasswordResult { Succeeded = true, Token = _tokenService.CreateToken(user) };
    }

    private async Task SendInviteTokenAsync(ApplicationUser user)
    {
        var rawToken = await _userManager.GeneratePasswordResetTokenAsync(user);
        var encoded = WebEncoders.Base64UrlEncode(Encoding.UTF8.GetBytes(rawToken));
        await _emailSender.SendStaffInviteAsync(user.Email!, encoded);
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
            ScheduledStart = job.ScheduledStart,
            ScheduleStatus = job.ScheduleStatus.ToString(),
            CreatedAtUtc = job.CreatedAtUtc,
            UpdatedAtUtc = job.UpdatedAtUtc,
            Photos = job.Photos.Select(p => new JobPhotoDto
            {
                Id = p.Id,
                Url = $"/api/photos/{p.BlobKey}",
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

        var before = new { job.Id, Status = job.Status.ToString(), job.DisputeStatus };

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
        await _audit.LogAsync(adminUserId, "dispute.resolve", "Job", jobId.ToString(),
            before, new { job.Id, Status = job.Status.ToString(), job.DisputeStatus, request.Action, request.Note });
        _logger.LogInformation("Dispute for job {JobId} resolved with action {Action} by admin {AdminId}",
            jobId, request.Action, adminUserId);
        return true;
    }

    // ── Credential verification (P1-07) ─────────────────────────────────────────

    public async Task<PagedResult<PendingCredentialDto>> GetPendingCredentialsAsync(int page, int pageSize)
    {
        var query = _db.TradieCredentials
            .Include(c => c.TradieProfile).ThenInclude(tp => tp.User)
            .Where(c => c.Status == CredentialStatus.Pending)
            .OrderBy(c => c.Id);

        var total = await query.CountAsync();

        var creds = await query
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        var items = new List<PendingCredentialDto>();
        foreach (var c in creds)
            items.Add(await MapToPendingCredentialDtoAsync(c));

        return new PagedResult<PendingCredentialDto>
        {
            Items = items,
            TotalCount = total,
            Page = page,
            PageSize = pageSize,
        };
    }

    public async Task<ReviewCredentialResult> ReviewCredentialAsync(
        int credentialId, ReviewCredentialRequest request, string adminUserId)
    {
        if (!Enum.TryParse<CredentialStatus>(request.Status, true, out var status)
            || status == CredentialStatus.Pending)
            return new ReviewCredentialResult { Error = "Status must be Approved or Rejected." };

        var cred = await _db.TradieCredentials
            .Include(c => c.TradieProfile).ThenInclude(tp => tp.User)
            .FirstOrDefaultAsync(c => c.Id == credentialId);

        if (cred is null)
            return new ReviewCredentialResult { NotFound = true };

        if (status == CredentialStatus.Rejected && string.IsNullOrWhiteSpace(request.RejectReason))
            return new ReviewCredentialResult { Error = "RejectReason is required when rejecting." };

        var before = new { cred.Id, Status = cred.Status.ToString(), cred.RejectReason };
        cred.Status = status;
        cred.ReviewedById = adminUserId;
        cred.ReviewedAtUtc = DateTime.UtcNow;
        cred.RejectReason = status == CredentialStatus.Rejected ? request.RejectReason!.Trim() : null;

        // MVP verification rule: a tradie is verified while they hold
        // at least one approved credential. Re-reviewing is allowed, so this
        // also un-verifies when the last approval is revoked.
        // NOTE: the review itself must be saved first — AnyAsync queries the
        // database, not the change tracker, so it would miss the row above.
        await _db.SaveChangesAsync();
        cred.TradieProfile.IsVerified = await _db.TradieCredentials.AnyAsync(c =>
            c.TradieProfileId == cred.TradieProfileId && c.Status == CredentialStatus.Approved);
            
        // P10-09: Insurance Badge logic
        cred.TradieProfile.HasInsurance = await _db.TradieCredentials.AnyAsync(c =>
            c.TradieProfileId == cred.TradieProfileId && c.Type == CredentialType.Insurance && c.Status == CredentialStatus.Approved);
            
        await _db.SaveChangesAsync();

        _logger.LogInformation("Credential {CredentialId} reviewed as {Status} by admin {AdminId}",
            credentialId, status, adminUserId);

        await _audit.LogAsync(adminUserId, "credential.review", "TradieCredential", credentialId.ToString(),
            before, new { cred.Id, Status = cred.Status.ToString(), cred.RejectReason, cred.ReviewedById });

        var dto = await MapToPendingCredentialDtoAsync(cred);
        return new ReviewCredentialResult
        {
            Succeeded = true,
            Credential = new ReviewedCredentialDto
            {
                Id = dto.Id,
                Type = dto.Type,
                TradieUserId = dto.TradieUserId,
                TradieName = dto.TradieName,
                TradieEmail = dto.TradieEmail,
                TradeType = dto.TradeType,
                BusinessName = dto.BusinessName,
                OriginalFileName = dto.OriginalFileName,
                DownloadUrl = dto.DownloadUrl,
                Status = cred.Status.ToString(),
                RejectReason = cred.RejectReason,
                ReviewedById = cred.ReviewedById,
                ReviewedAtUtc = cred.ReviewedAtUtc,
                TradieIsVerified = cred.TradieProfile.IsVerified,
            },
        };
    }

    private async Task<PendingCredentialDto> MapToPendingCredentialDtoAsync(TradieCredential c) =>
        new()
        {
            Id = c.Id,
            Type = c.Type.ToString(),
            TradieUserId = c.TradieProfile.UserId,
            TradieName = c.TradieProfile.User.FullName,
            TradieEmail = c.TradieProfile.User.Email ?? string.Empty,
            TradeType = c.TradieProfile.TradeType,
            BusinessName = c.TradieProfile.BusinessName,
            OriginalFileName = c.OriginalFileName,
            DownloadUrl = (await _blob.GetReadSasUriAsync(
                c.FileKey, _credentialsContainer, TimeSpan.FromMinutes(15))).ToString(),
        };

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

    public async Task<AdminSettingsDto> UpdateSettingsAsync(AdminSettingsDto dto, string? adminUserId = null)
    {
        var before = new AdminSettingsDto
        {
            Currency = _locale.Value.DefaultCurrency,
            CurrencySymbol = _locale.Value.CurrencySymbol,
            Timezone = _locale.Value.DefaultTimezone,
            PhoneFormat = _locale.Value.PhoneCountryCode,
        };
        var locale = _locale.Value;
        locale.DefaultCurrency = dto.Currency;
        locale.CurrencySymbol = dto.CurrencySymbol;
        locale.DefaultTimezone = dto.Timezone;
        locale.PhoneCountryCode = dto.PhoneFormat;

        await Task.CompletedTask;
        _logger.LogInformation("Admin updated locale settings: currency={Currency}, tz={Tz}",
            dto.Currency, dto.Timezone);

        await _audit.LogAsync(adminUserId, "settings.update", "AdminSettings", null, before, dto);

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
                h.ToStatus == JobStatus.Booked &&
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
            .Where(j => j.Status != JobStatus.Requested &&
                        j.Status != JobStatus.Requested &&
                        j.CreatedAtUtc >= windowStart)
            .ToListAsync();

        int totalMatched = matchedJobs.Count;
        // A response is when job moved past Matched to Confirmed or Cancelled
        int responded = matchedJobs.Count(j =>
            j.Status == JobStatus.Booked ||
            j.Status == JobStatus.InProgress ||
            j.Status == JobStatus.Completed ||
            j.Status == JobStatus.Cancelled);

        double tradieResponseRate = totalMatched > 0
            ? Math.Round((double)responded / totalMatched * 100, 1)
            : 0;

        // ── Review completion rate ─────────────────────────────────────────────
        var completedJobs = await _db.Jobs
            .Include(j => j.Reviews)
            .Where(j => j.Status == JobStatus.Completed && j.CreatedAtUtc >= windowStart)
            .ToListAsync();

        int totalCompleted = completedJobs.Count;
        int bothReviewed = completedJobs.Count(j => j.Reviews.Count >= 2);

        double reviewCompletionRate = totalCompleted > 0
            ? Math.Round((double)bothReviewed / totalCompleted * 100, 1)
            : 0;

        // ── P8-08: match → AwaitingPayment time (offer accepted) ───────────────
        var awaitingPaymentTransitions = await _db.JobStatusHistory
            .Include(h => h.Job)
            .Where(h =>
                h.ToStatus == JobStatus.AwaitingPayment &&
                h.ChangedAtUtc >= windowStart &&
                h.Job.CreatedAtUtc >= windowStart)
            .ToListAsync();

        double avgMatchToAwaitingPaymentHours = 0;
        if (awaitingPaymentTransitions.Count > 0)
        {
            var totalHours = awaitingPaymentTransitions
                .Sum(h => (h.ChangedAtUtc - h.Job.CreatedAtUtc).TotalHours);
            avgMatchToAwaitingPaymentHours = Math.Round(totalHours / awaitingPaymentTransitions.Count, 1);
        }

        // ── P8-08: payment verification time (Submitted → Verified/Rejected) ──
        var verifiedPayments = await _db.Payments
            .Where(p => p.SubmittedAtUtc != null
                && p.SubmittedAtUtc >= windowStart
                && (p.VerifiedAtUtc != null || p.Status == PaymentStatus.Rejected))
            .ToListAsync();

        double avgPaymentVerificationHours = 0;
        if (verifiedPayments.Count > 0)
        {
            var totalHours = verifiedPayments.Sum(p =>
                ((p.VerifiedAtUtc ?? p.UpdatedAtUtc) - p.SubmittedAtUtc!.Value).TotalHours);
            avgPaymentVerificationHours = Math.Round(totalHours / verifiedPayments.Count, 1);
        }

        // ── Total jobs in window ──────────────────────────────────────────────
        var totalJobs = await _db.Jobs.CountAsync(j => j.CreatedAtUtc >= windowStart);

        return new MetricsWindowDto
        {
            ActivationRatePct = activationRate,
            AvgMatchToConfirmationHours = avgMatchToConfirmHours,
            AvgMatchToAwaitingPaymentHours = avgMatchToAwaitingPaymentHours,
            AvgPaymentVerificationHours = avgPaymentVerificationHours,
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

    // ── Refunds (P6-04 / P6-05) ───────────────────────────────────────────────

    /// <summary>
    /// Returns a page of refunds with Status == Pending, oldest first.
    /// Includes job and homeowner details for the admin queue view.
    /// </summary>
    public async Task<PagedResult<RefundSummaryDto>> GetPendingRefundsAsync(int page, int pageSize)
    {
        var query = _db.Refunds
            .Include(r => r.Job)
                .ThenInclude(j => j.Homeowner)
            .Where(r => r.Status == RefundStatus.Pending)
            .OrderBy(r => r.CreatedAtUtc);

        var total = await query.CountAsync();

        var items = await query
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        var dtos = items.Select(MapRefundToDto).ToList();
        foreach (var dto in dtos)
        {
            var proofKey = items.FirstOrDefault(r => r.Id == dto.Id)?.ProofFileKey;
            if (!string.IsNullOrEmpty(proofKey))
            {
                try
                {
                    // P8-03: refund proofs live in the private bucket — signed URL only.
                    dto.ProofDownloadUrl = (await _blob.GenerateSignedUrl(
                        proofKey, TimeSpan.FromMinutes(15), _credentialsContainer)).ToString();
                }
                catch { /* best-effort */ }
            }
        }

        return new PagedResult<RefundSummaryDto>
        {
            Items = dtos,
            TotalCount = total,
            Page = page,
            PageSize = pageSize,
        };
    }

    /// <summary>
    /// P6-05: Process a pending refund — update amounts, record proof, mark Processed.
    /// Optionally uploads a proof file (bank transfer screenshot) to blob storage.
    /// Sends a push notification to the homeowner (P6-06).
    /// </summary>
    public async Task<ProcessRefundResult> ProcessRefundAsync(
        Guid refundId,
        ProcessRefundRequest request,
        Stream? proofFile,
        string? proofFileContentType,
        string adminUserId)
    {
        var refund = await _db.Refunds
            .Include(r => r.Job)
                .ThenInclude(j => j.Homeowner)
            .FirstOrDefaultAsync(r => r.Id == refundId);

        if (refund is null)
            return new ProcessRefundResult { NotFound = true };

        if (refund.Status == RefundStatus.Processed)
            return new ProcessRefundResult { Conflict = true, Error = "This refund has already been processed." };

        var refundBefore = new { refund.Id, Status = refund.Status.ToString(), refund.FinalAmount, refund.TransferReference };

        // Upload proof file if provided.
        if (proofFile != null && proofFile.Length > 0 && !string.IsNullOrEmpty(proofFileContentType))
        {
            try
            {
                var ext = proofFileContentType.Contains("pdf") ? ".pdf" : ".jpg";
                var key = $"refunds/{refund.Id}/{Guid.NewGuid()}{ext}";
                await _blob.UploadAsync(proofFile, key, proofFileContentType, _credentialsContainer);
                refund.ProofFileKey = key;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to upload proof file for refund {RefundId}.", refundId);
                // Non-fatal — still allow processing.
            }
        }

        // Apply updated amounts.
        refund.FinalAmount = request.FinalAmount;
        refund.Penalty = request.Penalty;
        refund.HoursWorked = request.HoursWorked;
        refund.HoursWorkedAmount = Math.Round(request.HoursWorked * refund.Job.HourlyRate, 2);
        refund.TransferReference = request.TransferReference;
        refund.Status = RefundStatus.Processed;
        refund.ProcessedAtUtc = DateTime.UtcNow;

        if (Guid.TryParse(adminUserId, out var adminGuid))
            refund.ProcessedBy = adminGuid;

        await _db.SaveChangesAsync();

        // P6-06: Notify the homeowner that their refund has been processed.
        // P8-06: critical event — email fallback when push is disabled/misses.
        var homeownerId = refund.Job.HomeownerId;
        var pushSent = false;
        try
        {
            var tokens = await _db.DeviceTokens
                .Where(dt => dt.UserId == homeownerId)
                .Select(dt => dt.Token)
                .ToListAsync();

            var currency = _locale.Value.DefaultCurrency;
            var amountStr = refund.FinalAmount.ToString("F2");

            foreach (var token in tokens)
            {
                try
                {
                    await _pushNotifications.SendAsync(
                        token,
                        "Your refund has been processed",
                        $"${amountStr} {currency} has been transferred. Reference: {request.TransferReference}",
                        new Dictionary<string, string>
                        {
                            ["jobId"]    = refund.JobId.ToString(),
                            ["refundId"] = refund.Id.ToString(),
                            ["type"]     = "refund_processed",
                        });
                    pushSent = true;
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "FCM push to token for user {UserId} failed.", homeownerId);
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not send refund notification to homeowner {HomeownerId}.", homeownerId);
        }

        if (!pushSent && !string.IsNullOrWhiteSpace(refund.Job.Homeowner.Email))
        {
            try
            {
                await _emailSender.SendRefundProcessedAsync(
                    refund.Job.Homeowner.Email!, refund.Job.Title,
                    refund.FinalAmount, _locale.Value.DefaultCurrency,
                    request.TransferReference);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Refund fallback email to {Email} failed.", refund.Job.Homeowner.Email);
            }
        }

        _logger.LogInformation(
            "Refund {RefundId} processed by admin {AdminUserId}: final=${Amount}, ref={Ref}.",
            refundId, adminUserId, request.FinalAmount, request.TransferReference);

        await _audit.LogAsync(adminUserId, "refund.process", "Refund", refundId.ToString(),
            refundBefore, new { refund.Id, Status = refund.Status.ToString(), refund.FinalAmount, refund.TransferReference });

        var dto = MapRefundToDto(refund);
        if (!string.IsNullOrEmpty(refund.ProofFileKey))
        {
            try
            {
                dto.ProofDownloadUrl = (await _blob.GenerateSignedUrl(
                    refund.ProofFileKey, TimeSpan.FromMinutes(15), _credentialsContainer)).ToString();
            }
            catch { /* best-effort */ }
        }

        return new ProcessRefundResult { Succeeded = true, Refund = dto };
    }

    // ── Audit log (P8-04 / P8-07) ────────────────────────────────────────────

    public Task<PagedResult<AuditLogDto>> GetAuditLogsAsync(
        DateTime? fromUtc, DateTime? toUtc, string? action, string? userId, int page, int pageSize) =>
        _audit.QueryAsync(fromUtc, toUtc, action, userId, page, pageSize);

    private static RefundSummaryDto MapRefundToDto(Refund r) => new()    {
        Id               = r.Id,
        JobId            = r.JobId,
        JobTitle         = r.Job.Title,
        HomeownerName    = r.Job.Homeowner.FullName,
        HomeownerEmail   = r.Job.Homeowner.Email ?? string.Empty,
        PaymentId        = r.PaymentId,
        SuggestedAmount  = r.SuggestedAmount,
        FinalAmount      = r.FinalAmount,
        Penalty          = r.Penalty,
        HoursWorked      = r.HoursWorked,
        HoursWorkedAmount = r.HoursWorkedAmount,
        Status           = r.Status.ToString(),
        CancelReasonCode = r.Job.CancelReasonCode?.ToString(),
        CreatedAtUtc     = r.CreatedAtUtc,
        ProcessedAtUtc   = r.ProcessedAtUtc,
        TransferReference = r.TransferReference,
    };
}
