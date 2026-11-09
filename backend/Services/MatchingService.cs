using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Hubs;
using FixoApi.Jobs;
using FixoApi.Models;
using Hangfire;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using NetTopologySuite.Geometries;

namespace FixoApi.Services;

/// <summary>
/// Rule-based tradie matching engine with sequential offer dispatch (P3-02 → P3-06).
///
/// Ranking algorithm (P3-02):
///   Score = w_distance × (1 – normalisedDistance)
///         + w_rating   × normalisedRating
///         + w_schedule × scheduleBonus
///
/// Sequential offer flow (P3-03 → P3-06):
///   1. Rank candidates by score (Auto stage, strict radius).
///   2. Skip tradies who already have a non-Pending offer for this job.
///   3. Create a JobOffer, schedule Hangfire timeout (P3-04).
///   4. Emit SignalR + FCM (P3-03 / P3-10).
///   5. When Auto list exhausted → Broadened stage (P3-05).
///   6. When Broadened list also exhausted → Cancel job (P3-06).
///
/// Uses EF Core spatial LINQ (NetTopologySuite) — never raw PostGIS SQL.
/// </summary>
public class MatchingService : IMatchingService
{
    private readonly FixoDbContext _context;
    private readonly IHubContext<JobHub> _jobHub;
    private readonly PushNotificationService _push;
    private readonly IBackgroundJobClient _hangfire;
    private readonly IJobStatusService _jobStatusService;
    private readonly ILogger<MatchingService> _logger;

    private readonly double _radiusKm;
    private readonly double _broadenedRadiusKm;
    private readonly int _offerWindowMinutes;

    private const double MetresPerKm = 1000.0;

    // Scoring weights (sum to 1.0)
    private const double WeightDistance = 0.50;
    private const double WeightRating   = 0.35;
    private const double WeightSchedule = 0.15;

    public MatchingService(
        FixoDbContext context,
        IHubContext<JobHub> jobHub,
        PushNotificationService push,
        IBackgroundJobClient hangfire,
        IJobStatusService jobStatusService,
        IConfiguration config,
        ILogger<MatchingService> logger)
    {
        _context          = context;
        _jobHub           = jobHub;
        _push             = push;
        _hangfire         = hangfire;
        _jobStatusService = jobStatusService;
        _logger           = logger;
        _radiusKm         = config.GetValue<double>("Matching:RadiusKm", 25.0);
        _broadenedRadiusKm = config.GetValue<double>("Matching:BroadenedRadiusKm", 50.0);
        _offerWindowMinutes = config.GetValue<int>("Matching:OfferWindowMinutes", 10);
    }

    // ── FindMatchesAsync (legacy broadcast helper) ────────────────────────────

    /// <inheritdoc/>
    public async Task<List<TradieMatchDto>> FindMatchesAsync(Job job)
    {
        if (job.Location == null)
            return new List<TradieMatchDto>();

        var jobLocation  = job.Location;
        var radiusMetres = _radiusKm * MetresPerKm;
        var categoryString = job.Category.ToString();
        var searchArea   = Geo.SearchArea(jobLocation, radiusMetres);

        var service = await _context.Services.FindAsync(job.ServiceId);
        
        // P8-02: never surface a tradie on either side of a block.
        var excluded = await GetBlockedTradieIdsAsync(job.HomeownerId);

        // Same box-prefilter + in-memory exact distance as RankTradiesAsync.
        var inBoxQuery = _context.TradieProfiles
            .Include(t => t.User)
            .Where(t =>
                t.IsAvailable &&
                t.IsVerified &&
                t.Location != null &&
                t.TradeType.ToLower() == categoryString.ToLower() &&
                !excluded.Contains(t.UserId) &&
                t.Location.Intersects(searchArea));
                
        // P10-08: Licence-Gated Matching
        if (service != null && service.RequiresLicence)
        {
            inBoxQuery = inBoxQuery.Where(t => 
                _context.TradieCredentials.Any(c => 
                    c.TradieProfileId == t.Id && 
                    c.Status == CredentialStatus.Approved && 
                    c.Type == CredentialType.License
                ));
        }

        var inBox = await inBoxQuery.ToListAsync();

        var tradies = inBox
            .Where(t => Geo.HaversineMetres(t.Location!, jobLocation) <= radiusMetres)
            .OrderBy(t => Geo.HaversineMetres(t.Location!, jobLocation))
            .ToList();

        if (tradies.Count == 0)
            return new List<TradieMatchDto>();

        var tradieIds    = tradies.Select(t => t.UserId).ToList();
        var ratingGroups = await GetRatingLookupAsync(tradieIds);

        return tradies.Select(t =>
        {
            var distanceM  = Geo.HaversineMetres(t.Location!, jobLocation);
            var distanceKm = distanceM / MetresPerKm;
            var initials   = GetInitials(t.User.FirstName, t.User.LastName);

            ratingGroups.TryGetValue(t.UserId, out var stats);
            var hasStats = ratingGroups.ContainsKey(t.UserId);

            return new TradieMatchDto
            {
                TradieId    = t.UserId,
                Initials    = initials,
                Name        = $"{t.User.FirstName} {t.User.LastName}".Trim(),
                Trade       = t.TradeType,
                Verified    = t.IsVerified,
                HasInsurance = t.HasInsurance,
                DistanceKm  = Math.Round(distanceKm, 1),
                Distance    = $"{distanceKm:F1} km away",
                Rating      = hasStats ? Math.Round(stats.AvgRating, 1) : 0,
                ReviewCount = hasStats ? stats.ReviewCount : 0,
            };
        }).ToList();
    }

