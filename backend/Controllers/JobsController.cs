using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Models;
using FixoApi.Services;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;
using FixoApi.Data;

namespace FixoApi.Controllers;

/// <summary>
/// Job CRUD, matching, photo upload, and accept/decline endpoints (M2-02, M2-03).
/// All routes require an authenticated user. Status transitions are enforced in
/// the service layer, never here (Controller Purity rule — .agent/rules/backend.md).
/// </summary>
[ApiController]
[Route("api/jobs")]
[Authorize]
public class JobsController : ControllerBase
{
    private readonly IJobService _jobService;
    private readonly IJobStatusService _jobStatusService;
    private readonly IScheduleService _scheduleService;
    private readonly IBlobStorageService _blob;
    private readonly FixoDbContext _context;
    private readonly IValidator<CreateJobRequest> _createValidator;
    private readonly IValidator<UpdateJobRequest> _updateValidator;
    private readonly IValidator<ScheduleJobRequest> _scheduleValidator;
    private readonly ILogger<JobsController> _logger;

    private const int MaxPhotos      = 5;
    private const long MaxPhotoBytes = 10 * 1024 * 1024; // 10 MB
    private static readonly string[] AllowedContentTypes =
        ["image/jpeg", "image/png", "image/heic", "image/heif"];

    public JobsController(
        IJobService jobService,
        IJobStatusService jobStatusService,
        IScheduleService scheduleService,
        IBlobStorageService blob,
        FixoDbContext context,
        IValidator<CreateJobRequest> createValidator,
        IValidator<UpdateJobRequest> updateValidator,
        IValidator<ScheduleJobRequest> scheduleValidator,
        ILogger<JobsController> logger)
    {
        _jobService       = jobService;
        _jobStatusService = jobStatusService;
        _scheduleService  = scheduleService;
        _blob             = blob;
        _context          = context;
        _createValidator  = createValidator;
        _updateValidator  = updateValidator;
        _scheduleValidator = scheduleValidator;
        _logger           = logger;
    }

    // ── POST /api/jobs ────────────────────────────────────────────────────────

    [HttpPost]
    public async Task<IActionResult> CreateJob([FromBody] CreateJobRequest request)
    {
        var validation = await _createValidator.ValidateAsync(request);
        if (!validation.IsValid) return BadRequest(validation.Errors);

        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var job = await _jobService.CreateJobAsync(userId, request);
        return CreatedAtAction(nameof(GetJob), new { id = job.Id }, job);
    }

    // ── GET /api/jobs?status=&page=&pageSize= ─────────────────────────────────

    [HttpGet]
    public async Task<IActionResult> GetJobs(
        [FromQuery] string? status = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
    {
        var userId    = GetUserId();
        if (userId == null) return Unauthorized();

        var isTradie = User.IsInRole("Tradie");
        var result   = await _jobService.GetJobsForUserAsync(userId, isTradie, status, page, pageSize);
        return Ok(result);
    }

    // ── GET /api/jobs/{id} ────────────────────────────────────────────────────

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetJob(int id)
    {
        var userId   = GetUserId();
        if (userId == null) return Unauthorized();

        var isTradie = User.IsInRole("Tradie");
        var job      = await _jobService.GetJobByIdAsync(id, userId, isTradie);
        return job == null ? NotFound() : Ok(job);
    }

    // ── PATCH /api/jobs/{id} ──────────────────────────────────────────────────

    [HttpPatch("{id:int}")]
    public async Task<IActionResult> UpdateJob(int id, [FromBody] UpdateJobRequest request)
    {
        var validation = await _updateValidator.ValidateAsync(request);
        if (!validation.IsValid) return BadRequest(validation.Errors);

        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var updated = await _jobService.UpdateJobAsync(id, userId, request);
        return updated ? NoContent() : NotFound();
    }

    // ── DELETE /api/jobs/{id} ─────────────────────────────────────────────────

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> CancelJob(int id)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var cancelled = await _jobService.CancelJobAsync(id, userId);
        return cancelled ? NoContent() : NotFound();
    }

    // ── POST /api/jobs/{id}/photos ────────────────────────────────────────────
    // M2-02: multipart photo upload → MinIO → JobPhoto rows.

