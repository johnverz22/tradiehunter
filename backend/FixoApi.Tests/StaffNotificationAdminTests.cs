using FixoApi.Data;
using FixoApi.Models;
using FixoApi.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace FixoApi.Tests;

/// <summary>
/// Plan 09 N6.1/N6.2: AdminService staff notification queries and read-state mutations.
/// </summary>
public class StaffNotificationAdminTests
{
    private static AdminService BuildAdminService(FixoDbContext db)
    {
        var config = new ConfigurationBuilder().Build();
        return new AdminService(
            db,
            userManager: null!,
            emailSender: null!,
            tokenService: null!,
            blob: null!,
            photoSigner: null!,
            config: config,
            locale: Microsoft.Extensions.Options.Options.Create(new LocaleOptions()),
            notifications: null!,
            jobStatusService: null!,
            audit: null!,
            logger: NullLogger<AdminService>.Instance);
    }

    private static FixoDbContext MakeDb()
    {
        var opts = new DbContextOptionsBuilder<FixoDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new FixoDbContext(opts);
    }

    [Fact]
    public async Task GetStaffNotifications_returns_only_current_users_rows_and_unread_count()
    {
        using var db = MakeDb();
        var now = DateTime.UtcNow;
        db.StaffNotifications.AddRange(
            new StaffNotification
            {
                UserId = "staff-1",
                Type = NotificationEvents.ReceiptAwaitingVerification,
                EntityType = "payment",
                EntityId = "10",
                Title = "Older unread",
                Body = "Body 1",
                AdminPath = "/payments",
                CreatedUtc = now.AddMinutes(-10),
            },
            new StaffNotification
            {
                UserId = "staff-1",
                Type = NotificationEvents.DisputeStaffAlert,
                EntityType = "dispute",
                EntityId = "22",
                Title = "Newer read",
                Body = "Body 2",
                AdminPath = "/disputes/22",
                CreatedUtc = now.AddMinutes(-2),
                ReadUtc = now.AddMinutes(-1),
            },
            new StaffNotification
            {
                UserId = "staff-2",
                Type = NotificationEvents.JobNeedsReview,
                EntityType = "job",
                EntityId = "99",
                Title = "Other user",
                Body = "Body 3",
                CreatedUtc = now,
            });
        await db.SaveChangesAsync();

        var svc = BuildAdminService(db);

        var all = await svc.GetStaffNotificationsAsync("staff-1");
        Assert.Equal(1, all.UnreadCount);
        Assert.Equal(2, all.Items.Count);
        Assert.Equal("Newer read", all.Items[0].Title);
        Assert.Equal("Older unread", all.Items[1].Title);

        var unreadOnly = await svc.GetStaffNotificationsAsync("staff-1", unreadOnly: true);
        Assert.Equal(1, unreadOnly.UnreadCount);
        var only = Assert.Single(unreadOnly.Items);
        Assert.Equal("Older unread", only.Title);
    }

    [Fact]
    public async Task MarkRead_and_MarkAllRead_respect_user_isolation()
    {
        using var db = MakeDb();
        var n1 = new StaffNotification
        {
            UserId = "staff-1",
            Type = NotificationEvents.ReceiptAwaitingVerification,
            EntityType = "payment",
            EntityId = "1",
            Title = "A",
            Body = "Body A",
        };
        var n2 = new StaffNotification
        {
            UserId = "staff-1",
            Type = NotificationEvents.PaymentSlaBreach,
            EntityType = "payment",
            EntityId = "2",
            Title = "B",
            Body = "Body B",
        };
        var other = new StaffNotification
        {
            UserId = "staff-2",
            Type = NotificationEvents.DisputeStaffAlert,
            EntityType = "dispute",
            EntityId = "3",
            Title = "C",
            Body = "Body C",
        };
        db.StaffNotifications.AddRange(n1, n2, other);
        await db.SaveChangesAsync();

        var svc = BuildAdminService(db);

        Assert.False(await svc.MarkStaffNotificationReadAsync(other.Id, "staff-1"));
        Assert.True(await svc.MarkStaffNotificationReadAsync(n1.Id, "staff-1"));
        Assert.NotNull((await db.StaffNotifications.FindAsync(n1.Id))!.ReadUtc);

        var marked = await svc.MarkAllStaffNotificationsReadAsync("staff-1");
        Assert.Equal(1, marked);
        Assert.NotNull((await db.StaffNotifications.FindAsync(n2.Id))!.ReadUtc);
        Assert.Null((await db.StaffNotifications.FindAsync(other.Id))!.ReadUtc);
    }
}
