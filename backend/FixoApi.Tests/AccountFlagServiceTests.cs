using FixoApi.Data;
using FixoApi.Email;
using FixoApi.Enums;
using FixoApi.Models;
using FixoApi.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FixoApi.Tests;

public class AccountFlagServiceTests
{
    private static FixoDbContext MakeDb()
    {
        var opts = new DbContextOptionsBuilder<FixoDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new FixoDbContext(opts);
    }

    private sealed class RecordingNotificationService : INotificationService
    {
        public List<StaffAlert> StaffAlerts { get; } = [];
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
            => Task.FromResult(false);
        public Task NotifyAsync(string eventKey, string userId, string title, string body,
            Dictionary<string, string>? data = null, CriticalNoticeModel? emailNotice = null,
            CancellationToken ct = default)
            => Task.CompletedTask;
        public Task SendToStaffAsync(StaffAlert alert, CancellationToken ct = default)
        {
            StaffAlerts.Add(alert);
            return Task.CompletedTask;
        }
    }

    [Fact]
    public async Task ResolveOverdueFlagAsync_ResolvesFlag_WhenNoOtherOverdueJobs()
    {
        await using var db = MakeDb();
        const string userId = "user-1";

        db.AccountFlags.Add(new AccountFlag
        {
            UserId        = userId,
            Type          = AccountFlagType.OverduePayment,
            Counter       = 1,
            ThresholdHit  = true,
            Resolved      = false,
            CreatedAtUtc  = DateTime.UtcNow
        });
        await db.SaveChangesAsync();

        var svc = new AccountFlagService(db, new RecordingNotificationService());
        await svc.ResolveOverdueFlagAsync(userId, "staff-1", "job 42 paid");

        var flag = await db.AccountFlags.SingleAsync(f => f.UserId == userId);
        Assert.True(flag.Resolved);
        Assert.NotNull(flag.ResolvedAtUtc);
    }

    [Fact]
    public async Task ResolveOverdueFlagAsync_DoesNotResolve_WhenOtherOverdueJobExists()
    {
        await using var db = MakeDb();
        const string userId = "user-2";

        db.AccountFlags.Add(new AccountFlag
        {
            UserId        = userId,
            Type          = AccountFlagType.OverduePayment,
            Counter       = 1,
            ThresholdHit  = true,
            Resolved      = false,
            CreatedAtUtc  = DateTime.UtcNow
        });

        // A second overdue AwaitingPayment v2 job — the guard must see this and skip resolving.
        db.Jobs.Add(new Job
        {
            HomeownerId      = userId,
            FlowVersion      = 2,
            Status           = JobStatus.AwaitingPayment,
            PaymentDueAtUtc  = DateTime.UtcNow.AddHours(-1),
            Title            = "other overdue job",
            Description      = "pending debt",
            CreatedAtUtc     = DateTime.UtcNow,
            UpdatedAtUtc     = DateTime.UtcNow
        });
        await db.SaveChangesAsync();

        var svc = new AccountFlagService(db, new RecordingNotificationService());
        await svc.ResolveOverdueFlagAsync(userId, "staff-1", "job 99 paid");

        var flag = await db.AccountFlags.SingleAsync(f => f.UserId == userId);
        Assert.False(flag.Resolved); // must NOT be cleared while another overdue job exists
    }

    [Fact]
    public async Task ResolveOverdueFlagAsync_IsIdempotent_WhenNoUnresolvedFlags()
    {
        await using var db = MakeDb();
        var svc = new AccountFlagService(db, new RecordingNotificationService());

        // Should complete without throwing when there is nothing to resolve.
        await svc.ResolveOverdueFlagAsync("user-no-flags", "staff-1");
    }

    [Fact]
    public async Task ResolveOverdueFlagAsync_DoesNotAffect_AlreadyResolvedFlag()
    {
        await using var db = MakeDb();
        const string userId = "user-3";
        var resolvedAt = DateTime.UtcNow.AddMinutes(-5);

        db.AccountFlags.Add(new AccountFlag
        {
            UserId        = userId,
            Type          = AccountFlagType.OverduePayment,
            Counter       = 1,
            ThresholdHit  = true,
            Resolved      = true,
            ResolvedAtUtc = resolvedAt,
            CreatedAtUtc  = DateTime.UtcNow.AddHours(-2)
        });
        await db.SaveChangesAsync();

        var svc = new AccountFlagService(db, new RecordingNotificationService());
        await svc.ResolveOverdueFlagAsync(userId, "staff-1", "re-resolving");

        var flag = await db.AccountFlags.SingleAsync(f => f.UserId == userId);
        // Timestamp should remain unchanged — idempotent.
        Assert.True(flag.Resolved);
        Assert.Equal(resolvedAt, flag.ResolvedAtUtc);
    }

    [Theory]
    [InlineData(AccountFlagType.Abuse)]
    [InlineData(AccountFlagType.RepeatNoShow)]
    [InlineData(AccountFlagType.LowRating)]
    [InlineData(AccountFlagType.OverduePayment)]
    public async Task LogFlagAsync_alerts_staff_only_when_threshold_is_crossed(AccountFlagType flagType)
    {
        await using var db = MakeDb();
        var notifications = new RecordingNotificationService();
        var svc = new AccountFlagService(db, notifications);

        await svc.LogFlagAsync("user-flag", flagType, "strike 1");
        await svc.LogFlagAsync("user-flag", flagType, "strike 2");
        Assert.Empty(notifications.StaffAlerts);

        await svc.LogFlagAsync("user-flag", flagType, "strike 3");
        var alert = Assert.Single(notifications.StaffAlerts);
        Assert.Equal(NotificationEvents.AccountFlagThreshold, alert.EventKey);
        Assert.Equal($"flag:user-flag:{flagType}", alert.EntityKey);

        // 4th strike does not re-alert because threshold was already hit.
        await svc.LogFlagAsync("user-flag", flagType, "strike 4");
        Assert.Single(notifications.StaffAlerts);
    }
}
