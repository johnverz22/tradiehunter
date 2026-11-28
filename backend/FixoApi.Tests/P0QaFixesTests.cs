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
using Hangfire.States;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;
using Job = FixoApi.Models.Job;
using MsOptions = Microsoft.Extensions.Options.Options;

namespace FixoApi.Tests;

/// <summary>
/// Regression tests for QA fix plan P0:
///   - §7a: OfferTimeoutJob does not auto-broaden Direct v2 offers
///   - §7b: OfferService.DeclineOfferAsync sends OfferDeclined notification (not OfferAccepted)
///   - §7d: OfferService.AcceptOfferAsync rejects expired offers with offer_expired
///   - §4:  PhotoUrlSigner issues 30-min SAS URLs and JobService returns them
/// </summary>
public class P0QaFixesTests
{
    private static FixoDbContext MakeDb() => new(
        new DbContextOptionsBuilder<FixoDbContext>()
            .UseInMemoryDatabase($"p0-{Guid.NewGuid()}")
            .Options);

    private static (Job Job, JobOffer Offer) SeedDirectV2Offer(
        FixoDbContext db,
        OfferStage stage = OfferStage.Direct,
        int flowVersion = 2,
        DateTime? expiresAtUtc = null)
    {
        var ho = new ApplicationUser
        {
            Id = "ho-1", UserName = "ho@test.nz", Email = "ho@test.nz",
            FirstName = "Ho", LastName = "One", Role = UserRole.Homeowner, IsActive = true
        };
        var tr = new ApplicationUser
        {
            Id = "tr-1", UserName = "tr@test.nz", Email = "tr@test.nz",
            FirstName = "Tr", LastName = "One", Role = UserRole.Tradie, IsActive = true
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
            FlowVersion = flowVersion,
            ServiceId = 1,
            HourlyRate = 85m,
            EstimatedHours = 2,
            EstimatedTotal = 170m,
        };
        db.Jobs.Add(job);
        db.SaveChanges();

        var offer = new JobOffer
        {
            JobId = job.Id,
            TradieId = tr.Id,
            OfferedAtUtc = DateTime.UtcNow.AddMinutes(-20),
            ExpiresAtUtc = expiresAtUtc ?? DateTime.UtcNow.AddMinutes(10),
            Response = OfferResponse.Pending,
            Stage = stage,
            Kind = OfferKind.Instant,
            HourlyRateSnapshot = 85m,
        };
        db.JobOffers.Add(offer);
        db.SaveChanges();
        return (job, offer);
    }

    [Fact]
    public async Task OfferTimeoutJob_DirectV2_DoesNotCallSendNextOfferAsync()
    {
        using var db = MakeDb();
        var (_, offer) = SeedDirectV2Offer(db, stage: OfferStage.Direct, flowVersion: 2);
        var matching = new SpyMatchingService();
        var notifications = new RecordingNotificationService();
        var sut = new OfferTimeoutJob(
            db, matching, new StubJobHubContext(), notifications, NullLogger<OfferTimeoutJob>.Instance);

        await sut.ExecuteAsync(offer.Id);

        var updated = await db.JobOffers.FindAsync(offer.Id);
        Assert.Equal(OfferResponse.TimedOut, updated!.Response);
        Assert.Empty(matching.Calls);
    }

    [Fact]
    public async Task OfferTimeoutJob_AutoStage_CallsSendNextOfferAsync()
    {
        using var db = MakeDb();
        var (job, offer) = SeedDirectV2Offer(db, stage: OfferStage.Auto, flowVersion: 2);
        var matching = new SpyMatchingService();
        var notifications = new RecordingNotificationService();
        var sut = new OfferTimeoutJob(
            db, matching, new StubJobHubContext(), notifications, NullLogger<OfferTimeoutJob>.Instance);

        await sut.ExecuteAsync(offer.Id);

        Assert.Single(matching.Calls);
        Assert.Equal(job.Id, matching.Calls[0]);
    }

