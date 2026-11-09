using FixoApi.DTOs;
using FixoApi.Enums;
using System.Threading.Tasks;

namespace FixoApi.Services;

public interface IJobStatusService
{
    Task<JobDto> TransitionAsync(int jobId, JobStatus newStatus, string userId, UserRole actorRole, ReasonCode? reasonCode = null, string? note = null);

    Task<JobDto> CancelJobAsync(int jobId, string userId, UserRole actorRole, CancelJobRequest request);

    Task<JobDto> ReportNoShowAsync(int jobId, string userId, UserRole actorRole, ReportNoShowRequest request);
}
