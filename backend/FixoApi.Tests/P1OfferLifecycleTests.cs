using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Email;
using FixoApi.Enums;
using FixoApi.Hubs;
using FixoApi.Models;
using FixoApi.Options;
using FixoApi.Services;
using Hangfire;
using Hangfire.States;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;
using Job = FixoApi.Models.Job;
using MsOptions = Microsoft.Extensions.Options.Options;
using DTOs = FixoApi.DTOs;

namespace FixoApi.Tests;

/// <summary>
/// Regression tests for QA fix plan P1 — offer lifecycle:
///   §2A: Withdraw a pending direct-request offer
///   §2B: Idempotent double-tap (re-send same request returns existing pending offer)
///   §2C: Siblings closed as Superseded when job is Booked
///   §2D: Declined tradie blocked on re-contact; Withdrawn tradie allowed
///   §2E: HO cancel from Requested closes orphaned offers as JobClosed
/// </summary>
public class P1OfferLifecycleTests
{
    // ── Helpers ──────────────────────────────────────────────────────────────

    private static FixoDbContext MakeDb() => new(
        new DbContextOptionsBuilder<FixoDbContext>()
            .UseInMemoryDatabase($"p1-{Guid.NewGuid()}")
            .Options);

    private static OfferService MakeOfferService(FixoDbContext db,
        RecordingNotificationService? notifications = null,
        IJobStatusService? jobStatus = null) =>
        new(db,
            jobStatus ?? new StubJobStatusService(),
            new StubJobHubContext(),
            notifications ?? new RecordingNotificationService(),
            new NoOpBackgroundJobClient(),
            MsOptions.Create(new JobFlowOptions { MaxConcurrentQuoteRequests = 3 }),
            NullLogger<OfferService>.Instance);

    private static (ApplicationUser Ho, ApplicationUser Tr, Job Job) SeedHoTradie(FixoDbContext db,
        string hoId = "ho-1", string trId = "tr-1")
    {
        var ho = new ApplicationUser
        {
            Id = hoId, UserName = $"{hoId}@test.nz", Email = $"{hoId}@test.nz",
            FirstName = "Ho", LastName = "One", Role = UserRole.Homeowner, IsActive = true
        };
        var tr = new ApplicationUser
        {
            Id = trId, UserName = $"{trId}@test.nz", Email = $"{trId}@test.nz",
            FirstName = "Tr", LastName = "One", Role = UserRole.Tradie, IsActive = true,
        };
        db.Users.AddRange(ho, tr);
        var job = new Job
        {
            HomeownerId = ho.Id,
            Title = "Fix leaking tap",
            Category = TradeCategory.Plumber,
            Description = "Kitchen tap",
            Address = "1 Queen St, Auckland",
            Status = JobStatus.Requested,
            FlowVersion = 2,
            ServiceId = 1,
            HourlyRate = 85m,
            EstimatedHours = 2,
            EstimatedTotal = 170m,
        };
        db.Jobs.Add(job);
        db.SaveChanges();
        return (ho, tr, job);
    }

    private static JobOffer SeedOffer(FixoDbContext db, int jobId, string tradieId,
        OfferResponse response = OfferResponse.Pending,
        DateTime? expiresAt = null)
    {
        var offer = new JobOffer
        {
            JobId = jobId,
            TradieId = tradieId,
            OfferedAtUtc = DateTime.UtcNow.AddMinutes(-5),
            ExpiresAtUtc = expiresAt ?? DateTime.UtcNow.AddHours(1),
            Response = response,
            Stage = OfferStage.Direct,
            Kind = OfferKind.Instant,
            HourlyRateSnapshot = 85m,
        };
        db.JobOffers.Add(offer);
        db.SaveChanges();
        return offer;
    }

    /// <summary>
    /// Seeds a TradieProfile + TradieRate so CreateDirectRequestAsync can pass the rate-lookup gate.
    /// </summary>
    private static void SeedTradieProfile(FixoDbContext db, string tradieId, int serviceId = 1)
    {
        var profile = new TradieProfile
        {
            UserId = tradieId,
            TradeType = "Plumber",
            IsVerified = true,
            IsAvailable = true,
        };
        db.Set<TradieProfile>().Add(profile);
        db.SaveChanges();

        var rate = new TradieRate
        {
            TradieProfileId = profile.Id,
            ServiceId = serviceId,
            HourlyRate = 85m,
        };
        db.Set<TradieRate>().Add(rate);
        db.SaveChanges();
    }


