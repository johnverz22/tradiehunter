using FixoApi.DTOs;
using FixoApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace FixoApi.Controllers;

/// <summary>
/// Admin REST API — all endpoints require the "Admin" role.
/// Controller is split into logical regions (stats, users, jobs, disputes, settings, metrics)
/// while staying in a single file to avoid over-splitting a thin controller layer.
///
/// Controller Purity: zero EF/DbContext usage here. All data access goes through IAdminService.
/// </summary>
[ApiController]
[Route("api/admin")]
[Authorize(Roles = "Admin")]
public class AdminController : ControllerBase
{
    private readonly IAdminService _admin;
    private readonly ILogger<AdminController> _logger;

    public AdminController(IAdminService admin, ILogger<AdminController> logger)
    {
        _admin = admin;
        _logger = logger;
    }

    private string CurrentUserId =>
        User.FindFirstValue(ClaimTypes.NameIdentifier)
        ?? throw new InvalidOperationException("User ID claim missing");

    // ══════════════════════════════════════════════════════════════════════════
    // STATS
    // ══════════════════════════════════════════════════════════════════════════

    /// <summary>Dashboard summary: totals, jobs-by-status, signups chart.</summary>
    [HttpGet("stats")]
    [ProducesResponseType<AdminStatsDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetStats()
    {
        var stats = await _admin.GetStatsAsync();
        return Ok(stats);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // USERS
    // ══════════════════════════════════════════════════════════════════════════

    /// <summary>Paginated, searchable, filterable user list.</summary>
    [HttpGet("users")]
    [ProducesResponseType<PagedResult<AdminUserListItemDto>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetUsers(
        [FromQuery] string? search = null,
        [FromQuery] string? role = null,
        [FromQuery] bool? isActive = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        [FromQuery] string? sortBy = null,
        [FromQuery] bool sortDesc = true)
    {
        if (page < 1) page = 1;
        if (pageSize < 1 || pageSize > 100) pageSize = 20;

        var result = await _admin.GetUsersAsync(search, role, isActive, page, pageSize, sortBy, sortDesc);
        return Ok(result);
    }

    /// <summary>Full user detail including job history and reviews.</summary>
    [HttpGet("users/{id}")]
    [ProducesResponseType<AdminUserDetailDto>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetUser(string id)
    {
        var user = await _admin.GetUserDetailAsync(id);
        if (user is null) return NotFound();
        return Ok(user);
    }

    /// <summary>Mark a tradie as verified (sets IsVerified on their TradieProfile).</summary>
    [HttpPost("users/{id}/verify")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> VerifyUser(string id)
    {
        var success = await _admin.VerifyUserAsync(id);
        if (!success) return NotFound(new { message = "User not found or has no tradie profile." });
        return NoContent();
    }

    /// <summary>Deactivate a user — disables login via Identity lockout.</summary>
    [HttpPost("users/{id}/deactivate")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DeactivateUser(string id)
    {
        // Prevent self-deactivation
        if (id == CurrentUserId)
            return BadRequest(new { message = "You cannot deactivate your own account." });

        var success = await _admin.DeactivateUserAsync(id);
        if (!success) return NotFound();
        return NoContent();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // JOBS
    // ══════════════════════════════════════════════════════════════════════════

    /// <summary>Paginated job list with optional status filter.</summary>
    [HttpGet("jobs")]
    [ProducesResponseType<PagedResult<AdminJobSummaryDto>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetJobs(
        [FromQuery] string? status = null,
        [FromQuery] string? search = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        [FromQuery] string? sortBy = null,
        [FromQuery] bool sortDesc = true)
    {
        if (page < 1) page = 1;
        if (pageSize < 1 || pageSize > 100) pageSize = 20;

        var result = await _admin.GetJobsAsync(status, search, page, pageSize, sortBy, sortDesc);
        return Ok(result);
    }

    /// <summary>Full job detail: participants, chat transcript, status history, photos.</summary>
    [HttpGet("jobs/{id:int}")]
    [ProducesResponseType<AdminJobDetailDto>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetJob(int id)
    {
        var job = await _admin.GetJobDetailAsync(id);
        if (job is null) return NotFound();
        return Ok(job);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // DISPUTES
    // ══════════════════════════════════════════════════════════════════════════

    /// <summary>List flagged disputes, filterable by dispute status (Open/Resolved/Escalated).</summary>
    [HttpGet("disputes")]
    [ProducesResponseType<PagedResult<AdminDisputeListItemDto>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetDisputes(
        [FromQuery] string? disputeStatus = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
    {
        if (page < 1) page = 1;
        if (pageSize < 1 || pageSize > 100) pageSize = 20;

        var result = await _admin.GetDisputesAsync(disputeStatus, page, pageSize);
        return Ok(result);
    }

    /// <summary>Dispute detail with chat context and both-party info.</summary>
    [HttpGet("disputes/{jobId:int}")]
    [ProducesResponseType<AdminDisputeDetailDto>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetDispute(int jobId)
    {
        var dispute = await _admin.GetDisputeDetailAsync(jobId);
        if (dispute is null) return NotFound();
        return Ok(dispute);
    }

    /// <summary>Resolve, escalate, or cancel a disputed job.</summary>
    [HttpPost("disputes/{jobId:int}/resolve")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ResolveDispute(int jobId, [FromBody] ResolveDisputeRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Action))
            return BadRequest(new { message = "Action is required (Resolved, Escalated, CancelJob)." });

        var success = await _admin.ResolveDisputeAsync(jobId, request, CurrentUserId);
        if (!success) return NotFound(new { message = "Dispute not found or job is not flagged." });
        return NoContent();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // SETTINGS
    // ══════════════════════════════════════════════════════════════════════════

    /// <summary>Get current platform settings (locale, radius, feature flags).</summary>
    [HttpGet("settings")]
    [ProducesResponseType<AdminSettingsDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetSettings()
    {
        var settings = await _admin.GetSettingsAsync();
        return Ok(settings);
    }

    /// <summary>Update platform settings.</summary>
    [HttpPut("settings")]
    [ProducesResponseType<AdminSettingsDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> UpdateSettings([FromBody] AdminSettingsDto dto)
    {
        var updated = await _admin.UpdateSettingsAsync(dto);
        return Ok(updated);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // METRICS
    // ══════════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Success metrics (M5-08): activation rate, match-to-confirmation time,
    /// tradie response rate, review completion rate — time-windowed (7d / 30d / all-time).
    /// </summary>
    [HttpGet("metrics")]
    [ProducesResponseType<AdminMetricsDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetMetrics()
    {
        var metrics = await _admin.GetMetricsAsync();
        return Ok(metrics);
    }
}
