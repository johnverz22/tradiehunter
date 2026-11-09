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

    Task<List<ServiceSearchResultDto>> FindTradiesForServiceAsync(
        double latitude, double longitude, int serviceId);

    /// <summary>
    /// Scores and ranks available tradies for a job. Considers trade, radius,
    /// rating, and distance. Used by the sequential offer engine (P3-02).
    /// </summary>
    Task<List<RankedTradieDto>> RankTradiesAsync(Job job, bool broadened = false);

    /// <summary>
    /// Creates an offer for the next top-ranked tradie who has not yet been
    /// offered this job, schedules the Hangfire timeout job, and emits
    /// SignalR + FCM notifications. If no candidates remain, transitions the
    /// job to Cancelled with reason <c>no_tradie_found</c> (P3-03 / P3-06).
    /// </summary>
    Task SendNextOfferAsync(int jobId, string actorUserId);
}