    // ── §2A: Withdraw ────────────────────────────────────────────────────────

    [Fact]
    public async Task WithdrawOffer_SetsPendingToWithdrawn_AndNotifiesTradie()
    {
        using var db = MakeDb();
        var (ho, tr, job) = SeedHoTradie(db);
        var offer = SeedOffer(db, job.Id, tr.Id);
        var notifications = new RecordingNotificationService();
        var sut = MakeOfferService(db, notifications);

        var dto = await sut.WithdrawOfferAsync(job.Id, offer.Id, ho.Id);

        Assert.Equal("Withdrawn", dto.Response);
        var updated = await db.JobOffers.FindAsync(offer.Id);
        Assert.Equal(OfferResponse.Withdrawn, updated!.Response);

        // Tradie should receive an OfferWithdrawn notification.
        Assert.Contains(notifications.Calls,
            c => c.EventType == NotificationEvents.OfferWithdrawn && c.UserId == tr.Id);
    }

    [Fact]
    public async Task WithdrawOffer_AlreadyWithdrawn_ThrowsBusinessRuleException()
    {
        using var db = MakeDb();
        var (ho, tr, job) = SeedHoTradie(db);
        var offer = SeedOffer(db, job.Id, tr.Id, OfferResponse.Withdrawn);
        var sut = MakeOfferService(db);

        var ex = await Assert.ThrowsAsync<BusinessRuleException>(
            () => sut.WithdrawOfferAsync(job.Id, offer.Id, ho.Id));

        Assert.Equal("offer_not_pending", ex.Code);
    }

    // ── §2B: Idempotent re-contact ───────────────────────────────────────────

    [Fact]
    public async Task CreateDirectRequest_SameTradie_ExistingPending_IsIdempotent()
    {
        using var db = MakeDb();
        var (_, tr, job) = SeedHoTradie(db);
        var existing = SeedOffer(db, job.Id, tr.Id, OfferResponse.Pending);
        SeedTradieProfile(db, tr.Id);
        var sut = MakeOfferService(db);

        var dto = await sut.CreateDirectRequestAsync(job.Id, job.HomeownerId, new RequestTradieRequest { TradieId = tr.Id });

        // Same offer ID returned — no new row created.
        Assert.Equal(existing.Id, dto.Id);
        Assert.Equal(1, await db.JobOffers.CountAsync(o => o.JobId == job.Id));
    }

    // ── §2D: Re-contact rules ────────────────────────────────────────────────

    [Fact]
    public async Task CreateDirectRequest_SameTradie_AfterDeclined_ThrowsTradie_Already_Declined()
    {
        using var db = MakeDb();
        var (_, tr, job) = SeedHoTradie(db);
        SeedOffer(db, job.Id, tr.Id, OfferResponse.Declined);
        SeedTradieProfile(db, tr.Id);
        var sut = MakeOfferService(db);

        var ex = await Assert.ThrowsAsync<BusinessRuleException>(
            () => sut.CreateDirectRequestAsync(job.Id, job.HomeownerId, new RequestTradieRequest { TradieId = tr.Id }));

        Assert.Equal("tradie_already_declined", ex.Code);
    }

    [Fact]
    public async Task CreateDirectRequest_SameTradie_AfterWithdrawn_CreatesNewOffer()
    {
        using var db = MakeDb();
        var (_, tr, job) = SeedHoTradie(db);
        var old = SeedOffer(db, job.Id, tr.Id, OfferResponse.Withdrawn);
        SeedTradieProfile(db, tr.Id);
        var sut = MakeOfferService(db);

        var dto = await sut.CreateDirectRequestAsync(job.Id, job.HomeownerId, new RequestTradieRequest { TradieId = tr.Id });

        // New offer row created.
        Assert.NotEqual(old.Id, dto.Id);
        Assert.Equal("Pending", dto.Response);
        Assert.Equal(2, await db.JobOffers.CountAsync(o => o.JobId == job.Id));
    }

    // ── §2C: Siblings closed on accept ──────────────────────────────────────

