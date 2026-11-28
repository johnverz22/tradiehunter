using FixoApi.Data;
using FixoApi.Email;
using FixoApi.Enums;
using FixoApi.Models;
using FixoApi.Services;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;
using Job = FixoApi.Models.Job;

namespace FixoApi.Tests;

/// <summary>
/// Admin user page: detail aggregates, deactivate/reactivate notes and emails, warn flags,
/// and flag resolution. Runs on the EF in-memory provider with a real UserManager over it.
/// </summary>
public class AdminUserManagementTests
{
    private static FixoDbContext MakeDb() =>
        new(new DbContextOptionsBuilder<FixoDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options);

    private sealed class RecordingAudit : IAuditLogService
    {
        public List<(string Action, object? After)> Entries { get; } = [];
        public Task LogAsync(string? userId, string action, string? entityType = null, string? entityId = null,
            object? oldValues = null, object? newValues = null, string? ipAddress = null, CancellationToken ct = default)
        {
            Entries.Add((action, newValues));
            return Task.CompletedTask;
        }
        public Task<FixoApi.DTOs.PagedResult<AuditLogDto>> QueryAsync(DateTime? fromUtc, DateTime? toUtc,
            string? action, string? userId, int page, int pageSize, CancellationToken ct = default)
            => throw new NotSupportedException();
    }

    /// <summary>Records what would have been emailed; <see cref="Fail"/> simulates a relay outage.</summary>
    private sealed class RecordingEmail : IEmailSender
    {
        public bool Fail { get; set; }
        public List<string> Suspended { get; } = [];
        public List<CriticalNoticeModel> Notices { get; } = [];

        public Task SendAccountSuspendedAsync(string toEmail, string name)
        {
            if (Fail) throw new InvalidOperationException("smtp down");
            Suspended.Add(toEmail);
            return Task.CompletedTask;
        }

        public Task SendCriticalNoticeAsync(string toEmail, CriticalNoticeModel notice)
        {
            if (Fail) throw new InvalidOperationException("smtp down");
            Notices.Add(notice);
            return Task.CompletedTask;
        }

        public Task SendOtpAsync(string toEmail, string otpCode) => Task.CompletedTask;
        public Task SendStaffInviteAsync(string toEmail, string inviteToken) => Task.CompletedTask;
        public Task SendPaymentVerifiedAsync(string toEmail, string jobTitle, decimal amount, string currency = "NZD", string? tradieName = null, string? reference = null, int? jobId = null) => Task.CompletedTask;
        public Task SendPaymentRejectedAsync(string toEmail, string jobTitle, string reason, DateTime newDeadlineUtc, int? jobId = null) => Task.CompletedTask;
        public Task SendCriticalAsync(string toEmail, string subject, string body) => Task.CompletedTask;
        public Task SendStaffAlertAsync(string toEmail, StaffAlertModel alert, string? entityRef = null) => Task.CompletedTask;
        public Task SendCredentialDecisionAsync(string toEmail, string credentialType, bool approved, string? rejectReason = null, int? credentialId = null) => Task.CompletedTask;
        public Task SendRefundProcessedAsync(string toEmail, string jobTitle, decimal amount, string currency, string reference, int? jobId = null) => Task.CompletedTask;
        public Task SendJobCancelledAsync(string toEmail, string jobTitle, string reason) => Task.CompletedTask;
    }

    private static (AdminService Sut, RecordingEmail Email, RecordingAudit Audit) Build(FixoDbContext db)
    {
        var userManager = new UserManager<ApplicationUser>(
            new UserStore<ApplicationUser>(db),
            Microsoft.Extensions.Options.Options.Create(new IdentityOptions()),
            new PasswordHasher<ApplicationUser>(),
            null!, null!, null!, null!, null!,
            NullLogger<UserManager<ApplicationUser>>.Instance);
        var email = new RecordingEmail();
        var audit = new RecordingAudit();
        var sut = new AdminService(
            db, userManager, email, tokenService: null!, blob: null!,
            photoSigner: null!,
            config: new ConfigurationBuilder().Build(),
            locale: Microsoft.Extensions.Options.Options.Create(new LocaleOptions()),
            notifications: null!, jobStatusService: null!, audit: audit,
            logger: NullLogger<AdminService>.Instance);
        return (sut, email, audit);
    }