    // ── FindTradiesForServiceAsync ────────────────────────────────────────────

    /// <inheritdoc/>
    public async Task<List<ServiceSearchResultDto>> FindTradiesForServiceAsync(
        double latitude, double longitude, int serviceId)
    {
        var location     = new Point(longitude, latitude) { SRID = 4326 };
        var radiusMetres = _radiusKm * MetresPerKm;
        var searchArea   = Geo.SearchArea(location, radiusMetres);

        // Bounding-box prefilter in SQL (EF spatial LINQ); the exact radius and
        // ordering are applied in memory — see Geo for why ST_Distance can't
        // be compared against metres here.
        var candidates = await _context.TradieRates
            .Include(rate => rate.TradieProfile)
                .ThenInclude(profile => profile.User)
            .Where(rate => rate.ServiceId == serviceId
                && rate.TradieProfile.IsVerified
                && rate.TradieProfile.IsAvailable
                && rate.TradieProfile.Location != null
                && rate.TradieProfile.Location.Intersects(searchArea))
            .ToListAsync();

        return candidates
            .Where(rate => Geo.HaversineMetres(rate.TradieProfile.Location!, location) <= radiusMetres)
            .OrderBy(rate => Geo.HaversineMetres(rate.TradieProfile.Location!, location))
            .Select(rate => new ServiceSearchResultDto
            {
                TradieId     = rate.TradieProfile.UserId,
                Name         = (rate.TradieProfile.User.FirstName + " " + rate.TradieProfile.User.LastName).Trim(),
                BusinessName = rate.TradieProfile.BusinessName,
                HourlyRate   = rate.HourlyRate,
                DistanceKm   = Math.Round(
                    Geo.HaversineMetres(rate.TradieProfile.Location!, location) / MetresPerKm, 1),
            })
            .ToList();
    }

    // ── P3-02: Ranking algorithm ──────────────────────────────────────────────

