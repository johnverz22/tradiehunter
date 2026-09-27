using FixoApi.DTOs;
using FixoApi.Enums;

namespace FixoApi.Services;

/// <summary>
/// Formal job-status state machine (M3-05).
/// All status transitions MUST go through <see cref="TransitionAsync"/> —
/// never update Job.Status directly in controllers or other services.
/// </summary>
public interface IJobStatusService
{
    /// <summary>
    /// Transition a job to <paramref name="newStatus"/>.
    /// Validates the transition is legal, writes to <c>JobStatusHistory</c>,
    /// broadcasts <c>JobStatusChanged</c> via SignalR, and sends FCM to both parties.
    /// Throws <see cref="InvalidOperationException"/> for illegal transitions.
    /// </summary>
    Task<JobDto> TransitionAsync(int jobId, JobStatus newStatus, string userId, string? reason = null);
}
