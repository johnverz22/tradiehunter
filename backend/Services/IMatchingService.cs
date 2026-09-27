using FixoApi.DTOs;
using FixoApi.Models;

namespace FixoApi.Services;

/// <summary>
/// Rule-based matching: finds available, verified tradies within the
/// configured radius whose trade category matches the job. No ML.
/// </summary>
public interface IMatchingService
{
    /// <summary>
    /// Returns a list of eligible tradies ordered by distance (ascending).
    /// Never throws — returns empty list when no match is found.
    /// </summary>
    Task<List<TradieMatchDto>> FindMatchesAsync(Job job);
}