    /// <inheritdoc/>
    public async Task<List<RankedTradieDto>> RankTradiesAsync(Job job, bool broadened = false)
    {
        if (job.Location == null)
            return new List<RankedTradieDto>();

        var jobLocation  = job.Location;
        var radiusMetres = (broadened ? _broadenedRadiusKm : _radiusKm) * MetresPerKm;
        var categoryStr  = job.Category.ToString();
        var searchArea   = Geo.SearchArea(jobLocation, radiusMetres);

        var service = await _context.Services.FindAsync(job.ServiceId);
        
        // P8-02: blocks apply in both directions (homeowner↔tradie).
        var excluded = await GetBlockedTradieIdsAsync(job.HomeownerId);

        // SQL does the cheap box test via EF Core spatial LINQ; the exact
        // great-circle radius filter and the score are computed in memory
        // (see Geo — ST_Distance on geometry(4326) returns degrees).
        var inBoxQuery = _context.TradieProfiles
            .Include(t => t.User)
            .Where(t =>
                t.IsAvailable &&
                t.IsVerified &&
                t.Location != null &&
                t.TradeType.ToLower() == categoryStr.ToLower() &&
                !excluded.Contains(t.UserId) &&
                t.Location.Intersects(searchArea));
                
        // P10-08: Licence-Gated Matching
        if (service != null && service.RequiresLicence)
        {
            inBoxQuery = inBoxQuery.Where(t => 
                _context.TradieCredentials.Any(c => 
                    c.TradieProfileId == t.Id && 
                    c.Status == CredentialStatus.Approved && 
                    c.Type == CredentialType.License
                ));
        }

        var inBox = await inBoxQuery.ToListAsync();

        var tradies = inBox
            .Where(t => Geo.HaversineMetres(t.Location!, jobLocation) <= radiusMetres)
            .ToList();

        if (tradies.Count == 0)
            return new List<RankedTradieDto>();

        var tradieIds    = tradies.Select(t => t.UserId).ToList();
        var ratingLookup = await GetRatingLookupAsync(tradieIds);

        // Fetch schedules for all candidates in one round-trip.
        var scheduledWeekday = (int)job.ScheduledStartUtc.DayOfWeek; // 0=Sunday … 6=Saturday
        var scheduledTradieIds = await _context.TradieSchedules
            .Where(s => tradieIds.Contains(s.TradieProfile.UserId) && s.Weekday == scheduledWeekday)
            .Select(s => s.TradieProfile.UserId)
            .ToListAsync();
        var scheduledSet = scheduledTradieIds.ToHashSet();

        // Max distance in metres within the searched radius (for normalisation).
        double maxDistM  = radiusMetres;
        double maxRating = 5.0;

        var ranked = tradies.Select(t =>
        {
            var distM  = Geo.HaversineMetres(t.Location!, jobLocation);
            var distKm = distM / MetresPerKm;

            ratingLookup.TryGetValue(t.UserId, out var stats);
            var rating = stats.AvgRating; // default 0 when not found

            var scheduleBonus = scheduledSet.Contains(t.UserId) ? 1.0 : 0.0;

            var normDist = maxDistM > 0 ? distM / maxDistM : 0;
            var normRat  = maxRating > 0 ? rating / maxRating : 0;

            var score = WeightDistance * (1.0 - normDist)
                      + WeightRating   * normRat
                      + WeightSchedule * scheduleBonus;

            return new RankedTradieDto
            {
                TradieId      = t.UserId,
                Name          = $"{t.User.FirstName} {t.User.LastName}".Trim(),
                Score         = Math.Round(score, 4),
                DistanceKm    = Math.Round(distKm, 1),
                Rating        = Math.Round(rating, 1),
                ScheduleMatch = scheduleBonus > 0,
            };
        })
        .OrderByDescending(r => r.Score)
        .ToList();

        return ranked;
    }

    // ── P3-03 / P3-04 / P3-05 / P3-06: Sequential offer dispatch ─────────────