    [Fact]
    public async Task DeclineOfferAsync_SendsOfferDeclinedNotification_NotOfferAccepted()
    {
        using var db = MakeDb();
        var (job, offer) = SeedDirectV2Offer(db);
        var notifications = new RecordingNotificationService();
        var sut = new OfferService(
            db,
            new StubJobStatusService(),
            new StubJobHubContext(),
            notifications,
            new NoOpBackgroundJobClient(),
            MsOptions.Create(new JobFlowOptions()),
            NullLogger<OfferService>.Instance);

        var dto = await sut.DeclineOfferAsync(job.Id, offer.Id, "tr-1");

        Assert.Equal("Declined", dto.Response);
        Assert.Equal(2, notifications.Calls.Count);
        Assert.All(notifications.Calls, c => Assert.Equal(NotificationEvents.OfferDeclined, c.EventType));
        Assert.DoesNotContain(notifications.Calls, c => c.EventType == NotificationEvents.OfferAccepted);
        var hoCall = notifications.Calls.Single(c => c.UserId == "ho-1");
        Assert.Contains("declined", hoCall.Title, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task AcceptOfferAsync_WhenExpired_ThrowsBusinessRuleExceptionOfferExpired()
    {
        using var db = MakeDb();
        var (job, offer) = SeedDirectV2Offer(db, expiresAtUtc: DateTime.UtcNow.AddSeconds(-5));
        var sut = new OfferService(
            db,
            new StubJobStatusService(),
            new StubJobHubContext(),
            new RecordingNotificationService(),
            new NoOpBackgroundJobClient(),
            MsOptions.Create(new JobFlowOptions()),
            NullLogger<OfferService>.Instance);

        var ex = await Assert.ThrowsAsync<BusinessRuleException>(
            () => sut.AcceptOfferAsync(job.Id, offer.Id, "tr-1"));

        Assert.Equal("offer_expired", ex.Code);
        var unchanged = await db.JobOffers.FindAsync(offer.Id);
        Assert.Equal(OfferResponse.Pending, unchanged!.Response);
    }

    [Fact]
    public async Task PhotoUrlSigner_UsesDefault30MinuteTtlAndNullContainer()
    {
        var blob = new SpyBlobStorageService();
        var config = new ConfigurationBuilder().Build();
        var signer = new PhotoUrlSigner(blob, config);

        var url = await signer.SignAsync("jobs/1/abc.jpg");

        Assert.StartsWith("https://sas.example.test/th-photos/jobs/1/abc.jpg?sig=", url);
        Assert.Null(blob.LastContainer);
        Assert.Equal(TimeSpan.FromMinutes(30), blob.LastValidFor);
    }

    // ── Test doubles ────────────────────────────────────────────────────────

    private sealed class SpyMatchingService : IMatchingService
    {
        public List<int> Calls { get; } = [];
        public Task<List<TradieMatchDto>> FindMatchesAsync(Job job) => Task.FromResult(new List<TradieMatchDto>());
        public Task<List<ServiceSearchResultDto>> FindTradiesForServiceAsync(double lat, double lng, int serviceId)
            => Task.FromResult(new List<ServiceSearchResultDto>());
        public Task<List<TradieListDto>> GetTradieListForJobAsync(Job job, TradieListQuery query)
            => Task.FromResult(new List<TradieListDto>());
        public Task<List<RankedTradieDto>> RankTradiesAsync(Job job, bool broadened = false)
            => Task.FromResult(new List<RankedTradieDto>());
        public Task SendNextOfferAsync(int jobId, string actorUserId)
        {
            Calls.Add(jobId);
            return Task.CompletedTask;
        }
    }

    private sealed class RecordingNotificationService : INotificationService
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

    private sealed class StubJobStatusService : IJobStatusService
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

    private sealed class StubJobHubContext : IHubContext<JobHub>
    {
        public IHubClients Clients { get; } = new StubHubClients();
        public IGroupManager Groups => throw new NotImplementedException();

        private sealed class StubHubClients : IHubClients
        {
            private static readonly IClientProxy Proxy = new NoOpProxy();
            public IClientProxy All => Proxy;
            public IClientProxy AllExcept(IReadOnlyList<string> excludedConnectionIds) => Proxy;
            public IClientProxy Client(string connectionId) => Proxy;
            public IClientProxy Clients(IReadOnlyList<string> connectionIds) => Proxy;
            public IClientProxy Group(string groupName) => Proxy;
            public IClientProxy GroupExcept(string groupName, IReadOnlyList<string> excludedConnectionIds) => Proxy;
            public IClientProxy Groups(IReadOnlyList<string> groupNames) => Proxy;
            public IClientProxy User(string userId) => Proxy;
            public IClientProxy Users(IReadOnlyList<string> userIds) => Proxy;
        }

        private sealed class NoOpProxy : IClientProxy
        {
            public Task SendCoreAsync(string method, object?[] args, CancellationToken cancellationToken = default)
                => Task.CompletedTask;
        }
    }

    private sealed class NoOpBackgroundJobClient : IBackgroundJobClient
    {
        public string Create(Hangfire.Common.Job job, IState state) => "hf-1";
        public bool ChangeState(string jobId, IState state, string expectedState) => true;
    }

    private sealed class SpyBlobStorageService : IBlobStorageService
    {
        public string? LastContainer { get; private set; }
        public TimeSpan LastValidFor { get; private set; }

        public Task<string> UploadAsync(Stream content, string key, string contentType, string? container = null)
            => Task.FromResult(key);
        public Task DeleteAsync(string key, string? container = null) => Task.CompletedTask;
        public Task<Uri> GetReadSasUriAsync(string key, string? container, TimeSpan validFor)
        {
            LastContainer = container;
            LastValidFor = validFor;
            return Task.FromResult(new Uri($"https://sas.example.test/{container ?? "th-photos"}/{key}?sig=test"));
        }
        public Task<Uri> GenerateSignedUrl(string fileKey, TimeSpan expiration, string? container = null)
            => GetReadSasUriAsync(fileKey, container, expiration);
    }
}
