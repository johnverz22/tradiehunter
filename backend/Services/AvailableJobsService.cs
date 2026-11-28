using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using NetTopologySuite.Geometries;

namespace FixoApi.Services;

/// <summary>
/// Plan 10 (Q7.4): tradie "Available jobs" board.
///
/// A project job appears here when:
///   • JobType == Project
///   • Status == Requested
///   • OpenToBoard == true
///   • QuotesCloseAtUtc &gt; now (window still open)
///   • The tradie is verified and their account is active
///   • The tradie offers the job's service (has a TradieRate row)
///   • The tradie is within radius of the job
///   • The tradie's licence credential is approved when the service RequiresLicence
///   • The tradie has not been blocked by the homeowner (and vice versa)
///   • The tradie has not already submitted a quote for this job
///
/// Address is masked to suburb (P5-01) — the full address stays hidden until Booked.
/// </summary>
public class AvailableJobsService
{
    private readonly FixoDbContext _context;
    private readonly IConfiguration _config;
    private readonly ILogger<AvailableJobsService> _logger;

    private const double MetresPerKm = 1000.0;

    public AvailableJobsService(
        FixoDbContext context,
        IConfiguration config,
        ILogger<AvailableJobsService> logger)
    {
        _context = context;
        _config = config;
        _logger = logger;
    }

    private double RadiusKm => _config.GetValue<double>("Matching:RadiusKm", 25.0);