    /// <inheritdoc/>
    public async Task SendNextOfferAsync(int jobId, string actorUserId)
    {
        var job = await _context.Jobs
            .Include(j => j.Offers)
            .FirstOrDefaultAsync(j => j.Id == jobId);

        if (job == null)
        {
            _logger.LogWarning("SendNextOfferAsync: job {JobId} not found.", jobId);
            return;
        }

        if (job.Status != JobStatus.Requested)
        {
            _logger.LogInformation(
                "SendNextOfferAsync: job {JobId} is {Status} — no offer sent.", jobId, job.Status);
            return;
        }

        // IDs of tradies who already have an offer for this job (any terminal state or pending).
        var alreadyOfferedIds = job.Offers.Select(o => o.TradieId).ToHashSet();

        // --- Auto stage first ---
        var autoRanked = await RankTradiesAsync(job, broadened: false);
        var autoNext   = autoRanked.FirstOrDefault(r => !alreadyOfferedIds.Contains(r.TradieId));

        if (autoNext != null)
        {
            await CreateAndDispatchOfferAsync(job, autoNext, OfferStage.Auto, alreadyOfferedIds.Count + 1);
            return;
        }

        // --- Auto list exhausted → Broadened stage (P3-05) ---
        var broadRanked = await RankTradiesAsync(job, broadened: true);
        var broadNext   = broadRanked.FirstOrDefault(r => !alreadyOfferedIds.Contains(r.TradieId));

        if (broadNext != null)
        {
            _logger.LogInformation(
                "SendNextOfferAsync: job {JobId} Auto list exhausted → Broadened stage.", jobId);
            await CreateAndDispatchOfferAsync(job, broadNext, OfferStage.Broadened, alreadyOfferedIds.Count + 1);
            return;
        }

        // --- Terminal path: no tradie found (P3-06) ---
        _logger.LogWarning(
            "SendNextOfferAsync: job {JobId} — all candidates exhausted. Cancelling.", jobId);

        try
        {
            await _jobStatusService.TransitionAsync(
                jobId,
                JobStatus.Cancelled,
                actorUserId,
                UserRole.Staff,           // system acts on behalf of platform
                ReasonCode.no_tradie_found,
                "Matching exhausted — no available tradie found.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "SendNextOfferAsync: failed to cancel job {JobId}.", jobId);
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private async Task CreateAndDispatchOfferAsync(
        Job job, RankedTradieDto tradie, OfferStage stage, int offerIndex)
    {
        var now     = DateTime.UtcNow;
        var expires = now.AddMinutes(_offerWindowMinutes);

        var offer = new JobOffer
        {
            JobId        = job.Id,
            TradieId     = tradie.TradieId,
            OfferedAtUtc = now,
            ExpiresAtUtc = expires,
            Response     = OfferResponse.Pending,
            Stage        = stage,
        };
        _context.JobOffers.Add(offer);
        await _context.SaveChangesAsync(); // flush to get offer.Id

        // Schedule Hangfire timeout job (P3-04).
        var hangfireId = _hangfire.Schedule<OfferTimeoutJob>(
            j => j.ExecuteAsync(offer.Id),
            expires - now);

        offer.HangfireJobId = hangfireId;
        await _context.SaveChangesAsync();

        _logger.LogInformation(
            "SendNextOfferAsync: offer {OfferId} sent to tradie {TradieId} for job {JobId} " +
            "(stage={Stage}, expires={Expires}, hangfire={HangfireId}).",
            offer.Id, tradie.TradieId, job.Id, stage, expires, hangfireId);

        // Build SignalR payload (P3-10).
        var payload = new OfferLifecyclePayload
        {
            EventType   = "OfferCreated",
            JobId       = job.Id,
            OfferId     = offer.Id,
            TradieId    = tradie.TradieId,
            ExpiresAtUtc = expires,
            JobTitle    = job.Title,
            OfferIndex  = offerIndex,
        };

        // Notify homeowner (job group) + targeted tradie (user group).
        await _jobHub.Clients.Group(JobHub.GroupName(job.Id))
            .SendAsync("OfferLifecycleEvent", payload);
        await _jobHub.Clients.User(tradie.TradieId)
            .SendAsync("OfferLifecycleEvent", payload);

        // FCM push to tradie (best effort — don't fail the offer if push fails).
        try
        {
            var deviceTokens = await _context.DeviceTokens
                .Where(dt => dt.UserId == tradie.TradieId)
                .Select(dt => dt.Token)
                .ToListAsync();

            foreach (var token in deviceTokens)
            {
                await _push.SendAsync(token,
                    title: "New Job Request",
                    body:  $"{job.Title} — respond within {_offerWindowMinutes} minutes.",
                    data:  new Dictionary<string, string>
                    {
                        ["jobId"]   = job.Id.ToString(),
                        ["offerId"] = offer.Id.ToString(),
                    });
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex,
                "FCM push to tradie {TradieId} failed — offer {OfferId} still active.",
                tradie.TradieId, offer.Id);
        }
    }

    private async Task<Dictionary<string, (double AvgRating, int ReviewCount)>> GetRatingLookupAsync(
        List<string> tradieIds)
    {
        var groups = await _context.Reviews
            .Where(r => tradieIds.Contains(r.RevieweeId))
            .GroupBy(r => r.RevieweeId)
            .Select(g => new
            {
                UserId      = g.Key,
                AvgRating   = g.Average(r => (double)r.Rating),
                ReviewCount = g.Count(),
            })
            .ToListAsync();

        return groups.ToDictionary(
            g => g.UserId,
            g => (g.AvgRating, g.ReviewCount));
    }

    private static string GetInitials(string first, string last)
    {
        var f = string.IsNullOrEmpty(first) ? "" : first[..1].ToUpper();
        var l = string.IsNullOrEmpty(last)  ? "" : last[..1].ToUpper();
        return $"{f}{l}";
    }

    /// <summary>
    /// P8-02: user ids that must never be matched with this homeowner —
    /// tradies they blocked plus tradies who blocked them.
    /// </summary>
    private async Task<HashSet<string>> GetBlockedTradieIdsAsync(string homeownerId)
    {
        if (string.IsNullOrEmpty(homeownerId)) return new HashSet<string>();
        try
        {
            var ids = await _context.UserBlocks
                .Where(b => b.BlockerId == homeownerId || b.BlockedId == homeownerId)
                .Select(b => b.BlockerId == homeownerId ? b.BlockedId : b.BlockerId)
                .ToListAsync();
            return ids.ToHashSet();
        }
        catch (Exception ex)
        {
            // Blocks must never take matching down — fail open and log.
            _logger.LogWarning(ex, "Could not load blocks for homeowner {HomeownerId}.", homeownerId);
            return new HashSet<string>();
        }
    }
}
