using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Hubs;
using FixoApi.Models;
using FixoApi.Options;
using FixoApi.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;
using Job = FixoApi.Models.Job;
using MsOptions = Microsoft.Extensions.Options.Options;

namespace FixoApi.Tests;

/// <summary>
/// QA fix plan P3 (§1 tradie presence, §6 chat collapse/tag push).
/// </summary>
public class P3PresenceAndChatTests
{
    private static FixoDbContext MakeDb() => new(
        new DbContextOptionsBuilder<FixoDbContext>()
            .UseInMemoryDatabase($"p3-{Guid.NewGuid()}")
            .Options);

    [Theory]
    [InlineData(false, false, null, false)]
    [InlineData(false, true, 0, false)]
    [InlineData(true, true, null, true)]
    [InlineData(true, false, null, false)]
    [InlineData(true, false, -2, true)]
    [InlineData(true, false, -3, false)] // exact boundary: LastSeenAtUtc == now - grace -> offline
    [InlineData(true, false, -10, false)]
    public void IsEffectivelyOnline_TruthTable(
        bool isAvailable,
        bool hasActiveConnection,
        int? lastSeenOffsetMinutes,
        bool expected)
    {
        var now = new DateTime(2026, 11, 28, 12, 0, 0, DateTimeKind.Utc);
        DateTime? lastSeen = lastSeenOffsetMinutes.HasValue
            ? now.AddMinutes(lastSeenOffsetMinutes.Value)
            : null;

        var actual = TradiePresenceService.IsEffectivelyOnline(
            isAvailable, hasActiveConnection, lastSeen, now, graceMinutes: 3);

        Assert.Equal(expected, actual);
    }

    [Fact]
    public async Task PresenceService_FilterOnline_And_SetOffline()
    {
        await using var db = MakeDb();
        var now = DateTime.UtcNow;

        db.TradieProfiles.AddRange(
            new TradieProfile { Id = 1, UserId = "tr-online", IsAvailable = true, LastSeenAtUtc = now.AddMinutes(-1) },
            new TradieProfile { Id = 2, UserId = "tr-stale", IsAvailable = true, LastSeenAtUtc = now.AddMinutes(-10) },
            new TradieProfile { Id = 3, UserId = "tr-off", IsAvailable = false, LastSeenAtUtc = now }
        );
        await db.SaveChangesAsync();

        var svc = new TradiePresenceService(db, NullLogger<TradiePresenceService>.Instance);

        var online = await svc.FilterOnlineAsync(["tr-online", "tr-stale", "tr-off", "tr-missing"]);
        Assert.Equal(new HashSet<string> { "tr-online" }, online);

        await svc.SetOfflineAsync("tr-online");
        var afterLogout = await svc.IsOnlineAsync("tr-online");
        Assert.False(afterLogout);
    }

    [Fact]
    public async Task DirectRequest_RejectsOfflineTradie_WithTradieUnreachable()
    {
        await using var db = MakeDb();
        db.Users.AddRange(
            new ApplicationUser { Id = "ho-1", UserName = "ho@test", FirstName = "Ho", LastName = "One", IsActive = true },
            new ApplicationUser { Id = "tr-1", UserName = "tr@test", FirstName = "Tr", LastName = "One", IsActive = true }
        );
        var tp = new TradieProfile
        {
            Id = 1,
            UserId = "tr-1",
            IsVerified = true,
            IsAvailable = true,
            LastSeenAtUtc = DateTime.UtcNow.AddMinutes(-15),
        };
        db.TradieProfiles.Add(tp);
        db.TradieRates.Add(new TradieRate { TradieProfileId = 1, ServiceId = 1, HourlyRate = 90m });
        var job = new Job
        {
            HomeownerId = "ho-1",
            Title = "Fix tap",
            Category = TradeCategory.Plumber,
            Description = "desc",
            Address = "1 Queen St",
            Status = JobStatus.Requested,
            FlowVersion = 2,
            ServiceId = 1,
        };
        db.Jobs.Add(job);
        await db.SaveChangesAsync();

        var presence = new TradiePresenceService(db, NullLogger<TradiePresenceService>.Instance);
        var svc = new OfferService(
            db,
            new P1OfferLifecycleTests.StubJobStatusService(),
            new P1OfferLifecycleTests.StubJobHubContext(),
            new P1OfferLifecycleTests.RecordingNotificationService(),
            new P1OfferLifecycleTests.NoOpBackgroundJobClient(),
            MsOptions.Create(new JobFlowOptions()),
            NullLogger<OfferService>.Instance,
            presence);

        var ex = await Assert.ThrowsAsync<BusinessRuleException>(() =>
            svc.CreateDirectRequestAsync(job.Id, "ho-1", new RequestTradieRequest { TradieId = "tr-1" }));

        Assert.Equal("tradie_unreachable", ex.Code);
    }

    [Fact]
    public void PushConfig_AppliesCollapseKey_ToAndroidAndApns()
    {
        var data = new Dictionary<string, string>
        {
            [PushNotificationService.ChannelKey] = PushNotificationService.ChatChannel,
            [PushNotificationService.CollapseKey] = "chat-42",
        };

        var android = PushNotificationService.BuildAndroid(data);
        Assert.Equal("chat", android.Notification?.ChannelId);
        Assert.Equal("chat-42", android.Notification?.Tag);
        Assert.Equal("chat-42", android.CollapseKey);

        var apns = PushNotificationService.BuildApns(data);
        Assert.NotNull(apns.Headers);
        Assert.Equal("chat-42", apns.Headers["apns-collapse-id"]);
    }
}
