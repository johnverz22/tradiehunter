using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace FixoApi.Services;

public class DisputeService : IDisputeService
{
    /// <summary>How long a dispute-evidence SAS stays valid (P8-03, private bucket).</summary>
    private static readonly TimeSpan EvidenceSasLifetime = TimeSpan.FromMinutes(15);

    private readonly FixoDbContext _context;
    private readonly IBlobStorageService _blobStorage;
    private readonly string _disputesContainer;

    public DisputeService(FixoDbContext context, IBlobStorageService blobStorage, IConfiguration config)
    {
        _context = context;
        _blobStorage = blobStorage;
        _disputesContainer = config["AzureBlob:DisputesContainer"] ?? "th-disputes";
    }

    public async Task<DisputeDto> OpenDisputeAsync(int jobId, string userId, CreateDisputeRequest request)
    {
        var job = await _context.Jobs
            .Include(j => j.Homeowner)
            .Include(j => j.MatchedTradie)
            .FirstOrDefaultAsync(j => j.Id == jobId);
            
        if (job == null) throw new KeyNotFoundException("Job not found.");

        if (job.HomeownerId != userId && job.MatchedTradieId != userId)
        {
            throw new UnauthorizedAccessException("Only parties to the job can open a dispute.");
        }

        var existingDispute = await _context.Disputes.FirstOrDefaultAsync(d => d.JobId == jobId);
        if (existingDispute != null)
        {
            throw new InvalidOperationException("A dispute is already open for this job.");
        }

        var dispute = new Dispute
        {
            JobId = jobId,
            OpenedBy = userId,
            OpenedAtUtc = DateTime.UtcNow,
            Status = DisputeStatus.Open,
            Outcome = DisputeOutcome.Null,
            OpenReason = request.Reason
        };

        _context.Disputes.Add(dispute);

        job.DisputeStatus = DisputeStatus.Open.ToString();
        // Surface on the admin disputes queue — for MVP the queue lists
        // flagged jobs (see AdminDisputeListItemDto), so an open dispute must
        // flag the job or staff can never see or resolve it.
        job.IsFlagged = true;
        job.FlagReason = request.Reason;
        job.FlaggedAtUtc = DateTime.UtcNow;
        job.UpdatedAtUtc = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        return MapToDto(dispute);
    }

    public async Task<DisputeEvidenceDto> AddEvidenceTextAsync(int disputeId, string userId, AddEvidenceTextRequest request)
    {
        var dispute = await _context.Disputes.FindAsync(disputeId);
        if (dispute == null) throw new KeyNotFoundException("Dispute not found.");

        var evidence = new DisputeEvidence
        {
            DisputeId = disputeId,
            SubmittedBy = userId,
            Type = DisputeEvidenceType.Text,
            TextContent = request.TextContent,
            CreatedAtUtc = DateTime.UtcNow
        };

        _context.DisputeEvidences.Add(evidence);
        await _context.SaveChangesAsync();

        return MapEvidenceDto(evidence);
    }

    public async Task<List<DisputeEvidenceDto>> AddEvidenceFilesAsync(int disputeId, string userId, List<IFormFile> files)
    {
        var dispute = await _context.Disputes.FindAsync(disputeId);
        if (dispute == null) throw new KeyNotFoundException("Dispute not found.");

        var results = new List<DisputeEvidenceDto>();

        foreach (var file in files)
        {
            var key = $"disputes/{disputeId}/{Guid.NewGuid()}_{file.FileName}";
            using var stream = file.OpenReadStream();
            // P8-03: dispute evidence lives in the private disputes bucket.
            await _blobStorage.UploadAsync(stream, key, file.ContentType, _disputesContainer);

            var type = file.ContentType.StartsWith("image/") ? DisputeEvidenceType.Photo : DisputeEvidenceType.Document;

            var evidence = new DisputeEvidence
            {
                DisputeId = disputeId,
                SubmittedBy = userId,
                Type = type,
                FileKey = key,
                CreatedAtUtc = DateTime.UtcNow
            };

            _context.DisputeEvidences.Add(evidence);
            results.Add(MapEvidenceDto(evidence));
        }

        await _context.SaveChangesAsync();

        // Hydrate signed URLs (P8-03) — MapEvidenceDto can't be async.
        foreach (var dto in results)
        {
            if (string.IsNullOrEmpty(dto.FileKey)) continue;
            try
            {
                dto.DownloadUrl = (await _blobStorage.GenerateSignedUrl(
                    dto.FileKey, EvidenceSasLifetime, _disputesContainer)).ToString();
            }
            catch { /* best-effort: row still returns without a URL */ }
        }
        return results;
    }

    public async Task<DisputeDto> GetDisputeAsync(int disputeId)
    {
        var dispute = await _context.Disputes
            .Include(d => d.Evidence)
            .FirstOrDefaultAsync(d => d.Id == disputeId);

        if (dispute == null) throw new KeyNotFoundException("Dispute not found.");
        var dto = MapToDto(dispute);
        await HydrateEvidenceUrlsAsync(dto);
        return dto;
    }

    public async Task<List<DisputeDto>> GetOpenDisputesAsync()
    {
        var disputes = await _context.Disputes
            .Include(d => d.Evidence)
            .Where(d => d.Status != DisputeStatus.Resolved)
            .ToListAsync();

        var dtos = disputes.Select(MapToDto).ToList();
        foreach (var dto in dtos)
            await HydrateEvidenceUrlsAsync(dto);
        return dtos;
    }

    /// <summary>P8-03: attach short-lived signed URLs to file evidence.</summary>
    private async Task HydrateEvidenceUrlsAsync(DisputeDto dto)
    {
        foreach (var e in dto.Evidence)
        {
            if (string.IsNullOrEmpty(e.FileKey)) continue;
            try
            {
                e.DownloadUrl = (await _blobStorage.GenerateSignedUrl(
                    e.FileKey, EvidenceSasLifetime, _disputesContainer)).ToString();
            }
            catch { /* best-effort */ }
        }
    }

    private static DisputeDto MapToDto(Dispute dispute)
    {
        return new DisputeDto
        {
            Id = dispute.Id,
            JobId = dispute.JobId,
            OpenedBy = dispute.OpenedBy,
            OpenedAtUtc = dispute.OpenedAtUtc,
            Status = dispute.Status.ToString(),
            Outcome = dispute.Outcome.ToString(),
            DecidedBy = dispute.DecidedBy,
            DecidedAtUtc = dispute.DecidedAtUtc,
            DecisionNote = dispute.DecisionNote,
            OpenReason = dispute.OpenReason,
            ResolvedAtUtc = dispute.ResolvedAtUtc,
            Evidence = dispute.Evidence.Select(MapEvidenceDto).ToList()
        };
    }

    private static DisputeEvidenceDto MapEvidenceDto(DisputeEvidence evidence)
    {
        return new DisputeEvidenceDto
        {
            Id = evidence.Id,
            SubmittedBy = evidence.SubmittedBy,
            Type = evidence.Type.ToString(),
            FileKey = evidence.FileKey,
            TextContent = evidence.TextContent,
            CreatedAtUtc = evidence.CreatedAtUtc
        };
    }
}
