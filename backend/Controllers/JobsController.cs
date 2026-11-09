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
using FixoApi.Jobs;
using Hangfire;

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
    private readonly IMatchingService _matching;
    private readonly IScheduleService _scheduleService;
    private readonly IBlobStorageService _blob;
    private readonly FixoDbContext _context;
    private readonly IBackgroundJobClient _hangfire;
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
        IMatchingService matching,
        IScheduleService scheduleService,
        IBlobStorageService blob,
        FixoDbContext context,
        IBackgroundJobClient hangfire,
        IValidator<CreateJobRequest> createValidator,
        IValidator<UpdateJobRequest> updateValidator,
        IValidator<ScheduleJobRequest> scheduleValidator,
        ILogger<JobsController> logger)
    {
        _jobService       = jobService;
        _jobStatusService = jobStatusService;
        _matching         = matching;
        _scheduleService  = scheduleService;
        _blob             = blob;
        _context          = context;
        _hangfire         = hangfire;
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

        try
        {
            var job = await _jobService.CreateJobAsync(userId, request);
            return CreatedAtAction(nameof(GetJob), new { id = job.Id }, job);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
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

    // ── GET /api/jobs/{id}/contact ────────────────────────────────────────────
    // V15-15: counterparty contact (name + phone) for the matched tradie or the
    // homeowner, only once the job is Booked or later and still meaningful.
    // Cancelled/Expired jobs return NotFound — contact ends with the job.

    [HttpGet("{id:int}/contact")]
    public async Task<IActionResult> GetJobContact(int id)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var job = await _context.Jobs.FindAsync(id);
        if (job == null) return NotFound();

        var isHomeowner     = job.HomeownerId == userId;
        var isMatchedTradie = job.MatchedTradieId == userId;
        if (!isHomeowner && !isMatchedTradie) return NotFound();

        var contactable = job.Status is JobStatus.Booked or JobStatus.InProgress
            or JobStatus.AwaitingConfirmation or JobStatus.Completed
            or JobStatus.Disputed;
        if (!contactable || job.MatchedTradieId == null) return NotFound();

        var counterpartyId = isHomeowner ? job.MatchedTradieId : job.HomeownerId;
        var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == counterpartyId);
        if (user == null) return NotFound();

        return Ok(new JobContactDto
        {
            UserId      = user.Id,
            FirstName   = user.FirstName,
            PhoneNumber = user.PhoneNumber,
        });
    }

    // ── PATCH /api/jobs/{id} ──────────────────────────────────────────────────

    [HttpPatch("{id:int}")]
    public async Task<IActionResult> UpdateJob(int id, [FromBody] UpdateJobRequest request)
    {
        var validation = await _updateValidator.ValidateAsync(request);
        if (!validation.IsValid) return BadRequest(validation.Errors);

        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var job = await _context.Jobs.Include(j => j.Offers).FirstOrDefaultAsync(j => j.Id == id);
        if (job == null || job.HomeownerId != userId) return NotFound();

        // P10-13: Job Editing Lockout
        if (job.Status != JobStatus.Requested || job.Offers.Any())
            return Conflict(new { message = "Job cannot be edited once matching has started or offers exist." });

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
    // M2-02: multipart photo upload → Azure Blob → JobPhoto rows.

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
            var blobKey  = await _blob.UploadAsync(file.OpenReadStream(), key, file.ContentType);

            var photo = new JobPhoto
            {
                JobId            = id,
                BlobKey          = blobKey,
                OriginalFileName = file.FileName,
                ContentType      = file.ContentType,
                UploadedAtUtc    = DateTime.UtcNow,
            };
            _context.JobPhotos.Add(photo);
            await _context.SaveChangesAsync();

            uploaded.Add(new JobPhotoDto
            {
                Id               = photo.Id,
                Url              = $"/api/photos/{blobKey}",
                OriginalFileName = file.FileName,
            });
        }

        return Ok(uploaded);
    }

    // ── POST /api/jobs/{id}/match ─────────────────────────────────────────────
    // Kick off sequential offer dispatch. Returns 202 Accepted immediately.
    // Homeowner listens via SignalR for OfferLifecycleEvent updates.

    [HttpPost("{id:int}/match")]
    public async Task<IActionResult> RunMatching(int id)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        // Only the job's homeowner may trigger matching.
        var job = await _context.Jobs.FindAsync(id);
        if (job == null) return NotFound();

        if (job.HomeownerId != userId) return Forbid();
        if (job.Status != JobStatus.Requested)
            return Conflict(new { error = $"Job is in state '{job.Status}' — cannot start matching." });

        // Sequential dispatch runs in a Hangfire job, not on this request:
        // SendNextOfferAsync touches a scoped DbContext, the SignalR hub, and
        // the Hangfire client, so it needs a scope that outlives the request
        // (a bare Task.Run would be torn down when the request completes).
        // The client waits on SignalR OfferLifecycleEvent, not this response.
        _hangfire.Enqueue<SendOfferJob>(j => j.ExecuteAsync(id, userId));

        return Accepted(new { message = "Matching started. Listen for OfferLifecycleEvent via SignalR." });
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
    // M3-06: Booked → InProgress. Tradie only.

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
            var dto = await _jobStatusService.TransitionAsync(id, JobStatus.InProgress, userId, UserRole.Tradie);
            return Ok(dto);
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { error = ex.Message });
        }
    }

    // ── POST /api/jobs/{id}/check-in ──────────────────────────────────────────
    // P5-02: Booked → InProgress. Tradie only. Alias for /start for clarity.

    [HttpPost("{id:int}/check-in")]
    public async Task<IActionResult> CheckIn(int id)
    {
        if (!User.IsInRole("Tradie")) return Forbid();

        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var job = await _context.Jobs.FindAsync(id);
        if (job == null || job.MatchedTradieId != userId) return NotFound();

        try
        {
            var dto = await _jobStatusService.TransitionAsync(id, JobStatus.InProgress, userId, UserRole.Tradie);
            return Ok(dto);
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { error = ex.Message });
        }
    }

    // ── POST /api/jobs/{id}/check-out ─────────────────────────────────────────
    // P5-02: InProgress → AwaitingConfirmation. Tradie only.

    [HttpPost("{id:int}/check-out")]
    public async Task<IActionResult> CheckOut(int id)
    {
        if (!User.IsInRole("Tradie")) return Forbid();

        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var job = await _context.Jobs.FindAsync(id);
        if (job == null || job.MatchedTradieId != userId) return NotFound();

        try
        {
            var dto = await _jobStatusService.TransitionAsync(id, JobStatus.AwaitingConfirmation, userId, UserRole.Tradie);
            return Ok(dto);
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { error = ex.Message });
        }
    }

    // ── POST /api/jobs/{id}/confirm ───────────────────────────────────────────
    // P5-02: AwaitingConfirmation → Completed. Homeowner only.

    [HttpPost("{id:int}/confirm")]
    public async Task<IActionResult> ConfirmCompletion(int id)
    {
        if (User.IsInRole("Tradie")) return Forbid(); // homeowner only

        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var job = await _context.Jobs.FindAsync(id);
        if (job == null || job.HomeownerId != userId) return NotFound();

        try
        {
            var dto = await _jobStatusService.TransitionAsync(id, JobStatus.Completed, userId, UserRole.Homeowner);
            return Ok(dto);
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { error = ex.Message });
        }
    }

    // ── POST /api/jobs/{id}/complete ──────────────────────────────────────────
    // M3-06: InProgress → Complete. Homeowner only. (Legacy endpoint)

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
            var dto = await _jobStatusService.TransitionAsync(id, JobStatus.Completed, userId, UserRole.Homeowner);
            return Ok(dto);
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { error = ex.Message });
        }
    }

    // ── POST /api/jobs/{id}/cancel ────────────────────────────────────────────
    // P6-02: Either party can cancel with a required ReasonCode.

    [HttpPost("{id:int}/cancel")]
    public async Task<IActionResult> CancelJobWithReason(int id, [FromBody] CancelJobRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var job = await _context.Jobs.FindAsync(id);
        if (job == null) return NotFound();

        // Either participant may cancel.
        if (job.HomeownerId != userId && job.MatchedTradieId != userId)
            return Forbid();

        try
        {
            var role = job.HomeownerId == userId ? UserRole.Homeowner : UserRole.Tradie;
            var dto = await _jobStatusService.CancelJobAsync(id, userId, role, request);
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

    // ── POST /api/jobs/{id}/no-show ───────────────────────────────────────────
    /// <summary>
    /// Report a no-show on a booked job.
    /// Homeowners can cancel (CancelJob=true) or reassign (CancelJob=false).
    /// Tradies can only cancel (homeowner is considered absent, partial refund applied).
    /// Available 15 minutes after the scheduled start time.
    /// </summary>
    [HttpPost("{id:int}/no-show")]
    public async Task<IActionResult> ReportNoShow(int id, [FromBody] ReportNoShowRequest request)
    {
        var userId = GetUserId();
        if (userId is null) return Unauthorized();

        var roleStr = User.FindFirstValue(ClaimTypes.Role) ?? string.Empty;
        var actorRole = roleStr switch
        {
            "Homeowner"  => UserRole.Homeowner,
            "Tradie"     => UserRole.Tradie,
            "Staff"      => UserRole.Staff,
            "Superadmin" => UserRole.Superadmin,
            _            => UserRole.Homeowner,
        };

        try
        {
            var dto = await _jobStatusService.ReportNoShowAsync(id, userId, actorRole, request);
            return Ok(dto);
        }
        catch (KeyNotFoundException ex)      { return NotFound(new { message = ex.Message }); }
        catch (InvalidOperationException ex) { return Conflict(new { message = ex.Message }); }
        catch (UnauthorizedAccessException)  { return Forbid(); }
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

    private string? GetUserId() => User.FindFirstValue("sub");
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
