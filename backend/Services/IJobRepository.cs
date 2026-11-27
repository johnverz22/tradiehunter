using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Models;

namespace FixoApi.Services;

/// <summary>
/// Data-access interface for Job entities. Implementation lives in the
/// Infrastructure layer (EF Core). Kept separate so the service layer
/// and tests can mock persistence without touching EF.
/// </summary>
public interface IJobRepository
{
    Task<Job?> GetByIdAsync(int id, bool includePhotos = false, bool includeOffers = false);
    Task<(List<Job> Items, int TotalCount)> GetForUserAsync(
        string userId, bool isTradie, JobStatus? statusFilter, int page, int pageSize);
    /// <summary>
    /// Quote counts for the given jobs in one grouped read (plan 10 Q1.2). Jobs with
    /// no offers or quotes are present in the result with zero counts.
    /// </summary>
    Task<Dictionary<int, QuoteCountSummary>> GetQuoteCountsAsync(
        IReadOnlyCollection<int> jobIds, DateTime nowUtc);
    Task<Job> CreateAsync(Job job);
    Task UpdateAsync(Job job);
    Task DeleteAsync(Job job);
}
