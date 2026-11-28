using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Models;
using FixoApi.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using NetTopologySuite.Geometries;
using Xunit;
using Job = FixoApi.Models.Job;

namespace FixoApi.Tests;

/// <summary>
/// Every tradie-suggestion path must drop deactivated or unverified tradies and bring a
/// reactivated one back.
/// </summary>
public class MatchingAccountGateTests
{
    private static Point Akl(double lat = 0) => new(174.7633, -36.8485 + lat) { SRID = 4326 };

    private static async Task<(MatchingService Sut, FixoDbContext Db, Job Job)> SetUpAsync()
    {
        var db = new FixoDbContext(new DbContextOptionsBuilder<FixoDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);

        db.Services.Add(new Service { Id = 1, Name = "Plumbing", Category = TradeCategory.Plumber, RequiresLicence = false });
        db.Users.AddRange(
            new ApplicationUser { Id = "ho", UserName = "ho", Email = "ho@test.nz", FirstName = "H", LastName = "O" },
            new ApplicationUser { Id = "tr", UserName = "tr", Email = "tr@test.nz", FirstName = "T", LastName = "R" });
        db.TradieProfiles.Add(new TradieProfile
        {
            Id = 1, UserId = "tr", TradeType = "Plumber", IsVerified = true, IsAvailable = true, Location = Akl(0.01),
        });
        db.TradieRates.Add(new TradieRate { TradieProfileId = 1, ServiceId = 1, HourlyRate = 90m });
        var job = new Job
        {
            Id = 1, HomeownerId = "ho", Title = "Tap", Category = TradeCategory.Plumber, ServiceId = 1,
            Status = JobStatus.Requested, Location = Akl(),
        };
        db.Jobs.Add(job);
        await db.SaveChangesAsync();

        var config = new ConfigurationBuilder().Build();
        var sut = new MatchingService(db, null!, null!, null!, null!, config, NullLogger<MatchingService>.Instance);
        return (sut, db, job);
    }

    private static async Task<int[]> CountsAsync(MatchingService sut, Job job) =>
    [
        (await sut.FindMatchesAsync(job)).Count,
        (await sut.FindTradiesForServiceAsync(-36.8485, 174.7633, 1)).Count,
        (await sut.GetTradieListForJobAsync(job, new TradieListQuery())).Count,
        (await sut.RankTradiesAsync(job)).Count,
    ];

    [Fact]
    public async Task Active_verified_tradie_is_suggested_on_every_path()
    {
        var (sut, db, job) = await SetUpAsync();
        using (db) Assert.Equal(new[] { 1, 1, 1, 1 }, await CountsAsync(sut, job));
    }

    [Fact]
    public async Task Deactivated_tradie_is_dropped_everywhere_and_returns_when_reactivated()
    {
        var (sut, db, job) = await SetUpAsync();
        using (db)
        {
            (await db.Users.FindAsync("tr"))!.IsActive = false;
            await db.SaveChangesAsync();
            Assert.Equal(new[] { 0, 0, 0, 0 }, await CountsAsync(sut, job));

            (await db.Users.FindAsync("tr"))!.IsActive = true;
            await db.SaveChangesAsync();
            Assert.Equal(new[] { 1, 1, 1, 1 }, await CountsAsync(sut, job));
        }
    }

    [Fact]
    public async Task Unverified_tradie_is_dropped_everywhere()
    {
        var (sut, db, job) = await SetUpAsync();
        using (db)
        {
            (await db.TradieProfiles.FindAsync(1))!.IsVerified = false;
            await db.SaveChangesAsync();
            Assert.Equal(new[] { 0, 0, 0, 0 }, await CountsAsync(sut, job));
        }
    }
}
