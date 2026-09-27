using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace FixoApi.Services;

/// <summary>
/// Rule-based tradie matching engine (M2-04).
/// Queries tradies where:
///   • trade category matches the job (case-insensitive)
///   • tradie is within <c>Matching:RadiusKm</c> (default 25 km)
///   • tradie IsAvailable == true
///   • tradie IsVerified == true
/// Uses EF Core spatial LINQ (NetTopologySuite) — never raw PostGIS SQL.
/// Rating and ReviewCount are populated from the Reviews table (M4-03).
/// </summary>
public class MatchingService : IMatchingService
{
    private readonly FixoDbContext _context;
    private readonly double _radiusKm;

    private const double MetresPerKm = 1000.0;

    public MatchingService(FixoDbContext context, IConfiguration config)
    {
        _context  = context;
        _radiusKm = config.GetValue<double>("Matching:RadiusKm", 25.0);
    }

    public async Task<List<TradieMatchDto>> FindMatchesAsync(Job job)
    {
        if (job.Location == null)
            return new List<TradieMatchDto>();

        var jobLocation   = job.Location;
        var radiusMetres  = _radiusKm * MetresPerKm;
        var categoryString = job.Category.ToString();

        // EF Core spatial LINQ — Distance() uses the GIST-indexed column.
        var tradies = await _context.TradieProfiles
            .Include(t => t.User)
            .Where(t =>
                t.IsAvailable &&
                t.IsVerified &&
                t.Location != null &&
                t.TradeType.ToLower() == categoryString.ToLower() &&
                t.Location!.Distance(jobLocation) <= radiusMetres)
            .OrderBy(t => t.Location!.Distance(jobLocation))
            .ToListAsync();

        if (tradies.Count == 0)
            return new List<TradieMatchDto>();

        // Fetch aggregated ratings for all matched tradies in a single query (M4-03).
        var tradieIds = tradies.Select(t => t.UserId).ToList();
        var ratingGroups = await _context.Reviews
            .Where(r => tradieIds.Contains(r.RevieweeId))
            .GroupBy(r => r.RevieweeId)
            .Select(g => new
            {
                UserId      = g.Key,
                AvgRating   = g.Average(r => (double)r.Rating),
                ReviewCount = g.Count(),
            })
            .ToListAsync();

        var ratingLookup = ratingGroups.ToDictionary(g => g.UserId);

        return tradies.Select(t =>
        {
            var distanceM  = t.Location!.Distance(jobLocation);
            var distanceKm = distanceM / MetresPerKm;
            var initials   = GetInitials(t.User.FirstName, t.User.LastName);

            ratingLookup.TryGetValue(t.UserId, out var stats);

            return new TradieMatchDto
            {
                TradieId    = t.UserId,
                Initials    = initials,
                Name        = $"{t.User.FirstName} {t.User.LastName}".Trim(),
                Trade       = t.TradeType,
                Verified    = t.IsVerified,
                DistanceKm  = Math.Round(distanceKm, 1),
                Distance    = $"{distanceKm:F1} km away",
                Rating      = stats != null ? Math.Round(stats.AvgRating, 1) : 0,
                ReviewCount = stats?.ReviewCount ?? 0,
            };
        }).ToList();
    }

    private static string GetInitials(string first, string last)
    {
        var f = string.IsNullOrEmpty(first) ? "" : first[..1].ToUpper();
        var l = string.IsNullOrEmpty(last)  ? "" : last[..1].ToUpper();
        return $"{f}{l}";
    }
}
