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
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace FixoApi.Tests;

/// <summary>
/// Plan 09 N2.5: verifies that the N2 paths (flagging/dispute open, dispute evidence,
/// admin dispute resolution) route through IJobStatusService (writing JobStatusHistory
/// and emitting JobStatusChanged) and trigger the policy notifications.
/// </summary>
public class NotificationN2PathTests
{
    private const string HomeownerId = "homeowner-1";
    private const string TradieId = "tradie-1";
    private const string StaffId = "staff-1";

    private static FixoDbContext MakeDb()
    {
        var opts = new DbContextOptionsBuilder<FixoDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new FixoDbContext(opts);
    }

    private static async Task<(FixoDbContext db, Job job)> SeedJobAsync(
        JobStatus status = JobStatus.AwaitingConfirmation,
        bool flagged = false)
    {
        var db = MakeDb();
        db.Users.AddRange(
            new ApplicationUser { Id = HomeownerId, UserName = HomeownerId },
            new ApplicationUser { Id = TradieId, UserName = TradieId },
            new ApplicationUser { Id = StaffId, UserName = StaffId });

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
            IsFlagged = flagged,
            DisputeStatus = flagged ? DisputeStatus.Open.ToString() : "None",
            FlagReason = flagged ? "Existing flag" : string.Empty,
        };
        db.Jobs.Add(job);
        await db.SaveChangesAsync();
        return (db, job);
    }

    [Fact]
    public async Task RecordFlagAsync_writes_history_and_emits_JobStatusChanged()
    {
        var (db, job) = await SeedJobAsync(JobStatus.Booked);
        var hub = new RecordingHubContext();
        var sut = new JobStatusService(
            db,
            hub,
            null!,
            null!,
            Microsoft.Extensions.Options.Options.Create(new PaymentOptions()),
            Microsoft.Extensions.Options.Options.Create(new JobFlowOptions { Version = 2 }),
            NullLogger<JobStatusService>.Instance,
            null!,
            null!,
            new RecordingNotificationService(),
            Microsoft.Extensions.Options.Options.Create(new BrandOptions()));

        await sut.RecordFlagAsync(job.Id, HomeownerId, "No-show");

        var updated = await db.Jobs.FindAsync(job.Id);
        Assert.NotNull(updated);
        Assert.True(updated.IsFlagged);
        Assert.Equal("No-show", updated.FlagReason);
        Assert.Equal("Open", updated.DisputeStatus);

        var history = await db.JobStatusHistory.SingleAsync(h => h.JobId == job.Id);
        Assert.Equal(JobStatus.Booked, history.FromStatus);
        Assert.Equal(JobStatus.Booked, history.ToStatus);
        Assert.Equal(HomeownerId, history.ChangedByUserId);
        Assert.Contains("No-show", history.Reason);

        var sent = Assert.Single(hub.Sent);
        Assert.Equal(JobHub.GroupName(job.Id), sent.Group);
        Assert.Equal("JobStatusChanged", sent.Method);
    }

    [Fact]
    public async Task OpenDisputeAsync_records_flag_and_notifies_counterparty_and_staff()
    {
        var (db, job) = await SeedJobAsync(JobStatus.AwaitingConfirmation);
        var jobStatus = new RecordingJobStatusService();
        var notifications = new RecordingNotificationService();
        var config = new ConfigurationBuilder().AddInMemoryCollection().Build();

        var sut = new DisputeService(db, new NullBlobStorageService(), config, jobStatus, notifications);

        var dto = await sut.OpenDisputeAsync(job.Id, HomeownerId, new CreateDisputeRequest
        {
            JobId = job.Id,
            Reason = "Work incomplete"
        });

        Assert.Equal(job.Id, dto.JobId);
        Assert.Single(jobStatus.RecordedFlags, f => f.JobId == job.Id && f.UserId == HomeownerId);

        var userNotif = Assert.Single(notifications.UserEvents);
        Assert.Equal(NotificationEvents.DisputeOpened, userNotif.EventKey);
        Assert.Equal(TradieId, userNotif.UserId);

        var staffAlert = Assert.Single(notifications.StaffAlerts);
        Assert.Equal(NotificationEvents.DisputeStaffAlert, staffAlert.EventKey);
        Assert.Equal($"/disputes/{job.Id}", staffAlert.AdminPath);
    }

    [Fact]
    public async Task AddEvidenceTextAsync_notifies_counterparty_and_staff()
    {
        var (db, job) = await SeedJobAsync(JobStatus.Disputed, flagged: true);
        var dispute = new Dispute
        {
            JobId = job.Id,
            OpenedBy = HomeownerId,
            OpenedAtUtc = DateTime.UtcNow,
            Status = DisputeStatus.Open,
            Outcome = DisputeOutcome.Null,
            OpenReason = "Invoice mismatch"
        };
        db.Disputes.Add(dispute);
        await db.SaveChangesAsync();

        var notifications = new RecordingNotificationService();
        var config = new ConfigurationBuilder().AddInMemoryCollection().Build();
        var sut = new DisputeService(
            db, new NullBlobStorageService(), config, new RecordingJobStatusService(), notifications);

        await sut.AddEvidenceTextAsync(dispute.Id, TradieId, new AddEvidenceTextRequest
        {
            TextContent = "Here is the breakdown"
        });

        var userNotif = Assert.Single(notifications.UserEvents);
        Assert.Equal(NotificationEvents.DisputeEvidenceAdded, userNotif.EventKey);
        Assert.Equal(HomeownerId, userNotif.UserId);

        var staffAlert = Assert.Single(notifications.StaffAlerts);
        Assert.Equal(NotificationEvents.DisputeStaffAlert, staffAlert.EventKey);
    }

    [Fact]
    public async Task ResolveDisputeAsync_cancel_transitions_via_JobStatusService_and_notifies_both_parties()
    {
        var (db, job) = await SeedJobAsync(JobStatus.Disputed, flagged: true);
        var jobStatus = new RecordingJobStatusService();
        var notifications = new RecordingNotificationService();
        var config = new ConfigurationBuilder().AddInMemoryCollection().Build();

        var sut = new AdminService(
            db,
            userManager: null!,
            emailSender: null!,
            tokenService: null!,
            blob: new NullBlobStorageService(),
            photoSigner: null!,
            config,
            Microsoft.Extensions.Options.Options.Create(new LocaleOptions()),
            notifications,
            jobStatus,
            new NullAuditLogService(),
            NullLogger<AdminService>.Instance);

        var ok = await sut.ResolveDisputeAsync(
            job.Id,
            new ResolveDisputeRequest { Action = "CancelJob", Note = "Agreed cancellation" },
            StaffId);

        Assert.True(ok);
        var transition = Assert.Single(jobStatus.Transitions);
        Assert.Equal(job.Id, transition.JobId);
        Assert.Equal(JobStatus.Cancelled, transition.NewStatus);
        Assert.Equal(UserRole.Staff, transition.ActorRole);

        Assert.Equal(2, notifications.UserEvents.Count);
        Assert.All(notifications.UserEvents, e => Assert.Equal(NotificationEvents.DisputeResolved, e.EventKey));
        Assert.Contains(notifications.UserEvents, e => e.UserId == HomeownerId);
        Assert.Contains(notifications.UserEvents, e => e.UserId == TradieId);
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
            => Task.FromResult(false);
    }

    private sealed class RecordingJobStatusService : IJobStatusService
    {
        public List<(int JobId, string UserId, string Reason)> RecordedFlags { get; } = [];
        public List<(int JobId, JobStatus NewStatus, UserRole ActorRole)> Transitions { get; } = [];

        public Task RecordFlagAsync(int jobId, string userId, string reason, CancellationToken ct = default)
        {
            RecordedFlags.Add((jobId, userId, reason));
            return Task.CompletedTask;
        }

        public Task<JobDto> TransitionAsync(int jobId, JobStatus newStatus, string userId,
            UserRole actorRole, ReasonCode? reasonCode = null, string? note = null)
        {
            Transitions.Add((jobId, newStatus, actorRole));
            return Task.FromResult(new JobDto { Id = jobId, Status = newStatus.ToString() });
        }

        public Task<JobDto> CancelJobAsync(int jobId, string userId, UserRole actorRole, CancelJobRequest request)
            => Task.FromResult(new JobDto { Id = jobId, Status = JobStatus.Cancelled.ToString() });

        public Task<JobDto> ReportNoShowAsync(int jobId, string userId, UserRole actorRole, ReportNoShowRequest request)
            => Task.FromResult(new JobDto { Id = jobId });
    }

    private sealed class RecordingHubContext : IHubContext<JobHub>
    {
        public List<(string Group, string Method, object?[] Args)> Sent { get; } = [];
        public IHubClients Clients => new RecordingClients(Sent);
        public IGroupManager Groups => throw new NotImplementedException();

        private sealed class RecordingClients(List<(string, string, object?[])> sent) : IHubClients
        {
            public IClientProxy Group(string groupName) => new RecordingProxy(groupName, sent);
            public IClientProxy All => throw new NotImplementedException();
            public IClientProxy AllExcept(IReadOnlyList<string> excludedConnectionIds) => throw new NotImplementedException();
            public IClientProxy Client(string connectionId) => throw new NotImplementedException();
            public IClientProxy Clients(IReadOnlyList<string> connectionIds) => throw new NotImplementedException();
            public IClientProxy GroupExcept(string groupName, IReadOnlyList<string> excludedConnectionIds) => throw new NotImplementedException();
            public IClientProxy Groups(IReadOnlyList<string> groupNames) => throw new NotImplementedException();
            public IClientProxy User(string userId) => throw new NotImplementedException();
            public IClientProxy Users(IReadOnlyList<string> userIds) => throw new NotImplementedException();
        }

        private sealed class RecordingProxy(string group, List<(string, string, object?[])> sent) : IClientProxy
        {
            public Task SendCoreAsync(string method, object?[] args, CancellationToken cancellationToken = default)
            {
                sent.Add((group, method, args));
                return Task.CompletedTask;
            }
        }
    }

    private sealed class NullBlobStorageService : IBlobStorageService
    {
        public Task<string> UploadAsync(Stream content, string fileName, string contentType, string? containerName = null)
            => Task.FromResult(fileName);
        public Task DeleteAsync(string blobUrl, string? containerName = null) => Task.CompletedTask;
        public Task<Uri> GetReadSasUriAsync(string blobKey, string? containerName, TimeSpan lifetime)
            => Task.FromResult(new Uri($"https://example.test/{blobKey}"));
        public Task<Uri> GenerateSignedUrl(string blobKey, TimeSpan lifetime, string? containerName = null)
            => Task.FromResult(new Uri($"https://example.test/{blobKey}"));
    }

    private sealed class NullAuditLogService : IAuditLogService
    {
        public Task LogAsync(string? actorId, string action, string? entityType = null, string? entityId = null,
            object? before = null, object? after = null, string? ipAddress = null, CancellationToken ct = default)
            => Task.CompletedTask;

        public Task<PagedResult<AuditLogDto>> QueryAsync(DateTime? fromUtc = null, DateTime? toUtc = null,
            string? actorId = null, string? action = null, int page = 1, int pageSize = 50,
            CancellationToken ct = default)
            => Task.FromResult(new PagedResult<AuditLogDto>());
    }
}
