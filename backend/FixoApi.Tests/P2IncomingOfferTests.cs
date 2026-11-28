using FixoApi.Data;
using FixoApi.Enums;
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
/// QA fix plan P2 (§3) backend support for the tradie incoming-request alert:
///   - GET /api/offers/pending/mine data source (OfferService.GetPendingForTradieAsync)
///   - FCM channel routing + iOS time-sensitive marking for offer pushes
/// </summary>
public class P2IncomingOfferTests
{
    private static FixoDbContext MakeDb() => new(
        new DbContextOptionsBuilder<FixoDbContext>()
            .UseInMemoryDatabase($"p2-{Guid.NewGuid()}")
            .Options);

    private static OfferService MakeService(FixoDbContext db) => new(
        db,
        new P1OfferLifecycleTests.StubJobStatusService(),
        new P1OfferLifecycleTests.StubJobHubContext(),
        new P1OfferLifecycleTests.RecordingNotificationService(),
        new P1OfferLifecycleTests.NoOpBackgroundJobClient(),
        MsOptions.Create(new JobFlowOptions { MaxConcurrentQuoteRequests = 3 }),
        NullLogger<OfferService>.Instance);

    private static Job SeedJob(FixoDbContext db, string title, JobStatus status = JobStatus.Requested)
    {
        var job = new Job
        {
            HomeownerId = "ho-1",
            Title = title,
            Category = TradeCategory.Plumber,
            Description = "desc",
            Address = "1 Queen St, Auckland",
            Status = status,
            FlowVersion = 2,
            ServiceId = 1,
            HourlyRate = 85m,
            EstimatedHours = 2,
            EstimatedTotal = 170m,
        };
        db.Jobs.Add(job);
        db.SaveChanges();
        return job;
    }

    private static JobOffer SeedOffer(FixoDbContext db, int jobId, string tradieId,
        OfferResponse response = OfferResponse.Pending, int expiresInMinutes = 30)
    {
        var offer = new JobOffer
        {
            JobId = jobId,
            TradieId = tradieId,
            OfferedAtUtc = DateTime.UtcNow.AddMinutes(-1),
            ExpiresAtUtc = DateTime.UtcNow.AddMinutes(expiresInMinutes),
            Response = response,
            Stage = OfferStage.Direct,
            Kind = OfferKind.Instant,
            HourlyRateSnapshot = 85m,
        };
        db.JobOffers.Add(offer);
        db.SaveChanges();
        return offer;
    }

    [Fact]
    public async Task PendingForTradie_ReturnsOnlyLiveOffersOrderedByExpiry()
    {
        using var db = MakeDb();
        var jobA = SeedJob(db, "Job A");
        var jobB = SeedJob(db, "Job B");
        var jobC = SeedJob(db, "Job C");
        var jobD = SeedJob(db, "Job D", JobStatus.Booked);
        var jobE = SeedJob(db, "Job E");

        var later = SeedOffer(db, jobA.Id, "tr-1", expiresInMinutes: 20);
        var sooner = SeedOffer(db, jobB.Id, "tr-1", expiresInMinutes: 5);
        SeedOffer(db, jobC.Id, "tr-1", OfferResponse.Declined);   // answered
        SeedOffer(db, jobD.Id, "tr-1");                           // job no longer Requested
        SeedOffer(db, jobE.Id, "tr-2");                           // someone else's
        SeedOffer(db, SeedJob(db, "Job F").Id, "tr-1", expiresInMinutes: -1); // expired

        var result = await MakeService(db).GetPendingForTradieAsync("tr-1");

        Assert.Equal(new[] { sooner.Id, later.Id }, result.Select(o => o.Id).ToArray());
        Assert.Equal("Job B", result[0].JobTitle);
        Assert.All(result, o => Assert.Equal("Pending", o.Response));
    }

    [Fact]
    public async Task PendingForTradie_NoOffers_ReturnsEmpty()
    {
        using var db = MakeDb();
        Assert.Empty(await MakeService(db).GetPendingForTradieAsync("tr-1"));
    }

    [Fact]
    public void BuildAndroid_WithChannel_SetsChannelId()
    {
        var cfg = PushNotificationService.BuildAndroid(new Dictionary<string, string>
        {
            [PushNotificationService.ChannelKey] = PushNotificationService.IncomingRequestsChannel,
        });

        Assert.Equal(PushNotificationService.IncomingRequestsChannel, cfg.Notification?.ChannelId);
    }

    [Fact]
    public void BuildAndroid_WithoutChannel_LeavesNotificationUnset()
    {
        Assert.Null(PushNotificationService.BuildAndroid(null).Notification);
        Assert.Null(PushNotificationService.BuildAndroid(new Dictionary<string, string>()).Notification);
    }

    [Fact]
    public void BuildApns_IncomingRequests_IsTimeSensitive()
    {
        var cfg = PushNotificationService.BuildApns(new Dictionary<string, string>
        {
            [PushNotificationService.ChannelKey] = PushNotificationService.IncomingRequestsChannel,
        });

        Assert.Equal("time-sensitive", cfg.Aps.CustomData["interruption-level"]);
    }

    [Fact]
    public void BuildApns_OtherPush_HasNoInterruptionLevel()
    {
        var cfg = PushNotificationService.BuildApns(new Dictionary<string, string> { ["type"] = "chat" });

        Assert.Null(cfg.Aps.CustomData);
    }
}