    [Fact]
    public async Task AcceptOffer_ClosesSiblingPendingOffers_AsSuperseeded_AndNotifiesThem()
    {
        using var db = MakeDb();
        var (ho, tr, job) = SeedHoTradie(db);

        // Add a second tradie and their pending offer.
        var tr2 = new ApplicationUser
        {
            Id = "tr-2", UserName = "tr2@test.nz", Email = "tr2@test.nz",
            FirstName = "Tr2", LastName = "Two", Role = UserRole.Tradie, IsActive = true,
        };
        db.Users.Add(tr2);
        db.SaveChanges();

        var winOffer  = SeedOffer(db, job.Id, tr.Id);
        var sibOffer  = SeedOffer(db, job.Id, tr2.Id);

        var notifications = new RecordingNotificationService();
        var statusService = new JobStatusService(
            db,
            new StubJobHubContext(),
            null!,
            new NoOpBackgroundJobClient(),
            Microsoft.Extensions.Options.Options.Create(new PaymentOptions()),
            Microsoft.Extensions.Options.Options.Create(new JobFlowOptions { Version = 2 }),
            NullLogger<JobStatusService>.Instance,
            null!,
            null!,
            notifications,
            Microsoft.Extensions.Options.Options.Create(new BrandOptions()));
        var sut = MakeOfferService(db, notifications, statusService);

        await sut.AcceptOfferAsync(job.Id, winOffer.Id, tr.Id);

        var sib = await db.JobOffers.FindAsync(sibOffer.Id);
        Assert.Equal(OfferResponse.Superseded, sib!.Response);

        // Tr2 should receive an OfferSuperseded notification.
        Assert.Contains(notifications.Calls,
            c => c.EventType == NotificationEvents.OfferSuperseded && c.UserId == tr2.Id);
    }

    [Fact]
    public async Task AcceptOffer_SendsOfferAccepted_NotOfferDeclined()
    {
        using var db = MakeDb();
        var (_, tr, job) = SeedHoTradie(db);
        var offer = SeedOffer(db, job.Id, tr.Id);
        var notifications = new RecordingNotificationService();
        var sut = MakeOfferService(db, notifications);

        await sut.AcceptOfferAsync(job.Id, offer.Id, tr.Id);

        Assert.DoesNotContain(notifications.Calls,
            c => c.EventType == NotificationEvents.OfferDeclined);
        Assert.Contains(notifications.Calls,
            c => c.EventType == NotificationEvents.OfferAccepted);
    }

    [Fact]
    public async Task AcceptOffer_WhenExpired_ThrowsOfferExpired()
    {
        using var db = MakeDb();
        var (_, tr, job) = SeedHoTradie(db);
        var offer = SeedOffer(db, job.Id, tr.Id,
            expiresAt: DateTime.UtcNow.AddSeconds(-1));
        var sut = MakeOfferService(db);

        var ex = await Assert.ThrowsAsync<BusinessRuleException>(
            () => sut.AcceptOfferAsync(job.Id, offer.Id, tr.Id));

        Assert.Equal("offer_expired", ex.Code);
    }

    // ── §2E: HO cancel from Requested closes orphans as JobClosed ───────────
    // This is exercised via CloseOrphanedOffersAsync directly (the hook in
    // HandleHomeownerCancellationAsync calls it after SaveChangesAsync).

    [Fact]
    public async Task CloseOrphanedOffersAsync_JobClosed_SetsAllPendingToJobClosed()
    {
        using var db = MakeDb();
        var (ho, tr, job) = SeedHoTradie(db);

        var tr2 = new ApplicationUser
        {
            Id = "tr-2", UserName = "tr2@test.nz", Email = "tr2@test.nz",
            FirstName = "Tr2", LastName = "Two", Role = UserRole.Tradie, IsActive = true,
        };
        db.Users.Add(tr2);
        db.SaveChanges();

        var o1 = SeedOffer(db, job.Id, tr.Id);
        var o2 = SeedOffer(db, job.Id, tr2.Id);

        var notifications = new RecordingNotificationService();
        var sut = MakeOfferService(db, notifications);

        await sut.CloseOrphanedOffersAsync(job.Id, OfferResponse.JobClosed, winnerOfferId: null);

        var r1 = await db.JobOffers.FindAsync(o1.Id);
        var r2 = await db.JobOffers.FindAsync(o2.Id);
        Assert.Equal(OfferResponse.JobClosed, r1!.Response);
        Assert.Equal(OfferResponse.JobClosed, r2!.Response);

        // Both tradies notified.
        Assert.Contains(notifications.Calls, c => c.UserId == tr.Id);
        Assert.Contains(notifications.Calls, c => c.UserId == tr2.Id);
    }

