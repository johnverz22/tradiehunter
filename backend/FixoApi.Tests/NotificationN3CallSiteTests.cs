using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Email;
using FixoApi.Enums;
using FixoApi.Hubs;
using FixoApi.Models;
using FixoApi.Options;
using FixoApi.Services;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace FixoApi.Tests;

/// <summary>
/// Plan 09 N8.1: verifies that N3 call sites in JobStatusService.TransitionAsync
/// emit the expected policy notification event keys to the right recipients.
/// </summary>
public class NotificationN3CallSiteTests
{
    private const string HomeownerId = "homeowner-1";
    private const string TradieId = "tradie-1";

    private static FixoDbContext MakeDb()
    {
        var opts = new DbContextOptionsBuilder<FixoDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new FixoDbContext(opts);
    }

    private static async Task<(FixoDbContext db, Job job)> SeedJobAsync(JobStatus status)
    {
        var db = MakeDb();
        db.Users.AddRange(
            new ApplicationUser { Id = HomeownerId, UserName = HomeownerId, FirstName = "H", LastName = "One" },
            new ApplicationUser { Id = TradieId, UserName = TradieId, FirstName = "T", LastName = "One" });

        var job = new Job
        {
            Title = "Fix leaking tap",
            Description = "Kitchen tap",
            Category = default,
            Urgency = default,
            Address = "1 Queen St",
            HomeownerId = HomeownerId,
            MatchedTradieId = TradieId,
            Status = status,
            DisputeStatus = "None",
            FlagReason = string.Empty,
        };
        db.Jobs.Add(job);
        await db.SaveChangesAsync();
        return (db, job);
    }

    private static JobStatusService MakeSut(FixoDbContext db, RecordingNotificationService notif)
        => new(
            db,
            new RecordingHubContext(),
            null!,
            null!,
            Microsoft.Extensions.Options.Options.Create(new PaymentOptions()),
            Microsoft.Extensions.Options.Options.Create(new JobFlowOptions { Version = 2 }),
            NullLogger<JobStatusService>.Instance,
            null!,
            null!,
            notif,
            Microsoft.Extensions.Options.Options.Create(new BrandOptions()));

    [Theory]
    [InlineData(JobStatus.Booked, JobStatus.InProgress, UserRole.Tradie, "job_in_progress")]
    [InlineData(JobStatus.InProgress, JobStatus.AwaitingConfirmation, UserRole.Tradie, "job_awaiting_confirmation")]
    [InlineData(JobStatus.AwaitingPayment, JobStatus.PaymentReview, UserRole.Homeowner, "job_payment_review")]
    [InlineData(JobStatus.Booked, JobStatus.Cancelled, UserRole.Homeowner, "job_cancelled")]
    public async Task TransitionAsync_emits_expected_policy_event(
        JobStatus fromStatus,
        JobStatus toStatus,
        UserRole actorRole,
        string expectedEventKey)
    {
        var (db, job) = await SeedJobAsync(fromStatus);
        var notif = new RecordingNotificationService();
        var sut = MakeSut(db, notif);
        var actorId = actorRole == UserRole.Tradie ? TradieId : HomeownerId;

        await sut.TransitionAsync(job.Id, toStatus, actorId, actorRole, null, "test transition");

        Assert.Contains(notif.UserEvents, e => e.EventKey == expectedEventKey);
    }

    // ── Test doubles ──────────────────────────────────────────────────────────

    private sealed class RecordingNotificationService : INotificationService
    {
        public List<(string EventKey, string UserId, string Title, string Body)> UserEvents { get; } = [];
        public List<StaffAlert> StaffAlerts { get; } = [];

        public Task NotifyAsync(string eventKey, string userId, string title, string body,
            Dictionary<string, string>? data = null, CriticalNoticeModel? emailModel = null,
            CancellationToken ct = default)
        {
            UserEvents.Add((eventKey, userId, title, body));
            return Task.CompletedTask;
        }

        public Task SendToStaffAsync(StaffAlert alert, CancellationToken ct = default)
        {
            StaffAlerts.Add(alert);
            return Task.CompletedTask;
        }

        public Task SendToUserAsync(string userId, string title, string body,
            Dictionary<string, string>? data = null, bool critical = false,
            string? ctaLabel = null, string? ctaPath = null, CancellationToken ct = default)
            => Task.CompletedTask;

        public Task SendToUserAsync(string userId, string title, string body,
            Dictionary<string, string>? data, CriticalNoticeModel emailModel,
            bool critical = false, CancellationToken ct = default)
            => Task.CompletedTask;

        public Task<bool> SendPushToUserAsync(string userId, string title, string body,
            Dictionary<string, string>? data = null, CancellationToken ct = default)
            => Task.FromResult(true);
    }

    private sealed class RecordingHubContext : IHubContext<JobHub>
    {
        public IHubClients Clients { get; } = new NoopClients();
        public IGroupManager Groups { get; } = new NoopGroups();

        private sealed class NoopClients : IHubClients
        {
            private static readonly IClientProxy Proxy = new NoopProxy();
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

        private sealed class NoopProxy : IClientProxy
        {
            public Task SendCoreAsync(string method, object?[] args, CancellationToken cancellationToken = default)
                => Task.CompletedTask;
        }

        private sealed class NoopGroups : IGroupManager
        {
            public Task AddToGroupAsync(string connectionId, string groupName, CancellationToken cancellationToken = default)
                => Task.CompletedTask;
            public Task RemoveFromGroupAsync(string connectionId, string groupName, CancellationToken cancellationToken = default)
                => Task.CompletedTask;
        }
    }
}
