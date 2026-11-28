using FixoApi.Data;
using FixoApi.Email;
using FixoApi.Enums;
using FixoApi.Options;
using FixoApi.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace FixoApi.Jobs;

/// <summary>
/// Plan 10 (Q7.7): notifies nearby eligible tradies when an open-board project
/// job is posted. Batched through <see cref="INotificationService.NotifyManyAsync"/>
/// and capped per run so a dense metro area never triggers an unbounded fan-out.
/// </summary>
public class BoardJobNotifyJob
{
    public const int DefaultNotifyCap = 50;
    private const double MetresPerKm = 1000.0;

    private readonly FixoDbContext _context;
    private readonly INotificationService _notifications;
    private readonly IConfiguration _config;
    private readonly BrandOptions _brand;
    private readonly ILogger<BoardJobNotifyJob> _logger;
    private readonly ITradiePresenceService? _presence;

    public BoardJobNotifyJob(
        FixoDbContext context,
        INotificationService notifications,
        IConfiguration config,
        IOptions<BrandOptions> brand,
        ILogger<BoardJobNotifyJob> logger,
        ITradiePresenceService? presence = null)
    {
        _context = context;
        _notifications = notifications;
        _config = config;
        _brand = brand.Value;
        _logger = logger;
        _presence = presence;
    }

    public async Task ExecuteAsync(int jobId, CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;
        var job = await _context.Jobs
            .AsNoTracking()
            .FirstOrDefaultAsync(j => j.Id == jobId, ct);

        if (job == null || !job.OpenToBoard || job.Status != JobStatus.Requested ||
            job.Location == null || (job.QuotesCloseAtUtc.HasValue && job.QuotesCloseAtUtc <= now))
        {
            return;
        }

        var radiusKm = _config.GetValue<double>("Matching:RadiusKm", 25.0);
        var radiusMetres = radiusKm * MetresPerKm;
        var cap = Math.Clamp(_config.GetValue<int>("Matching:BoardNotifyCap", DefaultNotifyCap), 1, 200);
        var searchArea = Geo.SearchArea(job.Location, radiusMetres);

        var service = await _context.Services.AsNoTracking().FirstOrDefaultAsync(s => s.Id == job.ServiceId, ct);

        var blockedIds = await _context.UserBlocks
            .AsNoTracking()
            .Where(b => b.BlockerId == job.HomeownerId || b.BlockedId == job.HomeownerId)
            .Select(b => b.BlockerId == job.HomeownerId ? b.BlockedId : b.BlockerId)
            .ToListAsync(ct);

        var candidatesQuery = _context.TradieRates
            .AsNoTracking()
            .Where(r =>
                r.ServiceId == job.ServiceId &&
                r.TradieProfile.IsVerified &&
                r.TradieProfile.User.IsActive &&
                r.TradieProfile.IsAvailable &&
                r.TradieProfile.Location != null &&
                !blockedIds.Contains(r.TradieProfile.UserId) &&
                r.TradieProfile.Location.Intersects(searchArea));

        if (service != null && service.RequiresLicence)
        {
            candidatesQuery = candidatesQuery.Where(r =>
                _context.TradieCredentials.Any(c =>
                    c.TradieProfileId == r.TradieProfileId &&
                    c.Status == CredentialStatus.Approved &&
                    c.Type == CredentialType.License));
        }

        var inBox = await candidatesQuery
            .Select(r => new { r.TradieProfile.UserId, r.TradieProfile.Location })
            .ToListAsync(ct);

        var recipientIds = inBox
            .Select(c => (c.UserId, Dist: Geo.HaversineMetres(c.Location!, job.Location)))
            .Where(c => c.Dist <= radiusMetres)
            .OrderBy(c => c.Dist)
            .Select(c => c.UserId)
            .Distinct()
            .Take(cap)
            .ToList();

        if (_presence != null && recipientIds.Count > 0)
        {
            var onlineIds = await _presence.FilterOnlineAsync(recipientIds, ct);
            recipientIds = recipientIds.Where(id => onlineIds.Contains(id)).ToList();
        }

        if (recipientIds.Count == 0)
        {
            _logger.LogInformation("BoardJobNotifyJob: no eligible tradies within {Radius}km for job {JobId}.", radiusKm, jobId);
            return;
        }

        var suburb = job.Address?.Split(',').FirstOrDefault()?.Trim();
        var where = string.IsNullOrWhiteSpace(suburb) ? "nearby" : $"in {suburb}";

        await _notifications.NotifyManyAsync(
            NotificationEvents.BoardJobPosted,
            recipientIds,
            "New project available to quote",
            $"\"{job.Title}\" ({where}) is open for quotes.",
            new Dictionary<string, string>
            {
                ["jobId"] = job.Id.ToString(),
            },
            new CriticalNoticeModel
            {
                Heading = $"New project {where}: \"{job.Title}\"",
                Preheader = "Open the app to view the full scope and submit a quote.",
                Sections =
                [
                    new EmailSection(
                        "Project details",
                        $"A homeowner {where} posted \"{job.Title}\". Open Available jobs in the app to review the scope and submit your quote."),
                ],
                CtaLabel = string.IsNullOrWhiteSpace(_brand.FrontendBaseUrl) ? null : "View available jobs",
                CtaUrl = string.IsNullOrWhiteSpace(_brand.FrontendBaseUrl)
                    ? null
                    : _brand.FrontendBaseUrl.TrimEnd('/') + "/tradie/available-jobs",
                Brand = _brand,
            },
            ct);

        _logger.LogInformation("BoardJobNotifyJob: notified {Count} tradie(s) for job {JobId}.", recipientIds.Count, jobId);
    }
}
