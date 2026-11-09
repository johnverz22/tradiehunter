using FixoApi.DTOs;
using Microsoft.AspNetCore.Http;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace FixoApi.Services;

public interface IDisputeService
{
    Task<DisputeDto> OpenDisputeAsync(int jobId, string userId, CreateDisputeRequest request);
    Task<DisputeEvidenceDto> AddEvidenceTextAsync(int disputeId, string userId, AddEvidenceTextRequest request);
    Task<List<DisputeEvidenceDto>> AddEvidenceFilesAsync(int disputeId, string userId, List<IFormFile> files);
    Task<DisputeDto> GetDisputeAsync(int disputeId);
    Task<List<DisputeDto>> GetOpenDisputesAsync();
}