    private static ApplicationUser User(string id, UserRole role, bool active = true) => new()
    {
        Id = id, UserName = id, Email = $"{id}@test.nz", FirstName = id, LastName = "Test",
        Role = role, IsActive = active,
    };

    // ── Deactivate / reactivate ──────────────────────────────────────────────

    [Fact]
    public async Task Deactivate_locks_account_revokes_tokens_emails_and_audits_the_note()
    {
        using var db = MakeDb();
        db.Users.Add(User("u1", UserRole.Tradie));
        db.RefreshTokens.Add(new RefreshToken { UserId = "u1", TokenHash = "h", ExpiresAtUtc = DateTime.UtcNow.AddDays(1), CreatedAtUtc = DateTime.UtcNow });
        await db.SaveChangesAsync();
        var (sut, email, audit) = Build(db);

        var result = await sut.DeactivateUserAsync("u1", "  fake licence  ", "admin-1");

        Assert.NotNull(result);
        Assert.True(result!.EmailSent);
        var user = await db.Users.FindAsync("u1");
        Assert.False(user!.IsActive);
        Assert.True(user.LockoutEnd > DateTimeOffset.UtcNow.AddYears(50));
        Assert.NotNull((await db.RefreshTokens.SingleAsync()).ConsumedAtUtc);
        Assert.Equal(["u1@test.nz"], email.Suspended);
        var entry = Assert.Single(audit.Entries, e => e.Action == "user.deactivate");
        Assert.Contains("fake licence", System.Text.Json.JsonSerializer.Serialize(entry.After));
    }

    [Fact]
    public async Task Deactivate_still_succeeds_but_reports_email_failure()
    {
        using var db = MakeDb();
        db.Users.Add(User("u1", UserRole.Homeowner));
        await db.SaveChangesAsync();
        var (sut, email, _) = Build(db);
        email.Fail = true;

        var result = await sut.DeactivateUserAsync("u1", "spam", "admin-1");

        Assert.False(result!.EmailSent);
        Assert.False((await db.Users.FindAsync("u1"))!.IsActive);
    }

    [Fact]
    public async Task Deactivate_unknown_user_returns_null()
    {
        using var db = MakeDb();
        var (sut, _, _) = Build(db);
        Assert.Null(await sut.DeactivateUserAsync("missing", "x", "admin-1"));
        Assert.Null(await sut.ReactivateUserAsync("missing", "x", "admin-1"));
    }

    [Fact]
    public async Task Reactivate_clears_lockout_emails_user_and_audits_the_note()
    {
        using var db = MakeDb();
        db.Users.Add(User("u1", UserRole.Tradie));
        await db.SaveChangesAsync();
        var (sut, email, audit) = Build(db);
        await sut.DeactivateUserAsync("u1", "review", "admin-1");

        var result = await sut.ReactivateUserAsync("u1", "cleared after review", "admin-1");

        Assert.True(result!.EmailSent);
        var user = await db.Users.FindAsync("u1");
        Assert.True(user!.IsActive);
        Assert.Null(user.LockoutEnd);
        var notice = Assert.Single(email.Notices);
        Assert.Contains("reactivated", notice.Heading);
        Assert.DoesNotContain("cleared after review", string.Join(" ", notice.TextBodyLines));
        Assert.Contains(audit.Entries, e => e.Action == "user.reactivate");
    }

