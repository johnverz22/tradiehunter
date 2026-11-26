using FixoApi.Data;
using FixoApi.Enums;
using FixoApi.Hubs;
using FixoApi.Models;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FixoApi.Tests;

public class JobHubAccessTests
{
    private static FixoDbContext MakeDb()
    {
        var opts = new DbContextOptionsBuilder<FixoDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new FixoDbContext(opts);
    }

    private static async Task<int> SeedJobAsync(FixoDbContext db, string? matchedTradieId = null)
    {
        var job = new Job
        {
            HomeownerId = "homeowner-1",
            MatchedTradieId = matchedTradieId,
            FlowVersion = 2,
            Status = JobStatus.Booked,
            Title = "Fix tap",
            Description = "Leaking",
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        };
        db.Jobs.Add(job);
        await db.SaveChangesAsync();
        return job.Id;
    }

    [Fact]
    public async Task Homeowner_CanJoin()
    {
        await using var db = MakeDb();
        var id = await SeedJobAsync(db);
        Assert.True(await JobHub.CanJoinAsync(db, id, "homeowner-1", isStaff: false));
    }

    [Fact]
    public async Task MatchedTradie_CanJoin()
    {
        await using var db = MakeDb();
        var id = await SeedJobAsync(db, matchedTradieId: "tradie-1");
        Assert.True(await JobHub.CanJoinAsync(db, id, "tradie-1", isStaff: false));
    }

    [Fact]
    public async Task Staff_CanJoin()
    {
        await using var db = MakeDb();
        var id = await SeedJobAsync(db);
        Assert.True(await JobHub.CanJoinAsync(db, id, "staff-1", isStaff: true));
    }

    [Fact]
    public async Task UnrelatedUser_IsRejected()
    {
        await using var db = MakeDb();
        var id = await SeedJobAsync(db, matchedTradieId: "tradie-1");
        Assert.False(await JobHub.CanJoinAsync(db, id, "stranger", isStaff: false));
        Assert.False(await JobHub.CanJoinAsync(db, id, "tradie-2", isStaff: false));
    }

    [Fact]
    public async Task UnknownJob_IsRejected_EvenForStaff()
    {
        await using var db = MakeDb();
        Assert.False(await JobHub.CanJoinAsync(db, 9999, "staff-1", isStaff: true));
    }
}
