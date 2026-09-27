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

    public async Task<Job?> GetByIdAsync(int id, bool includePhotos = false)
    {
        var q = _context.Jobs.AsQueryable();
        if (includePhotos) q = q.Include(j => j.Photos);
        return await q.FirstOrDefaultAsync(j => j.Id == id);
    }

    public async Task<(List<Job> Items, int TotalCount)> GetForUserAsync(
        string userId, bool isTradie, JobStatus? statusFilter, int page, int pageSize)
    {
        var q = isTradie
            ? _context.Jobs.Where(j => j.MatchedTradieId == userId)
            : _context.Jobs.Where(j => j.HomeownerId == userId);

        if (statusFilter.HasValue)
            q = q.Where(j => j.Status == statusFilter.Value);

        var total = await q.CountAsync();
        var items = await q
            .OrderByDescending(j => j.CreatedAtUtc)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Include(j => j.Photos)
            .ToListAsync();

        return (items, total);
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
