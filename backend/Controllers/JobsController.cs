using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Models;
using FixoApi.Options;
using FixoApi.Services;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
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
    private readonly OfferService _offerService;
    private readonly AdjustmentService _adjustmentService;
    private readonly QuoteService _quoteService;
    private readonly IOptions<JobFlowOptions> _flowOptions;
    private readonly IValidator<CreateJobRequest> _createValidator;
    private readonly IValidator<UpdateJobRequest> _updateValidator;
    private readonly IValidator<ScheduleJobRequest> _scheduleValidator;
    private readonly IValidator<CreateAdjustmentRequest> _adjustmentValidator;
    private readonly IValidator<SubmitQuoteRequest> _quoteValidator;
    private readonly INotificationService _notifications;
    private readonly ILogger<JobsController> _logger;

    private const int MaxPhotos      = 5;
    private const long MaxPhotoBytes = 10 * 1024 * 1024; // 10 MB
    private static readonly string[] AllowedContentTypes =
        ["image/jpeg", "image/png", "image/heic", "image/heif"];
    private static readonly string[] AllowedDocumentTypes =
        ["image/jpeg", "image/png", "image/heic", "image/heif", "application/pdf"];

    public JobsController(
        IJobService jobService,
        IJobStatusService jobStatusService,
        IMatchingService matching,
        IScheduleService scheduleService,
        IBlobStorageService blob,
        FixoDbContext context,
        IBackgroundJobClient hangfire,
        OfferService offerService,
        AdjustmentService adjustmentService,
        QuoteService quoteService,
        IOptions<JobFlowOptions> flowOptions,
        IValidator<CreateJobRequest> createValidator,
        IValidator<UpdateJobRequest> updateValidator,
        IValidator<ScheduleJobRequest> scheduleValidator,
        IValidator<CreateAdjustmentRequest> adjustmentValidator,
        IValidator<SubmitQuoteRequest> quoteValidator,
        INotificationService notifications,
        ILogger<JobsController> logger)
    {
        _jobService       = jobService;
        _jobStatusService = jobStatusService;
        _matching         = matching;
        _scheduleService  = scheduleService;
        _blob             = blob;
        _context          = context;
        _hangfire         = hangfire;
        _offerService     = offerService;
        _adjustmentService = adjustmentService;
        _quoteService     = quoteService;
        _flowOptions      = flowOptions;
        _createValidator  = createValidator;
        _updateValidator  = updateValidator;
        _scheduleValidator = scheduleValidator;
        _adjustmentValidator = adjustmentValidator;
        _quoteValidator   = quoteValidator;
        _notifications    = notifications;
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
            // v1.7 (P12-04): submitting lands on the Choose-a-Tradie screen.
            return CreatedAtAction(nameof(GetJob), new { id = job.Id }, job);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            // OverduePayment posting block and other business rules (P12-12).
            return Conflict(new { message = ex.Message });
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
    // v1.7 (P12-21): size limit covers the raised project attachment cap too.

    [HttpPost("{id:int}/photos")]
    [RequestSizeLimit(MaxPhotoBytes * 12 + 4096)]
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

        // v1.7 (P12-21): project jobs allow more attachments incl. PDFs
        // (config, default 10); hourly jobs keep the 5-photo cap (P10-14).
        var isProject = job.JobType == JobType.Project;
        var maxFiles  = isProject ? Math.Max(MaxPhotos, _flowOptions.Value.ProjectMaxAttachments) : MaxPhotos;
        var allowedTypes = isProject ? AllowedDocumentTypes : AllowedContentTypes;

        var remaining = maxFiles - job.Photos.Count;
        if (remaining <= 0)
            return BadRequest($"Maximum {maxFiles} files allowed per {(isProject ? "project" : "hourly")} job.");

        var toProcess = files.Take(remaining).ToList();
        var uploaded  = new List<JobPhotoDto>();

        foreach (var file in toProcess)
        {
            if (file.Length > MaxPhotoBytes)
                return BadRequest($"File '{file.FileName}' exceeds 10 MB limit.");

            if (!allowedTypes.Contains(file.ContentType.ToLower()))
                return BadRequest(isProject
                    ? $"File type '{file.ContentType}' is not allowed. Use JPEG, PNG, HEIC, or PDF."
                    : $"File type '{file.ContentType}' is not allowed. Use JPEG, PNG, or HEIC.");

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

    // ── GET /api/jobs/{id}/tradies ────────────────────────────────────────
    // v1.7 (P12-05): the Choose-a-Tradie screen. One server-ranked list with the
    // rate for this job's service, rating, distance, availability and GST flag.
    // Query: sort=best|rating|distance|rate, verified, insured, availableNow.

    [HttpGet("{id:int}/tradies")]
    public async Task<IActionResult> GetTradieList(
        int id, [FromQuery] TradieListQuery query)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var job = await _context.Jobs.FindAsync(id);
        if (job == null) return NotFound();
        if (job.HomeownerId != userId) return Forbid();

        var list = await _matching.GetTradieListForJobAsync(job, query);
        return Ok(list);
    }

    // ── POST /api/jobs/{id}/request ──────────────────────────────────
    // v1.7 (P12-08): ask a specific tradie. Creates a JobOffer for exactly that
    // tradie with the rate snapshotted at request time; urgency-aware expiry (D7);
    // optional message is the only pre-acceptance channel (D3). Projects create
    // QuoteRequest offers (up to 3 concurrent, P12-23).

    [HttpPost("{id:int}/request")]
    public async Task<IActionResult> RequestTradie(int id, [FromBody] RequestTradieRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        if (string.IsNullOrWhiteSpace(request?.TradieId))
            return BadRequest(new { error = "tradieId is required." });

        try
        {
            var dto = await _offerService.CreateDirectRequestAsync(id, userId, request);
            return Accepted(dto);
        }
        catch (KeyNotFoundException)
        {
            return NotFound();
        }
        catch (UnauthorizedAccessException)
        {
            return Forbid();
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { error = ex.Message });
        }
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
    // v1.7 (P12-11): body { finalHours, notes } — the tradie submits the actual
    // hours; the server computes LabourAmount/FinalAmount from the rate
    // snapshot + approved adjustments and returns the itemised summary.

    [HttpPost("{id:int}/check-out")]
    public async Task<IActionResult> CheckOut(int id, [FromBody] CheckOutRequest? request)
    {
        if (!User.IsInRole("Tradie")) return Forbid();

        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var job = await _context.Jobs
            .Include(j => j.Adjustments)
            .FirstOrDefaultAsync(j => j.Id == id);
        if (job == null || job.MatchedTradieId != userId) return NotFound();

        try
        {
            // v2 (P12-11): final hours are part of the completion submission.
            if (job.FlowVersion >= 2)
            {
                var finalHours = request?.FinalHours ?? 0m;
                if (finalHours <= 0 || finalHours > 500)
                    return BadRequest(new { error = "finalHours must be between 0.25 and 500." });

                var labour = JobMoney.ComputeLabourAmount(finalHours, job.HourlyRate);
                var adjustmentsTotal = job.Adjustments
                    .Where(a => a.Status == AdjustmentStatus.Approved)
                    .Sum(a => a.Amount);
                var finalAmount = JobMoney.ComputeFinalAmount(labour, adjustmentsTotal);

                job.FinalHours = finalHours;
                job.LabourAmount = labour;
                job.AdjustmentsTotal = Math.Round(adjustmentsTotal, 2);
                job.FinalAmount = finalAmount;
                job.CompletionSubmittedAtUtc = DateTime.UtcNow;
                await _context.SaveChangesAsync();

                var dto = await _jobStatusService.TransitionAsync(id, JobStatus.AwaitingConfirmation, userId, UserRole.Tradie,
                    note: string.IsNullOrWhiteSpace(request?.Notes) ? null : request.Notes);

                var exceeds = JobMoney.ExceedsTolerance(finalAmount, job.EstimatedTotal,
                    _flowOptions.Value.EstimateTolerancePercent, _flowOptions.Value.AutoApproveNoEstimateCap);

                return Ok(new CompletionSummaryDto
                {
                    JobId = id,
                    FinalHours = finalHours,
                    HourlyRate = job.HourlyRate,
                    LabourAmount = labour,
                    AdjustmentsTotal = Math.Round(adjustmentsTotal, 2),
                    FinalAmount = finalAmount,
                    EstimatedTotal = job.EstimatedTotal,
                    ExceedsTolerance = exceeds,
                    ToleranceNote = exceeds
                        ? (job.EstimatedTotal.HasValue
                            ? $"Final amount is more than {_flowOptions.Value.EstimateTolerancePercent:0}% above the ${job.EstimatedTotal:N2} estimate."
                            : $"No estimate was given and ${finalAmount:N2} is above the ${_flowOptions.Value.AutoApproveNoEstimateCap:N0} review cap.")
                        : null,
                    CompletionSubmittedAtUtc = job.CompletionSubmittedAtUtc.Value,
                });
            }

            // v1 legacy: plain transition.
            var legacyDto = await _jobStatusService.TransitionAsync(id, JobStatus.AwaitingConfirmation, userId, UserRole.Tradie);
            return Ok(legacyDto);
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { error = ex.Message });
        }
    }

    // ── POST /api/jobs/{id}/approve ───────────────────────────────────────────
    // v1.7 (P12-11): AwaitingConfirmation → AwaitingPayment. The homeowner
    // reviewed the itemised summary and approves the final amount. Blocked while
    // any price adjustment is still Pending — every extra needs a decision first.

    [HttpPost("{id:int}/approve")]
    public async Task<IActionResult> ApproveCompletion(int id, [FromBody] ApproveCompletionRequest? request)
    {
        if (User.IsInRole("Tradie")) return Forbid(); // homeowner (or staff) only

        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var job = await _context.Jobs
            .Include(j => j.Adjustments)
            .FirstOrDefaultAsync(j => j.Id == id);
        if (job == null) return NotFound();
        if (job.HomeownerId != userId) return Forbid();

        if (job.FlowVersion < 2)
            return Conflict(new { error = "This job was posted under the legacy flow — use confirm." });

        var pending = job.Adjustments.Any(a => a.Status == AdjustmentStatus.Pending);
        if (pending)
            return Conflict(new { error = "Approve is blocked while price adjustments are pending. Decide on every extra cost first." });

        try
        {
            var dto = await _jobStatusService.TransitionAsync(id, JobStatus.AwaitingPayment, userId, UserRole.Homeowner,
                note: string.IsNullOrWhiteSpace(request?.Note) ? "Homeowner approved the final amount." : request.Note);
            return Ok(dto);
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { error = ex.Message });
        }
    }

    // ── POST /api/jobs/{id}/confirm ───────────────────────────────────────────
    // P5-02: AwaitingConfirmation → Completed. Homeowner only.
    // v1 legacy edge. v2 jobs must use /approve (work must be paid before Completed).

    [HttpPost("{id:int}/confirm")]
    public async Task<IActionResult> ConfirmCompletion(int id)
    {
        if (User.IsInRole("Tradie")) return Forbid(); // homeowner only

        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var job = await _context.Jobs.FindAsync(id);
        if (job == null || job.HomeownerId != userId) return NotFound();

        if (job.FlowVersion >= 2)
            return Conflict(new { error = "Use 'Approve & pay' — payment completes this job now." });

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

        await _jobStatusService.RecordFlagAsync(id, userId, request.Reason);

        var counterpartyId = job.HomeownerId == userId ? job.MatchedTradieId : job.HomeownerId;
        var data = new Dictionary<string, string> { ["jobId"] = id.ToString() };
        if (!string.IsNullOrEmpty(counterpartyId))
        {
            await _notifications.NotifyAsync(
                NotificationEvents.DisputeOpened,
                counterpartyId,
                "Job flagged for dispute",
                $"\"{job.Title}\" was flagged for dispute review: {request.Reason}",
                data);
        }

        await _notifications.SendToStaffAsync(new StaffAlert(
            EventKey: NotificationEvents.DisputeStaffAlert,
            EntityKey: $"dispute:{id}",
            Heading: $"Job #{id} flagged for dispute",
            Body: $"\"{job.Title}\" was flagged: {request.Reason}",
            AdminPath: $"/disputes/{id}"));

        _logger.LogInformation("Job {JobId} flagged by user {UserId}: {Reason}", id, userId, request.Reason);
        return NoContent();
    }

    // ── v1.7 (P12-17): price adjustments ──────────────────────────────────────

    /// <summary>Tradie proposes an extra cost (materials, extra labour, travel).</summary>
    [HttpPost("{id:int}/adjustments")]
    public async Task<IActionResult> ProposeAdjustment(int id, [FromBody] CreateAdjustmentRequest request)
    {
        if (!User.IsInRole("Tradie")) return Forbid();

        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var validation = await _adjustmentValidator.ValidateAsync(request);
        if (!validation.IsValid) return BadRequest(validation.Errors);

        try
        {
            var dto = await _adjustmentService.ProposeAsync(id, userId, request);
            return CreatedAtAction(nameof(GetJob), new { id }, dto);
        }
        catch (KeyNotFoundException) { return NotFound(); }
        catch (UnauthorizedAccessException) { return Forbid(); }
        catch (InvalidOperationException ex) { return Conflict(new { error = ex.Message }); }
    }

    /// <summary>Homeowner approves or declines a proposed extra cost (recorded decision).</summary>
    [HttpPost("{id:int}/adjustments/{adjustmentId:int}/respond")]
    public async Task<IActionResult> RespondAdjustment(
        int id, int adjustmentId, [FromBody] RespondAdjustmentRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        try
        {
            var dto = await _adjustmentService.RespondAsync(id, adjustmentId, userId, request);
            return Ok(dto);
        }
        catch (KeyNotFoundException) { return NotFound(); }
        catch (UnauthorizedAccessException) { return Forbid(); }
        catch (InvalidOperationException ex) { return Conflict(new { error = ex.Message }); }
    }

    /// <summary>The proposing tradie withdraws a still-pending extra cost.</summary>
    [HttpPost("{id:int}/adjustments/{adjustmentId:int}/withdraw")]
    public async Task<IActionResult> WithdrawAdjustment(int id, int adjustmentId)
    {
        if (!User.IsInRole("Tradie")) return Forbid();

        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        try
        {
            var dto = await _adjustmentService.WithdrawAsync(id, adjustmentId, userId);
            return Ok(dto);
        }
        catch (KeyNotFoundException) { return NotFound(); }
        catch (UnauthorizedAccessException) { return Forbid(); }
        catch (InvalidOperationException ex) { return Conflict(new { error = ex.Message }); }
    }

    /// <summary>Adjustment history for the job (both parties).</summary>
    [HttpGet("{id:int}/adjustments")]
    public async Task<IActionResult> GetAdjustments(int id)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        try
        {
            var list = await _adjustmentService.ListAsync(id, userId);
            return Ok(list);
        }
        catch (KeyNotFoundException) { return NotFound(); }
        catch (UnauthorizedAccessException) { return Forbid(); }
    }

    /// <summary>
    /// Short-lived read URL for an adjustment's evidence document. Evidence
    /// lives in the private payments container — never a public URL (P12-17).
    /// Only the job's parties can read it.
    /// </summary>
    [HttpGet("{id:int}/adjustments/{adjustmentId:int}/evidence")]
    public async Task<IActionResult> GetAdjustmentEvidence(int id, int adjustmentId)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var job = await _context.Jobs.FindAsync(id);
        if (job == null) return NotFound();
        if (job.HomeownerId != userId && job.MatchedTradieId != userId) return Forbid();

        var adjustment = await _context.JobPriceAdjustments
            .FirstOrDefaultAsync(a => a.Id == adjustmentId && a.JobId == id);
        if (adjustment?.EvidenceFileKey == null) return NotFound();

        var sas = await _blob.GetReadSasUriAsync(
            adjustment.EvidenceFileKey, _flowOptions.Value.AdjustmentsContainer, TimeSpan.FromMinutes(15));
        return Redirect(sas.ToString());
    }

    // ── v1.7 (P12-23): project quotes ─────────────────────────────────────────

    /// <summary>Tradie submits a structured quote for a project job.</summary>
    [HttpPost("{id:int}/quotes")]
    public async Task<IActionResult> SubmitQuote(int id, [FromBody] SubmitQuoteRequest request)
    {
        if (!User.IsInRole("Tradie")) return Forbid();

        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var validation = await _quoteValidator.ValidateAsync(request);
        if (!validation.IsValid) return BadRequest(validation.Errors);

        try
        {
            var dto = await _quoteService.SubmitQuoteAsync(id, userId, request);
            return CreatedAtAction(nameof(GetJob), new { id }, dto);
        }
        catch (KeyNotFoundException) { return NotFound(); }
        catch (UnauthorizedAccessException) { return Forbid(); }
        catch (InvalidOperationException ex) { return Conflict(new { error = ex.Message }); }
    }

    /// <summary>Side-by-side quote comparison data for the homeowner.</summary>
    [HttpGet("{id:int}/quotes")]
    public async Task<IActionResult> GetQuotes(int id)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        try
        {
            var list = await _quoteService.ListQuotesAsync(id, userId);
            return Ok(list);
        }
        catch (KeyNotFoundException) { return NotFound(); }
        catch (UnauthorizedAccessException) { return Forbid(); }
    }

    /// <summary>
    /// Accept one quote — declines the others and books the job. Over the
    /// written-contract threshold the homeowner must confirm a contract exists
    /// first (P12-25): send confirmWrittenContract=true after the notice.
    /// </summary>
    [HttpPost("{id:int}/quotes/{quoteId:int}/accept")]
    public async Task<IActionResult> AcceptQuote(
        int id, int quoteId, [FromBody] AcceptQuoteRequest? request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        try
        {
            var result = await _quoteService.AcceptQuoteAsync(
                id, quoteId, userId, request ?? new AcceptQuoteRequest());

            if (result.RequiresContractConfirmation)
                return Conflict(new
                {
                    requiresWrittenContractConfirmation = true,
                    threshold = result.ThresholdAmount,
                    message = result.Message,
                });

            return Ok(result.Quote);
        }
        catch (KeyNotFoundException) { return NotFound(); }
        catch (UnauthorizedAccessException) { return Forbid(); }
        catch (InvalidOperationException ex) { return Conflict(new { error = ex.Message }); }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private string? GetUserId() => User.FindFirstValue("sub");
}

/// <summary>Request body for POST /api/jobs/{id}/flag.</summary>
public class FlagJobRequest
{
    public string? Reason { get; set; }
}
