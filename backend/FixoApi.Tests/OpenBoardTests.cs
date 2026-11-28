using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Email;
using FixoApi.Enums;
using FixoApi.Hubs;
using FixoApi.Jobs;
using FixoApi.Models;
using FixoApi.Options;
using FixoApi.Services;
using Hangfire;
using Hangfire.Common;
using Hangfire.States;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using NetTopologySuite.Geometries;
using Xunit;
using Job = FixoApi.Models.Job;

namespace FixoApi.Tests;

/// <summary>
/// Plan 10 (Q7.4–Q7.7, Q7.13): open project board backend tests.
/// Uses EF Core InMemoryDatabase with fake push/email/status/hangfire.
/// </summary>
public class OpenBoardTests
{
    // Auckland CBD (-36.8485, 174.7633)
    private static Point Akl(double latOffset = 0, double lngOffset = 0) =>
        new(174.7633 + lngOffset, -36.8485 + latOffset) { SRID = 4326 };

    private static FixoDbContext MakeDb() =>
        new(new DbContextOptionsBuilder<FixoDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options);

    private static IConfiguration MakeConfig(int cap = 50, double radiusKm = 25.0) =>
        new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Matching:RadiusKm"] = radiusKm.ToString(System.Globalization.CultureInfo.InvariantCulture),
                ["Matching:BoardNotifyCap"] = cap.ToString(),
            })
            .Build();

    private sealed class NoopHangfire : IBackgroundJobClient
    {
        public string Create(Hangfire.Common.Job job, IState state) => "job-1";
        public bool ChangeState(string jobId, IState state, string? expectedState) => true;
    }

    private sealed class RecordingAudit : IAuditLogService
    {
        public List<string> Actions { get; } = [];
        public Task LogAsync(string? userId, string action, string? entityType = null,
            string? entityId = null, object? oldValues = null, object? newValues = null,
            string? ipAddress = null, CancellationToken ct = default)
        {
            Actions.Add(action);
            return Task.CompletedTask;
        }
        public Task<PagedResult<AuditLogDto>> QueryAsync(DateTime? fromUtc, DateTime? toUtc,
            string? action, string? userId, int page, int pageSize, CancellationToken ct = default)
            => throw new NotSupportedException();
    }

    private sealed class FakeJobStatusService : IJobStatusService
    {
        private readonly FixoDbContext _db;
        public FakeJobStatusService(FixoDbContext db) => _db = db;

        public async Task<JobDto> TransitionAsync(int jobId, JobStatus newStatus, string userId,
            UserRole actorRole, ReasonCode? reasonCode = null, string? note = null)
        {
            var job = await _db.Jobs.FindAsync(jobId) ?? throw new KeyNotFoundException();
            job.Status = newStatus;
            await _db.SaveChangesAsync();
            return new JobDto { Id = job.Id, Status = job.Status.ToString() };
        }

        public Task<JobDto> CancelJobAsync(int jobId, string userId, UserRole actorRole, CancelJobRequest request)
            => throw new NotSupportedException();

        public Task<JobDto> ReportNoShowAsync(int jobId, string userId, UserRole actorRole, ReportNoShowRequest request)
            => throw new NotSupportedException();

        public Task RecordFlagAsync(int jobId, string userId, string reason, CancellationToken ct = default)
            => Task.CompletedTask;
    }

    private sealed class RecordingNotifications : INotificationService
    {
        public List<(string EventKey, string UserId)> Sent { get; } = [];
        public List<(string EventKey, IReadOnlyCollection<string> UserIds)> BatchSent { get; } = [];

        public Task SendToUserAsync(string userId, string title, string body, Dictionary<string, string>? data = null,
            bool critical = false, string? emailSubject = null, string? emailBody = null, CancellationToken ct = default)
        {
            Sent.Add((data != null && data.TryGetValue("type", out var t) ? t : "direct", userId));
            return Task.CompletedTask;
        }

        public Task SendToUserAsync(string userId, string title, string body, Dictionary<string, string>? data,
            CriticalNoticeModel emailNotice, bool critical = false, CancellationToken ct = default)
            => SendToUserAsync(userId, title, body, data, critical, ct: ct);

        public Task<bool> SendPushToUserAsync(string userId, string title, string body,
            Dictionary<string, string>? data = null, CancellationToken ct = default)
            => Task.FromResult(true);

        public Task NotifyAsync(string eventKey, string userId, string title, string body,
            Dictionary<string, string>? data = null, CriticalNoticeModel? emailNotice = null, CancellationToken ct = default)
        {
            Sent.Add((eventKey, userId));
            return Task.CompletedTask;
        }

        public Task NotifyManyAsync(string eventKey, IReadOnlyCollection<string> userIds, string title, string body,
            Dictionary<string, string>? data = null, CriticalNoticeModel? emailNotice = null, CancellationToken ct = default)
        {
            BatchSent.Add((eventKey, userIds.ToList()));
            return Task.CompletedTask;
        }

        public Task SendToStaffAsync(StaffAlert alert, CancellationToken ct = default) => Task.CompletedTask;
    }

    private sealed class StubHubContext : IHubContext<JobHub>
    {
        public IHubClients Clients => throw new NotImplementedException();
        public IGroupManager Groups => throw new NotImplementedException();
    }

    private static async Task<(FixoDbContext Db, int ServiceId, int LicencedServiceId)> SeedBasicAsync(FixoDbContext db)
    {
        var plumbing = new Service { Id = 1, Name = "Plumbing", Category = TradeCategory.Plumber, RequiresLicence = false };
        var electrical = new Service { Id = 2, Name = "Electrical", Category = TradeCategory.Electrician, RequiresLicence = true };
        db.Services.AddRange(plumbing, electrical);

        db.Users.AddRange(
            new ApplicationUser { Id = "ho-1", UserName = "ho-1", Email = "ho@test.nz", FirstName = "H", LastName = "O" },
            new ApplicationUser { Id = "tr-1", UserName = "tr-1", Email = "tr1@test.nz", FirstName = "T", LastName = "One" },
            new ApplicationUser { Id = "tr-far", UserName = "tr-far", Email = "trfar@test.nz", FirstName = "T", LastName = "Far" },
            new ApplicationUser { Id = "tr-blocked", UserName = "tr-blocked", Email = "trblk@test.nz", FirstName = "T", LastName = "Blk" });

        var tp1 = new TradieProfile { Id = 10, UserId = "tr-1", IsVerified = true, IsAvailable = true, IsGstRegistered = true, Location = Akl(), TradeType = "Plumbing" };
        var tpFar = new TradieProfile { Id = 11, UserId = "tr-far", IsVerified = true, IsAvailable = true, IsGstRegistered = false, Location = Akl(latOffset: 1.0), TradeType = "Plumbing" }; // ~111 km away
        var tpBlk = new TradieProfile { Id = 12, UserId = "tr-blocked", IsVerified = true, IsAvailable = true, IsGstRegistered = false, Location = Akl(), TradeType = "Plumbing" };
        db.TradieProfiles.AddRange(tp1, tpFar, tpBlk);

        db.TradieRates.AddRange(
            new TradieRate { TradieProfileId = 10, ServiceId = 1, HourlyRate = 90m },
            new TradieRate { TradieProfileId = 10, ServiceId = 2, HourlyRate = 110m },
            new TradieRate { TradieProfileId = 11, ServiceId = 1, HourlyRate = 90m },
            new TradieRate { TradieProfileId = 12, ServiceId = 1, HourlyRate = 90m });

        db.UserBlocks.Add(new UserBlock { BlockerId = "ho-1", BlockedId = "tr-blocked" });
        await db.SaveChangesAsync();
        return (db, 1, 2);
    }

    // ── Q7.4 AvailableJobsService ────────────────────────────────────────────

    [Fact]
    public async Task AvailableJobs_filters_eligibility_and_masks_address()
    {
        using var db = MakeDb();
        await SeedBasicAsync(db);
        var now = DateTime.UtcNow;

        db.Jobs.AddRange(
            // Eligible open board job
            new Job { Id = 1, HomeownerId = "ho-1", Title = "Rewire kitchen", Category = TradeCategory.Plumber, JobType = JobType.Project, Status = JobStatus.Requested, OpenToBoard = true, QuotesCloseAtUtc = now.AddHours(48), ServiceId = 1, Location = Akl(0.01, 0.01), Address = "Ponsonby, Auckland" },
            // Hourly job (excluded)
            new Job { Id = 2, HomeownerId = "ho-1", Title = "Hourly tap", Category = TradeCategory.Plumber, JobType = JobType.Hourly, Status = JobStatus.Requested, OpenToBoard = true, QuotesCloseAtUtc = now.AddHours(48), ServiceId = 1, Location = Akl(0.01, 0.01) },
            // Invite-only project (excluded)
            new Job { Id = 3, HomeownerId = "ho-1", Title = "Invite only", Category = TradeCategory.Plumber, JobType = JobType.Project, Status = JobStatus.Requested, OpenToBoard = false, ServiceId = 1, Location = Akl(0.01, 0.01) },
            // Closed window (excluded)
            new Job { Id = 4, HomeownerId = "ho-1", Title = "Closed", Category = TradeCategory.Plumber, JobType = JobType.Project, Status = JobStatus.Requested, OpenToBoard = true, QuotesCloseAtUtc = now.AddMinutes(-1), ServiceId = 1, Location = Akl(0.01, 0.01) },
            // Requires licence (tr-1 has none yet -> excluded)
            new Job { Id = 5, HomeownerId = "ho-1", Title = "Switchboard", Category = TradeCategory.Electrician, JobType = JobType.Project, Status = JobStatus.Requested, OpenToBoard = true, QuotesCloseAtUtc = now.AddHours(48), ServiceId = 2, Location = Akl(0.01, 0.01) },
            // Already quoted by tr-1 (excluded)
            new Job { Id = 6, HomeownerId = "ho-1", Title = "Already quoted", Category = TradeCategory.Plumber, JobType = JobType.Project, Status = JobStatus.Requested, OpenToBoard = true, QuotesCloseAtUtc = now.AddHours(48), ServiceId = 1, Location = Akl(0.01, 0.01) }
        );
        db.Quotes.Add(new Quote { JobId = 6, TradieId = "tr-1", PricingModel = QuotePricingModel.Fixed, Amount = 500m, Status = QuoteStatus.Submitted, ValidUntilUtc = now.AddHours(24) });
        await db.SaveChangesAsync();

        var sut = new AvailableJobsService(db, MakeConfig(), NullLogger<AvailableJobsService>.Instance);

        var res = await sut.GetAvailableJobsAsync("tr-1", 1, 20);
        Assert.Single(res.Items);
        Assert.Equal(1, res.Items[0].Id);
        Assert.Equal("Ponsonby", res.Items[0].Suburb);

        // Far tradie sees 0
        var farRes = await sut.GetAvailableJobsAsync("tr-far", 1, 20);
        Assert.Empty(farRes.Items);

        // Blocked tradie sees 0
        var blkRes = await sut.GetAvailableJobsAsync("tr-blocked", 1, 20);
        Assert.Empty(blkRes.Items);
    }

    [Fact]
    public async Task AvailableJobs_is_empty_for_unverified_or_deactivated_tradies()
    {
        using var db = MakeDb();
        await SeedBasicAsync(db);
        db.Jobs.Add(new Job { Id = 1, HomeownerId = "ho-1", Title = "Open", Category = TradeCategory.Plumber, JobType = JobType.Project, Status = JobStatus.Requested, OpenToBoard = true, QuotesCloseAtUtc = DateTime.UtcNow.AddHours(48), ServiceId = 1, Location = Akl(0.01, 0.01) });
        await db.SaveChangesAsync();
        var sut = new AvailableJobsService(db, MakeConfig(), NullLogger<AvailableJobsService>.Instance);

        Assert.Single((await sut.GetAvailableJobsAsync("tr-1", 1, 20)).Items);

        (await db.TradieProfiles.SingleAsync(p => p.UserId == "tr-1")).IsVerified = false;
        await db.SaveChangesAsync();
        Assert.Empty((await sut.GetAvailableJobsAsync("tr-1", 1, 20)).Items);

        (await db.TradieProfiles.SingleAsync(p => p.UserId == "tr-1")).IsVerified = true;
        (await db.Users.FindAsync("tr-1"))!.IsActive = false;
        await db.SaveChangesAsync();
        Assert.Empty((await sut.GetAvailableJobsAsync("tr-1", 1, 20)).Items);
    }

    [Fact]
    public async Task SubmitQuote_rejects_unverified_and_deactivated_tradies()
    {
        using var db = MakeDb();
        await SeedBasicAsync(db);
        db.Jobs.Add(new Job { Id = 10, HomeownerId = "ho-1", Title = "Open project", Category = TradeCategory.Plumber, JobType = JobType.Project, Status = JobStatus.Requested, OpenToBoard = true, QuotesCloseAtUtc = DateTime.UtcNow.AddHours(24), ServiceId = 1, Location = Akl(0.01, 0.01) });
        await db.SaveChangesAsync();

        var sut = new QuoteService(
            db,
            new FakeJobStatusService(db),
            new StubHubContext(),
            new RecordingNotifications(),
            new NoopHangfire(),
            Microsoft.Extensions.Options.Options.Create(new JobFlowOptions()),
            new PlatformSettings(db, Microsoft.Extensions.Options.Options.Create(new JobFlowOptions()), new RecordingAudit()),
            MakeConfig(),
            NullLogger<QuoteService>.Instance);
        var req = new SubmitQuoteRequest { PricingModel = "Fixed", Amount = 1200m, GstIncluded = true, EstimatedDurationDays = 2 };

        (await db.TradieProfiles.SingleAsync(p => p.UserId == "tr-1")).IsVerified = false;
        await db.SaveChangesAsync();
        await Assert.ThrowsAsync<InvalidOperationException>(() => sut.SubmitQuoteAsync(10, "tr-1", req));

        (await db.TradieProfiles.SingleAsync(p => p.UserId == "tr-1")).IsVerified = true;
        (await db.Users.FindAsync("tr-1"))!.IsActive = false;
        await db.SaveChangesAsync();
        await Assert.ThrowsAsync<InvalidOperationException>(() => sut.SubmitQuoteAsync(10, "tr-1", req));
    }

    // ── Q7.5 Quote without offer ─────────────────────────────────────────────

    [Fact]
    public async Task SubmitQuote_open_board_allows_eligible_tradie_without_offer_and_enforces_gates()
    {
        using var db = MakeDb();
        await SeedBasicAsync(db);
        var now = DateTime.UtcNow;

        db.Jobs.AddRange(
            new Job { Id = 10, HomeownerId = "ho-1", Title = "Open project", Category = TradeCategory.Plumber, JobType = JobType.Project, Status = JobStatus.Requested, OpenToBoard = true, QuotesCloseAtUtc = now.AddHours(24), ServiceId = 1, Location = Akl(0.01, 0.01) },
            new Job { Id = 11, HomeownerId = "ho-1", Title = "Closed board", Category = TradeCategory.Plumber, JobType = JobType.Project, Status = JobStatus.Requested, OpenToBoard = true, QuotesCloseAtUtc = now.AddHours(-1), ServiceId = 1, Location = Akl(0.01, 0.01) }
        );
        await db.SaveChangesAsync();

        var settings = new PlatformSettings(db, Microsoft.Extensions.Options.Options.Create(new JobFlowOptions()), new RecordingAudit());
        var sut = new QuoteService(
            db,
            new FakeJobStatusService(db),
            new StubHubContext(),
            new RecordingNotifications(),
            new NoopHangfire(),
            Microsoft.Extensions.Options.Options.Create(new JobFlowOptions()),
            settings,
            MakeConfig(),
            NullLogger<QuoteService>.Instance);

        var req = new SubmitQuoteRequest { PricingModel = "Fixed", Amount = 1200m, GstIncluded = true, EstimatedDurationDays = 2 };

        // Succeeds without an offer; OfferId stays null
        var dto = await sut.SubmitQuoteAsync(10, "tr-1", req);
        Assert.Equal(10, dto.JobId);
        var saved = await db.Quotes.FirstAsync(q => q.Id == dto.Id);
        Assert.Null(saved.OfferId);

        // Duplicate quote rejected
        await Assert.ThrowsAsync<InvalidOperationException>(() => sut.SubmitQuoteAsync(10, "tr-1", req));

        // Out-of-radius tradie rejected
        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            sut.SubmitQuoteAsync(10, "tr-far", new SubmitQuoteRequest { PricingModel = "Fixed", Amount = 1000m, GstIncluded = false }));

        // Blocked tradie rejected
        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            sut.SubmitQuoteAsync(10, "tr-blocked", new SubmitQuoteRequest { PricingModel = "Fixed", Amount = 1000m, GstIncluded = false }));

        // Closed board rejected
        await Assert.ThrowsAsync<InvalidOperationException>(() => sut.SubmitQuoteAsync(11, "tr-1", req));
    }

    // ── Q7.6 Board expiry ────────────────────────────────────────────────────

    [Fact]
    public async Task ExpireBoardJobs_expires_closed_board_with_no_valid_quotes_only()
    {
        using var db = MakeDb();
        await SeedBasicAsync(db);
        var now = DateTime.UtcNow;

        db.Jobs.AddRange(
            // Closed, no quotes -> should expire
            new Job { Id = 20, HomeownerId = "ho-1", Title = "No quotes", Category = TradeCategory.Plumber, JobType = JobType.Project, Status = JobStatus.Requested, OpenToBoard = true, QuotesCloseAtUtc = now.AddMinutes(-10), ServiceId = 1 },
            // Closed, has valid quote -> should stay Requested
            new Job { Id = 21, HomeownerId = "ho-1", Title = "Has quote", Category = TradeCategory.Plumber, JobType = JobType.Project, Status = JobStatus.Requested, OpenToBoard = true, QuotesCloseAtUtc = now.AddMinutes(-10), ServiceId = 1 }
        );
        db.Quotes.Add(new Quote { JobId = 21, TradieId = "tr-1", PricingModel = QuotePricingModel.Fixed, Amount = 800m, Status = QuoteStatus.Submitted, ValidUntilUtc = now.AddHours(12) });
        await db.SaveChangesAsync();

        var notify = new RecordingNotifications();
        var audit = new RecordingAudit();
        var services = new ServiceCollection()
            .AddSingleton(db)
            .AddSingleton<IJobStatusService>(new FakeJobStatusService(db))
            .AddSingleton<INotificationService>(notify)
            .AddSingleton<IAuditLogService>(audit)
            .BuildServiceProvider();

        var worker = new ExpirationWorker(
            services,
            MakeConfig(),
            Microsoft.Extensions.Options.Options.Create(new BrandOptions()),
            NullLogger<ExpirationWorker>.Instance);

        var count = await worker.ExpireBoardJobsAsync(CancellationToken.None);
        Assert.Equal(1, count);

        Assert.Equal(JobStatus.Expired, (await db.Jobs.FindAsync(20))!.Status);
        Assert.Equal(JobStatus.Requested, (await db.Jobs.FindAsync(21))!.Status);
        Assert.Contains(notify.Sent, s => s.EventKey == NotificationEvents.BoardJobExpired && s.UserId == "ho-1");
    }

    // ── Q7.7 BoardJobNotifyJob ───────────────────────────────────────────────

    [Fact]
    public async Task BoardJobNotifyJob_batches_eligible_tradies_and_respects_cap()
    {
        using var db = MakeDb();
        await SeedBasicAsync(db);
        var now = DateTime.UtcNow;

        db.Jobs.Add(new Job
        {
            Id = 30,
            HomeownerId = "ho-1",
            Title = "Bathroom reno",
            Category = TradeCategory.Plumber,
            JobType = JobType.Project,
            Status = JobStatus.Requested,
            OpenToBoard = true,
            QuotesCloseAtUtc = now.AddHours(72),
            ServiceId = 1,
            Location = Akl(0.01, 0.01),
            Address = "Grey Lynn, Auckland",
        });
        await db.SaveChangesAsync();

        var notify = new RecordingNotifications();
        var job = new BoardJobNotifyJob(
            db,
            notify,
            MakeConfig(cap: 1),
            Microsoft.Extensions.Options.Options.Create(new BrandOptions()),
            NullLogger<BoardJobNotifyJob>.Instance);

        await job.ExecuteAsync(30);

        Assert.Single(notify.BatchSent);
        var (eventKey, recipients) = notify.BatchSent[0];
        Assert.Equal(NotificationEvents.BoardJobPosted, eventKey);
        Assert.Equal(new[] { "tr-1" }, recipients);
    }
}
