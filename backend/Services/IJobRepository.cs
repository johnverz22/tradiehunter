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
    Task<Job?> GetByIdAsync(int id, bool includePhotos = false);
    Task<(List<Job> Items, int TotalCount)> GetForUserAsync(
        string userId, bool isTradie, JobStatus? statusFilter, int page, int pageSize);
    Task<Job> CreateAsync(Job job);
    Task UpdateAsync(Job job);
    Task DeleteAsync(Job job);
}