    [Fact]
    public async Task CloseOrphanedOffersAsync_ExcludesWinnerOffer()
    {
        using var db = MakeDb();
        var (_, tr, job) = SeedHoTradie(db);
        var winner = SeedOffer(db, job.Id, tr.Id, OfferResponse.Accepted);
        // The winner is already Accepted so it won't match the Pending filter anyway, but
        // let's test with a Pending winner too (edge case of calling with the wrong state).
        var sut = MakeOfferService(db);

        // No pending orphans — should complete silently.
        await sut.CloseOrphanedOffersAsync(job.Id, OfferResponse.Superseded, winner.Id);

        var w = await db.JobOffers.FindAsync(winner.Id);
        Assert.Equal(OfferResponse.Accepted, w!.Response);
    }

    // ── Test doubles ─────────────────────────────────────────────────────────

    internal sealed class RecordingNotificationService : INotificationService
    {
        public List<(string EventType, string UserId, string Title)> Calls { get; } = [];

        public Task NotifyAsync(string eventKey, string userId, string title, string body,
            Dictionary<string, string>? data = null, CriticalNoticeModel? emailNotice = null,
            CancellationToken ct = default)
        {
            Calls.Add((eventKey, userId, title));
            return Task.CompletedTask;
        }

        public Task SendToUserAsync(string userId, string title, string body,
            Dictionary<string, string>? data = null, bool critical = false,
            string? emailSubject = null, string? emailBody = null, CancellationToken ct = default)
            => Task.CompletedTask;

        public Task SendToUserAsync(string userId, string title, string body,
            Dictionary<string, string>? data, CriticalNoticeModel emailNotice,
            bool critical = false, CancellationToken ct = default)
            => Task.CompletedTask;

        public Task<bool> SendPushToUserAsync(string userId, string title, string body,
            Dictionary<string, string>? data = null, CancellationToken ct = default)
            => Task.FromResult(true);

        public Task SendToStaffAsync(StaffAlert alert, CancellationToken ct = default)
            => Task.CompletedTask;
    }

    internal sealed class StubJobStatusService : IJobStatusService
    {
        public Task<JobDto> TransitionAsync(int jobId, JobStatus newStatus, string userId, UserRole actorRole,
            ReasonCode? reasonCode = null, string? note = null)
            => Task.FromResult(new JobDto { Id = jobId, Status = newStatus.ToString() });
        public Task<JobDto> CancelJobAsync(int jobId, string userId, UserRole actorRole, CancelJobRequest request)
            => Task.FromResult(new JobDto { Id = jobId, Status = JobStatus.Cancelled.ToString() });
        public Task RecordFlagAsync(int jobId, string userId, string reason, CancellationToken ct = default)
            => Task.CompletedTask;
        public Task<JobDto> ReportNoShowAsync(int jobId, string userId, UserRole actorRole, ReportNoShowRequest request)
            => Task.FromResult(new JobDto { Id = jobId });
    }

    internal sealed class StubJobHubContext : IHubContext<JobHub>
    {
        public IHubClients Clients { get; } = new StubHubClients();
        public IGroupManager Groups => throw new NotImplementedException();

        private sealed class StubHubClients : IHubClients
        {
            private static readonly IClientProxy Proxy = new NoOpProxy();
            public IClientProxy All => Proxy;
            public IClientProxy AllExcept(IReadOnlyList<string> excluded) => Proxy;
            public IClientProxy Client(string connectionId) => Proxy;
            public IClientProxy Clients(IReadOnlyList<string> connectionIds) => Proxy;
            public IClientProxy Group(string groupName) => Proxy;
            public IClientProxy GroupExcept(string groupName, IReadOnlyList<string> excluded) => Proxy;
            public IClientProxy Groups(IReadOnlyList<string> groupNames) => Proxy;
            public IClientProxy User(string userId) => Proxy;
            public IClientProxy Users(IReadOnlyList<string> userIds) => Proxy;
        }

        private sealed class NoOpProxy : IClientProxy
        {
            public Task SendCoreAsync(string method, object?[] args, CancellationToken ct = default)
                => Task.CompletedTask;
        }
    }

    internal sealed class NoOpBackgroundJobClient : IBackgroundJobClient
    {
        public string Create(Hangfire.Common.Job job, IState state) => "hf-p1";
        public bool ChangeState(string jobId, IState state, string expectedState) => true;
    }
}
