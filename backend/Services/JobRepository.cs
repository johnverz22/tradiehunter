using FixoApi.Data;
using FixoApi.Enums;
using FixoApi.Models;
using Microsoft.EntityFrameworkCore;

namespace FixoApi.Services;

/// <summary>
/// EF Core implementation of <see cref="IJobRepository"/>.
/// Belongs to the Infrastructure layer — depends only on EF Core and the domain models.
/// </summary>
public class JobRepository : IJobRepository
{
    private readonly FixoDbContext _context;

    public JobRepository(FixoDbContext context)
    {
        _context = context;
    }

    public async Task<Job?> GetByIdAsync(int id, bool includePhotos = false, bool includeOffers = false)
    {
        var q = _context.Jobs.AsQueryable();
        if (includePhotos) q = q.Include(j => j.Photos);
        if (includeOffers) q = q.Include(j => j.Offers);
        q = q.Include(j => j.MatchedTradie);
        return await q.FirstOrDefaultAsync(j => j.Id == id);
    }

    public async Task<(List<Job> Items, int TotalCount)> GetForUserAsync(
        string userId, bool isTradie, JobStatus? statusFilter, int page, int pageSize)
    {
        var q = isTradie
            ? _context.Jobs.Where(j => j.MatchedTradieId == userId || j.Offers.Any(o => o.TradieId == userId && o.Response == OfferResponse.Pending))
            : _context.Jobs.Where(j => j.HomeownerId == userId);

        if (statusFilter.HasValue)
            q = q.Where(j => j.Status == statusFilter.Value);

        var total = await q.CountAsync();
        var items = await q
            .OrderByDescending(j => j.CreatedAtUtc)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Include(j => j.Photos)
            .Include(j => j.MatchedTradie)
            .ToListAsync();

        return (items, total);
    }

    public async Task<Dictionary<int, QuoteCountSummary>> GetQuoteCountsAsync(
        IReadOnlyCollection<int> jobIds, DateTime nowUtc)
    {
        var result = jobIds.ToDictionary(id => id, _ => new QuoteCountSummary(0, 0));
        if (jobIds.Count == 0) return result;

        // Two narrow projections (no entity graphs), filtered to the page's job ids.
        var offers = await _context.JobOffers
            .Where(o => jobIds.Contains(o.JobId) && o.Kind == OfferKind.QuoteRequest)
            .Select(o => new { o.JobId, o.Response })
            .ToListAsync();
        var quotes = await _context.Quotes
            .Where(q => jobIds.Contains(q.JobId))
            .Select(q => new { q.JobId, q.Status, q.ValidUntilUtc })
            .ToListAsync();

        // Plan 10 (Q7.8): open-board jobs show no "of M" denominator.
        var openBoardIds = await _context.Jobs
            .Where(j => jobIds.Contains(j.Id) && j.OpenToBoard)
            .Select(j => j.Id)
            .ToHashSetAsync();

        foreach (var id in jobIds)
        {
            result[id] = QuoteCounts.Compute(
                openBoardIds.Contains(id),
                offers.Where(o => o.JobId == id).Select(o => o.Response),
                quotes.Where(q => q.JobId == id).Select(q => (q.Status, q.ValidUntilUtc)),
                nowUtc);
        }
        return result;
    }

    public async Task<Job> CreateAsync(Job job)
    {
        _context.Jobs.Add(job);
        await _context.SaveChangesAsync();
        return job;
    }

    public async Task UpdateAsync(Job job)
    {
        job.UpdatedAtUtc = DateTime.UtcNow;
        _context.Jobs.Update(job);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Job job)
    {
        _context.Jobs.Remove(job);
        await _context.SaveChangesAsync();
    }
}
