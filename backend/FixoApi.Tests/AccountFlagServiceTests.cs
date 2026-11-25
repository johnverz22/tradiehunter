using FixoApi.Data;
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

        var svc = new AccountFlagService(db);
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

        var svc = new AccountFlagService(db);
        await svc.ResolveOverdueFlagAsync(userId, "staff-1", "job 99 paid");

        var flag = await db.AccountFlags.SingleAsync(f => f.UserId == userId);
        Assert.False(flag.Resolved); // must NOT be cleared while another overdue job exists
    }

    [Fact]
    public async Task ResolveOverdueFlagAsync_IsIdempotent_WhenNoUnresolvedFlags()
    {
        await using var db = MakeDb();
        var svc = new AccountFlagService(db);

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

        var svc = new AccountFlagService(db);
        await svc.ResolveOverdueFlagAsync(userId, "staff-1", "re-resolving");

        var flag = await db.AccountFlags.SingleAsync(f => f.UserId == userId);
        // Timestamp should remain unchanged — idempotent.
        Assert.True(flag.Resolved);
        Assert.Equal(resolvedAt, flag.ResolvedAtUtc);
    }
}