    [Fact]
    public async Task Suspend_uses_the_deactivation_path_with_a_prefixed_reason()
    {
        using var db = MakeDb();
        db.Users.Add(User("u1", UserRole.Homeowner));
        await db.SaveChangesAsync();
        var (sut, email, audit) = Build(db);

        await sut.SuspendUserAsync("u1", "abuse", "admin-1");

        Assert.False((await db.Users.FindAsync("u1"))!.IsActive);
        Assert.Single(email.Suspended);
        var entry = Assert.Single(audit.Entries, e => e.Action == "user.deactivate");
        Assert.Contains("Suspended: abuse", System.Text.Json.JsonSerializer.Serialize(entry.After));
    }

    // ── Warn and flags ───────────────────────────────────────────────────────

    [Fact]
    public async Task Warn_creates_a_manual_flag_then_hits_threshold_on_the_third_warning()
    {
        using var db = MakeDb();
        db.Users.Add(User("u1", UserRole.Homeowner));
        await db.SaveChangesAsync();
        var (sut, email, audit) = Build(db);

        await sut.WarnUserAsync("u1", "rude in chat", "admin-1");
        var flag = await db.AccountFlags.SingleAsync();
        Assert.Equal(AccountFlagType.Manual, flag.Type);
        Assert.Equal(1, flag.Counter);
        Assert.False(flag.ThresholdHit);

        await sut.WarnUserAsync("u1", "again", "admin-1");
        await sut.WarnUserAsync("u1", "and again", "admin-1");

        flag = await db.AccountFlags.SingleAsync();
        Assert.Equal(3, flag.Counter);
        Assert.True(flag.ThresholdHit);
        Assert.Equal(3, email.Notices.Count);
        Assert.Contains("rude in chat", email.Notices[0].TextBodyLines.Single(l => l.Contains("rude")));
        Assert.Equal(3, audit.Entries.Count(e => e.Action == "user.warn"));
    }

    [Fact]
    public async Task ResolveFlags_resolves_only_open_flags_of_that_user()
    {
        using var db = MakeDb();
        db.Users.AddRange(User("u1", UserRole.Homeowner), User("u2", UserRole.Homeowner));
        db.AccountFlags.AddRange(
            new AccountFlag { UserId = "u1", Type = AccountFlagType.Manual, Counter = 1 },
            new AccountFlag { UserId = "u1", Type = AccountFlagType.Abuse, Counter = 1 },
            new AccountFlag { UserId = "u1", Type = AccountFlagType.RepeatNoShow, Counter = 1, Resolved = true },
            new AccountFlag { UserId = "u2", Type = AccountFlagType.Manual, Counter = 1 });
        await db.SaveChangesAsync();
        var (sut, _, _) = Build(db);

        var count = await sut.ResolveUserFlagsAsync("u1", "admin-1");

        Assert.Equal(2, count);
        Assert.All(await db.AccountFlags.Where(f => f.UserId == "u1").ToListAsync(), f => Assert.True(f.Resolved));
        Assert.False((await db.AccountFlags.SingleAsync(f => f.UserId == "u2")).Resolved);
        Assert.Null(await sut.ResolveUserFlagsAsync("missing", "admin-1"));
    }

    // ── Detail aggregates ────────────────────────────────────────────────────