    /// <summary>
    /// Returns the paged list of available project jobs for the requesting tradie.
    /// </summary>
    public async Task<AvailableJobsResponse> GetAvailableJobsAsync(
        string tradieId, int page, int pageSize, CancellationToken ct = default)
    {
        pageSize = Math.Clamp(pageSize, 1, 50);
        page = Math.Max(1, page);

        var now = DateTime.UtcNow;

        // --- Tradie profile: location + services + credential status ----
        var profile = await _context.TradieProfiles
            .AsNoTracking()
            .Where(p => p.UserId == tradieId)
            .Select(p => new { p.Location, p.UserId, p.IsVerified, IsActive = p.User.IsActive })
            .FirstOrDefaultAsync(ct);

        // Only verified tradies on active accounts may browse the open board.
        if (profile is { IsVerified: false } or { IsActive: false })
        {
            _logger.LogInformation(
                "AvailableJobsService: tradie {TradieId} is unverified or deactivated — returning empty board.", tradieId);
            return new AvailableJobsResponse { Page = page, PageSize = pageSize };
        }

        if (profile?.Location == null)
        {
            _logger.LogInformation(
                "AvailableJobsService: tradie {TradieId} has no location — returning empty board.", tradieId);
            return new AvailableJobsResponse { Page = page, PageSize = pageSize };
        }

        var tradieLocation = profile.Location;
        var radiusMetres = RadiusKm * MetresPerKm;
        var searchArea = Geo.SearchArea(tradieLocation, radiusMetres);

        // Service IDs this tradie has a rate for.
        var tradieServiceIds = await _context.TradieRates
            .AsNoTracking()
            .Where(r => r.TradieProfile.UserId == tradieId)
            .Select(r => r.ServiceId)
            .ToListAsync(ct);

        if (tradieServiceIds.Count == 0)
            return new AvailableJobsResponse { Page = page, PageSize = pageSize };

        // Jobs already quoted by this tradie — excluded from the board.
        var alreadyQuotedJobIds = await _context.Quotes
            .AsNoTracking()
            .Where(q => q.TradieId == tradieId)
            .Select(q => q.JobId)
            .ToListAsync(ct);

        // Homeowners who have blocked this tradie (or been blocked by them).
        var blockedUserIds = await _context.UserBlocks
            .AsNoTracking()
            .Where(b => b.BlockerId == tradieId || b.BlockedId == tradieId)
            .Select(b => b.BlockerId == tradieId ? b.BlockedId : b.BlockerId)
            .ToListAsync(ct);

        // Service IDs that require a licence, intersected with the tradie's services.
        var licencedServiceIds = await _context.Services
            .AsNoTracking()
            .Where(s => tradieServiceIds.Contains(s.Id) && s.RequiresLicence)
            .Select(s => s.Id)
            .ToListAsync(ct);

        // If any licenced services, check whether the tradie holds an approved licence.
        bool hasApprovedLicence = false;
        if (licencedServiceIds.Count > 0)
        {
            hasApprovedLicence = await _context.TradieCredentials
                .AsNoTracking()
                .AnyAsync(c =>
                    c.TradieProfile.UserId == tradieId &&
                    c.Status == CredentialStatus.Approved &&
                    c.Type == CredentialType.License, ct);
        }

        // Build the unlicenced service set for use below.
        var unlicencedServiceIds = tradieServiceIds.Except(licencedServiceIds).ToHashSet();
        // If the tradie has the licence, all their services are quottable.
        var quottableServiceIds = hasApprovedLicence
            ? tradieServiceIds.ToHashSet()
            : unlicencedServiceIds;

        if (quottableServiceIds.Count == 0)
            return new AvailableJobsResponse { Page = page, PageSize = pageSize };

        // --- Open project jobs in the bounding-box area ----------------
        // Bounding-box prefilter in SQL (EF spatial LINQ); exact Haversine
        // radius filter in memory before paging (corners of the box exceed radius).
        var inBox = await _context.Jobs
            .AsNoTracking()
            .Where(j =>
                j.JobType == JobType.Project &&
                j.Status == JobStatus.Requested &&
                j.OpenToBoard &&
                j.QuotesCloseAtUtc != null && j.QuotesCloseAtUtc > now &&
                quottableServiceIds.Contains(j.ServiceId) &&
                !alreadyQuotedJobIds.Contains(j.Id) &&
                !blockedUserIds.Contains(j.HomeownerId) &&
                j.Location != null &&
                j.Location.Intersects(searchArea))
            .OrderByDescending(j => j.CreatedAtUtc)
            .Select(j => new { j.Id, j.Location })
            .ToListAsync(ct);

        var matchingIds = inBox
            .Where(j => Geo.HaversineMetres(j.Location!, tradieLocation) <= radiusMetres)
            .Select(j => j.Id)
            .ToList();

        var totalCount = matchingIds.Count;
        var pageIds = matchingIds
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToList();

        var jobs = pageIds.Count > 0
            ? await _context.Jobs
                .AsNoTracking()
                .Include(j => j.Photos)
                .Where(j => pageIds.Contains(j.Id))
                .OrderByDescending(j => j.CreatedAtUtc)
                .ToListAsync(ct)
            : new List<Job>();

        // Quote counts for these jobs (how many quotes already received).
        var jobIds = jobs.Select(j => j.Id).ToList();
        var quoteCounts = jobIds.Count > 0
            ? await _context.Quotes
                .AsNoTracking()
                .Where(q => jobIds.Contains(q.JobId) && q.Status == QuoteStatus.Submitted && q.ValidUntilUtc > now)
                .GroupBy(q => q.JobId)
                .Select(g => new { JobId = g.Key, Count = g.Count() })
                .ToDictionaryAsync(x => x.JobId, x => x.Count, ct)
            : new Dictionary<int, int>();

        var items = jobs.Select(j =>
        {
            var suburb = j.Address?.Split(',').FirstOrDefault()?.Trim() ?? "";
            double? distKm = j.Location != null
                ? Math.Round(Geo.HaversineMetres(j.Location, tradieLocation) / MetresPerKm, 1)
                : null;

            quoteCounts.TryGetValue(j.Id, out var received);

            return new AvailableJobDto
            {
                Id = j.Id,
                Title = j.Title,
                Category = j.Category.ToString(),
                Description = j.Description,
                Urgency = j.Urgency.ToString(),
                ServiceId = j.ServiceId,
                Suburb = suburb,
                DistanceKm = distKm,
                ScopeNotes = j.ScopeNotes,
                BudgetMin = j.BudgetMin,
                BudgetMax = j.BudgetMax,
                MaterialsBy = j.MaterialsBy.ToString(),
                SiteVisitWelcome = j.SiteVisitWelcome,
                TimingPreference = j.TimingPreference.ToString(),
                ScheduledStartUtc = j.ScheduledStartUtc,
                ScheduledEndUtc = j.ScheduledEndUtc,
                QuotesReceived = received,
                QuotesCloseAtUtc = j.QuotesCloseAtUtc!.Value,
                CreatedAtUtc = j.CreatedAtUtc,
                Photos = j.Photos.Select(p => new JobPhotoDto
                {
                    Id = p.Id,
                    Url = $"/api/photos/{p.BlobKey}",
                    OriginalFileName = p.OriginalFileName,
                }).ToList(),
            };
        }).ToList();

        return new AvailableJobsResponse
        {
            Items = items,
            TotalCount = totalCount,
            Page = page,
            PageSize = pageSize,
        };
    }
}