    [HttpPost("{id:int}/photos")]
    [RequestSizeLimit(MaxPhotos * MaxPhotoBytes + 4096)]
    public async Task<IActionResult> UploadPhotos(int id, [FromForm] List<IFormFile> files)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        // Authorisation: only the job's homeowner can upload.
        var job = await _context.Jobs
            .Include(j => j.Photos)
            .FirstOrDefaultAsync(j => j.Id == id && j.HomeownerId == userId);
        if (job == null) return NotFound();

        if (files.Count == 0)
            return BadRequest("No files provided.");

        var remaining = MaxPhotos - job.Photos.Count;
        if (remaining <= 0)
            return BadRequest($"Maximum {MaxPhotos} photos allowed per job.");

        var toProcess = files.Take(remaining).ToList();
        var uploaded  = new List<JobPhotoDto>();

        foreach (var file in toProcess)
        {
            if (file.Length > MaxPhotoBytes)
                return BadRequest($"File '{file.FileName}' exceeds 10 MB limit.");

            if (!AllowedContentTypes.Contains(file.ContentType.ToLower()))
                return BadRequest($"File type '{file.ContentType}' is not allowed. Use JPEG, PNG, or HEIC.");

            var ext      = Path.GetExtension(file.FileName).ToLowerInvariant();
            var key      = $"jobs/{id}/{Guid.NewGuid()}{ext}";
            var s3Key    = await _blob.UploadAsync(file.OpenReadStream(), key, file.ContentType);

            var photo = new JobPhoto
            {
                JobId            = id,
                S3Key            = s3Key,
                OriginalFileName = file.FileName,
                ContentType      = file.ContentType,
                UploadedAtUtc    = DateTime.UtcNow,
            };
            _context.JobPhotos.Add(photo);
            await _context.SaveChangesAsync();

            uploaded.Add(new JobPhotoDto
            {
                Id               = photo.Id,
                Url              = $"/api/photos/{s3Key}",
                OriginalFileName = file.FileName,
            });
        }