    [Fact]
    public async Task Detail_uses_real_homeowner_name_all_reviews_disputes_and_status_note()
    {
        using var db = MakeDb();
        db.Users.AddRange(User("tr", UserRole.Tradie, active: false), User("ho", UserRole.Homeowner), User("rv", UserRole.Homeowner));
        db.TradieProfiles.Add(new TradieProfile { Id = 1, UserId = "tr", TradeType = "Plumbing", IsVerified = true });
        db.Jobs.AddRange(
            new Job { Id = 1, HomeownerId = "ho", MatchedTradieId = "tr", Title = "A", Status = JobStatus.Completed },
            new Job { Id = 2, HomeownerId = "ho", MatchedTradieId = "tr", Title = "B", Status = JobStatus.Booked, IsFlagged = true });

        // 12 reviews (more than the 10 shown) — average must cover all of them: (5*6 + 1*6) / 12 = 3.0
        for (var i = 0; i < 12; i++)
            db.Reviews.Add(new Review { JobId = 1, ReviewerId = "rv", RevieweeId = "tr", Rating = i < 6 ? 5 : 1, CreatedAtUtc = DateTime.UtcNow.AddMinutes(-i) });
        // Removed and not-yet-revealed reviews must not count
        db.Reviews.Add(new Review { JobId = 1, ReviewerId = "ho", RevieweeId = "tr", Rating = 1, Status = ReviewStatus.Removed });
        db.Reviews.Add(new Review { JobId = 2, ReviewerId = "ho", RevieweeId = "tr", Rating = 1, RevealAfterUtc = DateTime.UtcNow.AddDays(1) });

        db.AuditLogs.Add(new AuditLog
        {
            UserId = "ho", Action = "user.deactivate", EntityType = "ApplicationUser", EntityId = "tr",
            NewValues = "{\"reason\":\"licence faked\"}", CreatedAtUtc = DateTime.UtcNow,
        });
        await db.SaveChangesAsync();
        var (sut, _, _) = Build(db);

        var dto = await sut.GetUserDetailAsync("tr");

        Assert.NotNull(dto);
        Assert.Equal(12, dto!.ReviewCount);
        Assert.Equal(3.0, dto.AverageRating);
        Assert.Equal(6, dto.RatingBreakdown["5"]);
        Assert.Equal(6, dto.RatingBreakdown["1"]);
        Assert.Equal(1, dto.CompletedJobCount);
        Assert.Equal(1, dto.DisputeCount);
        Assert.All(dto.RecentJobs, j => Assert.Equal("ho Test", j.HomeownerName));
        Assert.Equal(5, dto.TopReviews.Count);
        Assert.All(dto.TopReviews, r => Assert.Equal(5, r.Rating));
        Assert.Equal("licence faked", dto.Deactivation!.Note);
        Assert.Contains("Account is deactivated.", dto.TradieDetails!.EligibilityIssues);
        Assert.False(dto.TradieDetails.IsOfferable);
    }

    [Fact]
    public async Task Detail_explains_why_a_licence_gated_tradie_is_not_offerable_and_masks_bank_number()
    {
        using var db = MakeDb();
        db.Users.Add(User("tr", UserRole.Tradie));
        db.Services.Add(new Service { Id = 2, Name = "Electrical", Category = TradeCategory.Electrician, RequiresLicence = true });
        db.TradieProfiles.Add(new TradieProfile
        {
            Id = 1, UserId = "tr", TradeType = "Electrician", IsVerified = true, IsAvailable = true,
            Location = new NetTopologySuite.Geometries.Point(174.76, -36.85) { SRID = 4326 },
            BankAccountNumber = "12-3456-7890123-00",
        });
        db.TradieRates.Add(new TradieRate { TradieProfileId = 1, ServiceId = 2, HourlyRate = 90m });
        await db.SaveChangesAsync();
        var (sut, _, _) = Build(db);

        var blocked = (await sut.GetUserDetailAsync("tr"))!.TradieDetails!;
        Assert.False(blocked.IsOfferable);
        Assert.Contains(blocked.EligibilityIssues, i => i.Contains("Licence-gated"));
        Assert.Equal("••••2300", blocked.BankAccountMasked);
        Assert.DoesNotContain("12-3456", blocked.BankAccountMasked);

        db.TradieCredentials.Add(new TradieCredential
        {
            TradieProfileId = 1, Type = CredentialType.License, Status = CredentialStatus.Approved,
            FileKey = "k", OriginalFileName = "licence.pdf",
        });
        await db.SaveChangesAsync();

        var ok = (await sut.GetUserDetailAsync("tr"))!.TradieDetails!;
        Assert.True(ok.IsOfferable);
        Assert.Empty(ok.EligibilityIssues);
    }
}
