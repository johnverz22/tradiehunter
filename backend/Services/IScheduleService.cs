using FixoApi.DTOs;

namespace FixoApi.Services;

/// <summary>
/// Job scheduling proposal / confirmation (M4-07).
/// Either participant may propose; the other confirms (or proposes a counter).
/// Only Confirmed-status jobs may be scheduled.
/// </summary>
public interface IScheduleService
{
    /// <summary>
    /// Propose or confirm a schedule for <paramref name="jobId"/>.
    /// If the other party already proposed, this confirms. If the same party
    /// proposes again, it overrides the previous proposal.
    /// </summary>
    Task<ScheduleDto> ProposeOrConfirmAsync(
        int jobId, string userId, ScheduleJobRequest request);

    /// <summary>Get current schedule state for a job.</summary>
    Task<ScheduleDto?> GetScheduleAsync(int jobId);
}