        return Ok(uploaded);
    }

    // ── POST /api/jobs/{id}/match ─────────────────────────────────────────────
    // Trigger matching run. Returns the match list.

    [HttpPost("{id:int}/match")]
    public async Task<IActionResult> RunMatching(int id)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var result = await _jobService.RunMatchingAsync(id, userId);
        return Ok(result);
    }

    // ── GET /api/jobs/{id}/matches ────────────────────────────────────────────

    [HttpGet("{id:int}/matches")]
    public async Task<IActionResult> GetMatches(int id)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var result = await _jobService.GetMatchesAsync(id, userId);
        return Ok(result);
    }

    // ── POST /api/jobs/{id}/requests ──────────────────────────────────────────
    // Homeowner selects a specific tradie.

    [HttpPost("{id:int}/requests")]
    public async Task<IActionResult> RequestTradie(int id, [FromBody] RequestTradieDto dto)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var ok = await _jobService.RequestTradieAsync(id, userId, dto.TradieId);
        return ok ? NoContent() : NotFound();
    }

    // ── POST /api/jobs/{id}/accept ────────────────────────────────────────────

    [HttpPost("{id:int}/accept")]
    public async Task<IActionResult> AcceptJob(int id)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var ok = await _jobService.AcceptJobAsync(id, userId);
        return ok ? NoContent() : NotFound();
    }

    // ── POST /api/jobs/{id}/decline ───────────────────────────────────────────

    [HttpPost("{id:int}/decline")]
    public async Task<IActionResult> DeclineJob(int id)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var ok = await _jobService.DeclineJobAsync(id, userId);
        return ok ? NoContent() : NotFound();
    }

    // ── POST /api/jobs/{id}/start ─────────────────────────────────────────────
    // M3-06: Confirmed → InProgress. Tradie only.

    [HttpPost("{id:int}/start")]
    public async Task<IActionResult> StartJob(int id)
    {
        if (!User.IsInRole("Tradie")) return Forbid();

        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        // Ensure this tradie is matched to the job.
        var job = await _context.Jobs.FindAsync(id);
        if (job == null || job.MatchedTradieId != userId) return NotFound();

        try
        {
            var dto = await _jobStatusService.TransitionAsync(id, JobStatus.InProgress, userId);
            return Ok(dto);
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { error = ex.Message });
        }
    }

    // ── POST /api/jobs/{id}/complete ──────────────────────────────────────────
    // M3-06: InProgress → Complete. Homeowner only.

    [HttpPost("{id:int}/complete")]
    public async Task<IActionResult> CompleteJob(int id)
    {
        if (User.IsInRole("Tradie")) return Forbid(); // homeowner only

        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var job = await _context.Jobs.FindAsync(id);
        if (job == null || job.HomeownerId != userId) return NotFound();

        try
        {
            var dto = await _jobStatusService.TransitionAsync(id, JobStatus.Complete, userId);
            return Ok(dto);
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { error = ex.Message });
        }
    }

    // ── POST /api/jobs/{id}/cancel ────────────────────────────────────────────
    // M3-06: Any → Cancelled. Either party. Requires a reason.

    [HttpPost("{id:int}/cancel")]
    public async Task<IActionResult> CancelJobWithReason(int id, [FromBody] CancelJobRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        if (string.IsNullOrWhiteSpace(request.Reason))
            return BadRequest(new { error = "A cancellation reason is required." });

        var job = await _context.Jobs.FindAsync(id);
        if (job == null) return NotFound();

        // Either participant may cancel.
        if (job.HomeownerId != userId && job.MatchedTradieId != userId)
            return Forbid();

        try
        {
            var dto = await _jobStatusService.TransitionAsync(
                id, JobStatus.Cancelled, userId, request.Reason);
            return Ok(dto);
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { error = ex.Message });
        }
    }

    // ── POST /api/jobs/{id}/schedule ──────────────────────────────────────────
    // M4-07: Propose or confirm a schedule. Only for Confirmed-status jobs.

    [HttpPost("{id:int}/schedule")]
    public async Task<IActionResult> ProposeOrConfirmSchedule(
        int id, [FromBody] ScheduleJobRequest request)
    {
        var validation = await _scheduleValidator.ValidateAsync(request);
        if (!validation.IsValid) return BadRequest(validation.Errors);

        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        try
        {
            var dto = await _scheduleService.ProposeOrConfirmAsync(id, userId, request);
            return Ok(dto);
        }
        catch (KeyNotFoundException)   { return NotFound(); }
        catch (UnauthorizedAccessException ex) { return Forbid(ex.Message); }
        catch (InvalidOperationException ex)   { return Conflict(new { error = ex.Message }); }
    }

    // ── GET /api/jobs/{id}/schedule ───────────────────────────────────────────

    [HttpGet("{id:int}/schedule")]
    public async Task<IActionResult> GetSchedule(int id)
    {
        var dto = await _scheduleService.GetScheduleAsync(id);
        return dto == null ? NotFound() : Ok(dto);
    }

    // ── POST /api/jobs/{id}/flag ──────────────────────────────────────────────
    /// <summary>
    /// Flag a job for admin dispute review. Either participant (homeowner or matched tradie)
    /// can flag. Idempotent — re-flagging updates the reason.
    /// </summary>
    [HttpPost("{id:int}/flag")]
    public async Task<IActionResult> FlagJob(int id, [FromBody] FlagJobRequest request)
    {
        var userId = GetUserId();
        if (userId is null) return Unauthorized();

        var job = await _context.Jobs.FindAsync(id);
        if (job is null) return NotFound();

        if (job.HomeownerId != userId && job.MatchedTradieId != userId)
            return Forbid();

        job.IsFlagged = true;
        job.FlagReason = request.Reason;
        job.FlaggedAtUtc = DateTime.UtcNow;
        job.DisputeStatus = "Open";
        job.UpdatedAtUtc = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        _logger.LogInformation("Job {JobId} flagged by user {UserId}: {Reason}", id, userId, request.Reason);
        return NoContent();
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private string? GetUserId() => User.FindFirstValue(ClaimTypes.NameIdentifier);
}

/// <summary>Request body for POST /api/jobs/{id}/requests.</summary>
public class RequestTradieDto
{
    public string TradieId { get; set; } = string.Empty;
}

/// <summary>Request body for POST /api/jobs/{id}/flag.</summary>
public class FlagJobRequest
{
    public string? Reason { get; set; }
}
