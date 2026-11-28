using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Services;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace FixoApi.Controllers;

/// <summary>
/// Admin REST API — all endpoints require staff-level access or higher.
/// Controller is split into logical regions (stats, users, jobs, disputes, settings, metrics)
/// while staying in a single file to avoid over-splitting a thin controller layer.
///
/// Controller Purity: zero EF/DbContext usage here. All data access goes through IAdminService.
/// </summary>
[ApiController]
[Route("api/admin")]
[Authorize(Policy = "RequireStaffRole")]
public class AdminController : ControllerBase
{
    private readonly IAdminService _admin;
    private readonly IPlatformSettings _platformSettings;
    private readonly IPaymentService _payments;
    private readonly FixoApi.Services.Payout.IPayoutService _payouts;
    private readonly ILogger<AdminController> _logger;
    private readonly IValidator<StaffInviteRequest> _inviteValidator;
    private readonly IValidator<SetStaffPasswordRequest> _setPasswordValidator;
    private readonly IValidator<ReviewCredentialRequest> _reviewValidator;
    private readonly IValidator<RejectPaymentRequest> _rejectPaymentValidator;

    public AdminController(
        IAdminService admin,
        IPlatformSettings platformSettings,
        IPaymentService payments,
        FixoApi.Services.Payout.IPayoutService payouts,
        ILogger<AdminController> logger,
        IValidator<StaffInviteRequest> inviteValidator,
        IValidator<SetStaffPasswordRequest> setPasswordValidator,
        IValidator<ReviewCredentialRequest> reviewValidator,
        IValidator<RejectPaymentRequest> rejectPaymentValidator)
    {
        _admin = admin;
        _platformSettings = platformSettings;
        _payments = payments;
        _payouts = payouts;
        _logger = logger;
        _inviteValidator = inviteValidator;
        _setPasswordValidator = setPasswordValidator;
        _reviewValidator = reviewValidator;
        _rejectPaymentValidator = rejectPaymentValidator;
    }

    private string CurrentUserId =>
        User.FindFirstValue("sub") // JWT bearer (mobile/API clients)
        ?? User.FindFirstValue(ClaimTypes.NameIdentifier) // AdminCookie (web)
        ?? throw new InvalidOperationException("User ID claim missing");

    /// <summary>
    /// Actor role recorded on the job status history row. Both staff roles are
    /// permitted to review payments, so the state machine accepts either.
    /// </summary>
    private UserRole CurrentRole() =>
        User.IsInRole("Superadmin") ? UserRole.Superadmin : UserRole.Staff;

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
        var success = await _admin.VerifyUserAsync(id, CurrentUserId);
        if (!success) return NotFound(new { message = "User not found or has no tradie profile." });
        return NoContent();
    }

    /// <summary>Deactivate a user — disables login via Identity lockout. A staff note is required.</summary>
    [HttpPost("users/{id}/deactivate")]
    [ProducesResponseType<UserStatusChangeResult>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DeactivateUser(string id, [FromBody] DeactivateUserRequest request)
    {
        // Prevent self-deactivation
        if (id == CurrentUserId)
            return BadRequest(new { message = "You cannot deactivate your own account." });

        if (string.IsNullOrWhiteSpace(request?.Reason))
            return BadRequest(new { message = "A note is required when deactivating a user." });

        var result = await _admin.DeactivateUserAsync(id, request.Reason, CurrentUserId);
        if (result is null) return NotFound();
        return Ok(result);
    }

    /// <summary>Warn a user: records a flag and emails them the reason.</summary>
    [HttpPost("users/{id}/warn")]
    [ProducesResponseType<UserStatusChangeResult>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> WarnUser(string id, [FromBody] UserReasonRequest request)
    {
        if (id == CurrentUserId)
            return BadRequest(new { message = "You cannot warn your own account." });
        if (string.IsNullOrWhiteSpace(request?.Reason))
            return BadRequest(new { message = "A reason is required." });

        var result = await _admin.WarnUserAsync(id, request.Reason, CurrentUserId);
        return result is null ? NotFound() : Ok(result);
    }

    /// <summary>Suspend a user: locks login and emails them. Reactivate to undo.</summary>
    [HttpPost("users/{id}/suspend")]
    [ProducesResponseType<UserStatusChangeResult>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> SuspendUser(string id, [FromBody] UserReasonRequest request)
    {
        if (id == CurrentUserId)
            return BadRequest(new { message = "You cannot suspend your own account." });
        if (string.IsNullOrWhiteSpace(request?.Reason))
            return BadRequest(new { message = "A reason is required." });

        var result = await _admin.SuspendUserAsync(id, request.Reason, CurrentUserId);
        return result is null ? NotFound() : Ok(result);
    }

    /// <summary>Resolve all open account flags for a user.</summary>
    [HttpPost("users/{id}/flags/resolve")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ResolveUserFlags(string id)
    {
        var count = await _admin.ResolveUserFlagsAsync(id, CurrentUserId);
        return count is null ? NotFound() : NoContent();
    }

    /// <summary>Reactivate a deactivated user — restores login. A staff note is required.</summary>
    [HttpPost("users/{id}/reactivate")]
    [ProducesResponseType<UserStatusChangeResult>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ReactivateUser(string id, [FromBody] ReactivateUserRequest request)
    {
        if (string.IsNullOrWhiteSpace(request?.Note))
            return BadRequest(new { message = "A note is required when reactivating a user." });

        var result = await _admin.ReactivateUserAsync(id, request.Note, CurrentUserId);
        if (result is null) return NotFound();
        return Ok(result);
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
    // STAFF INVITES (P1-05)
    // ══════════════════════════════════════════════════════════════════════════

    /// <summary>Invite a staff member — creates an inactive account and emails a set-password token. Superadmin only.</summary>
    [HttpPost("staff/invite")]
    [Authorize(Policy = "RequireSuperadminRole")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> InviteStaff([FromBody] StaffInviteRequest request)
    {
        var validation = await _inviteValidator.ValidateAsync(request);
        if (!validation.IsValid) return BadRequest(validation.Errors);

        var result = await _admin.InviteStaffAsync(request);
        if (result.Conflict) return Conflict(new { message = result.Error });
        if (!result.Succeeded) return BadRequest(new { message = result.Error });
        return Ok(new { message = "Invite sent." });
    }

    /// <summary>Activate an invited staff account by setting its password. Public — the emailed token authorizes it.</summary>
    [HttpPost("staff/set-password")]
    [AllowAnonymous]
    [ProducesResponseType<AuthResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> SetStaffPassword([FromBody] SetStaffPasswordRequest request)
    {
        var validation = await _setPasswordValidator.ValidateAsync(request);
        if (!validation.IsValid) return BadRequest(validation.Errors);

        var result = await _admin.SetStaffPasswordAsync(request);
        if (!result.Succeeded) return BadRequest(new { message = result.Error });
        return Ok(new AuthResponse { Token = result.Token!, RefreshToken = "stub-refresh-token" });
    }

    // ══════════════════════════════════════════════════════════════════════════
    // CREDENTIAL VERIFICATION (P1-07)
    // ══════════════════════════════════════════════════════════════════════════

    /// <summary>Paginated queue of pending tradie credentials, oldest first.</summary>
    [HttpGet("credentials/pending")]
    [ProducesResponseType<PagedResult<PendingCredentialDto>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetPendingCredentials(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
    {
        if (page < 1) page = 1;
        if (pageSize < 1 || pageSize > 100) pageSize = 20;

        var result = await _admin.GetPendingCredentialsAsync(page, pageSize);
        return Ok(result);
    }

    /// <summary>Approve or reject a tradie credential. Rejections require a reason.</summary>
    [HttpPost("credentials/{id:int}/review")]
    [ProducesResponseType<ReviewedCredentialDto>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ReviewCredential(int id, [FromBody] ReviewCredentialRequest request)
    {
        var validation = await _reviewValidator.ValidateAsync(request);
        if (!validation.IsValid) return BadRequest(validation.Errors);

        var result = await _admin.ReviewCredentialAsync(id, request, CurrentUserId);
        if (result.NotFound) return NotFound(new { message = "Credential not found." });
        if (!result.Succeeded) return BadRequest(new { message = result.Error });
        return Ok(result.Credential);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // PAYMENT QUEUE (P4-05)
    // ══════════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Receipts waiting on review, oldest first. Each row carries a short-lived
    /// SAS URL for the receipt plus the amount and reference staff check against
    /// the trader's bank statement.
    /// </summary>
    [HttpGet("payments/pending")]
    [ProducesResponseType<PagedResult<PendingPaymentDto>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetPendingPayments(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
    {
        if (page < 1) page = 1;
        if (pageSize < 1 || pageSize > 100) pageSize = 20;

        var result = await _payments.GetPendingPaymentsAsync(page, pageSize);
        return Ok(result);
    }

    /// <summary>
    /// v1.7 (P12-16): v2-flow jobs in AwaitingPayment past their due date — the
    /// work was approved and completed but the homeowner has not paid. Staff
    /// follow-up list; the job stays payable and the homeowner is flagged.
    /// </summary>
    [HttpGet("payments/overdue")]
    [ProducesResponseType<PagedResult<OverduePaymentDto>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetOverduePayments(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
    {
        if (page < 1) page = 1;
        if (pageSize < 1 || pageSize > 100) pageSize = 20;

        var result = await _payments.GetOverduePaymentsAsync(page, pageSize);
        return Ok(result);
    }

    /// <summary>Approve a receipt — payment becomes Verified and the job is booked.</summary>
    [HttpPost("payments/{id:int}/verify")]
    [ProducesResponseType<PaymentStatusDto>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> VerifyPayment(int id)
    {
        var result = await _payments.VerifyPaymentAsync(id, CurrentUserId, CurrentRole());
        if (result.NotFound) return NotFound(new { message = "Payment not found." });
        if (result.Conflict) return Conflict(new { message = result.Error });
        if (!result.Succeeded) return BadRequest(new { message = result.Error });
        return Ok(result.Payment);
    }

    /// <summary>Refuse a receipt — the job returns to AwaitingPayment for a re-upload.</summary>
    [HttpPost("payments/{id:int}/reject")]
    [ProducesResponseType<PaymentStatusDto>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> RejectPayment(int id, [FromBody] RejectPaymentRequest request)
    {
        var validation = await _rejectPaymentValidator.ValidateAsync(request);
        if (!validation.IsValid) return BadRequest(validation.Errors);

        var result = await _payments.RejectPaymentAsync(id, CurrentUserId, CurrentRole(), request.Reason);
        if (result.NotFound) return NotFound(new { message = "Payment not found." });
        if (result.Conflict) return Conflict(new { message = result.Error });
        if (!result.Succeeded) return BadRequest(new { message = result.Error });
        return Ok(result.Payment);
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
        var updated = await _admin.UpdateSettingsAsync(dto, CurrentUserId);
        return Ok(updated);
    }

    /// <summary>Quote time windows (plan 10 Q7.2): effective values, DB setting or config fallback.</summary>
    [HttpGet("settings/quotes")]
    [ProducesResponseType<QuoteSettingsDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetQuoteSettings(CancellationToken ct)
    {
        var w = await _platformSettings.GetQuoteWindowsAsync(ct);
        return Ok(new QuoteSettingsDto { BoardWindowHours = w.BoardWindowHours, ValidityHours = w.ValidityHours });
    }

    /// <summary>Change quote time windows (Superadmin only). Applies to jobs and quotes created afterwards.</summary>
    [HttpPut("settings/quotes")]
    [Authorize(Policy = "RequireSuperadminRole")]
    [ProducesResponseType<QuoteSettingsDto>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> UpdateQuoteSettings([FromBody] QuoteSettingsDto dto, CancellationToken ct)
    {
        try
        {
            var w = await _platformSettings.SetQuoteWindowsAsync(
                dto.BoardWindowHours, dto.ValidityHours, CurrentUserId, ct);
            return Ok(new QuoteSettingsDto { BoardWindowHours = w.BoardWindowHours, ValidityHours = w.ValidityHours });
        }
        catch (ArgumentOutOfRangeException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
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

    /// <summary>
    /// Audit log (P8-07): timestamp, admin/user, action, entity + JSON diffs.
    /// Filter by date (?fromUtc & ?toUtc, ISO-8601), action, or user ID.
    /// </summary>
    [HttpGet("audit-logs")]
    [ProducesResponseType<PagedResult<AuditLogDto>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetAuditLogs(
        [FromQuery] DateTime? fromUtc = null,
        [FromQuery] DateTime? toUtc = null,
        [FromQuery] string? action = null,
        [FromQuery] string? userId = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
    {
        if (page < 1) page = 1;
        if (pageSize < 1 || pageSize > 100) pageSize = 20;

        var result = await _admin.GetAuditLogsAsync(fromUtc, toUtc, action, userId, page, pageSize);
        return Ok(result);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // REFUND QUEUE (P6-04 / P6-05)
    // ══════════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Pending refunds queue — jobs cancelled after payment, sorted oldest-first.
    /// Each row shows the homeowner, suggested amounts, and cancellation reason.
    /// </summary>
    [HttpGet("refunds/pending")]
    [ProducesResponseType<PagedResult<RefundSummaryDto>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetPendingRefunds(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
    {
        if (page < 1) page = 1;
        if (pageSize < 1 || pageSize > 100) pageSize = 20;

        var result = await _admin.GetPendingRefundsAsync(page, pageSize);
        return Ok(result);
    }

    /// <summary>
    /// Process a pending refund: upload proof, set final amounts, notify homeowner.
    /// Accepts a multipart/form-data body where the JSON fields are in the `data` part
    /// and an optional proof file (receipt screenshot) is in the `proof` part.
    /// </summary>
    [HttpPost("refunds/{id:guid}/process")]
    [ProducesResponseType<RefundSummaryDto>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> ProcessRefund(Guid id, [FromForm] ProcessRefundForm form)
    {
        if (string.IsNullOrWhiteSpace(form.TransferReference))
            return BadRequest(new { message = "TransferReference is required." });

        var request = new ProcessRefundRequest
        {
            FinalAmount       = form.FinalAmount,
            Penalty           = form.Penalty,
            HoursWorked       = form.HoursWorked,
            TransferReference = form.TransferReference,
        };

        Stream? proofStream = null;
        string? proofContentType = null;
        if (form.Proof != null && form.Proof.Length > 0)
        {
            proofStream = form.Proof.OpenReadStream();
            proofContentType = form.Proof.ContentType;
        }

        var result = await _admin.ProcessRefundAsync(id, request, proofStream, proofContentType, CurrentUserId);

        if (result.NotFound) return NotFound(new { message = "Refund not found." });
        if (result.Conflict) return Conflict(new { message = result.Error });
        if (!result.Succeeded) return BadRequest(new { message = result.Error });
        return Ok(result.Refund);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // PAYOUT QUEUE (P10-06)
    // ══════════════════════════════════════════════════════════════════════════

    [HttpGet("payouts/pending")]
    public async Task<IActionResult> GetPendingPayouts([FromQuery] int page = 1, [FromQuery] int pageSize = 20)
    {
        var result = await _payouts.GetPendingPayoutsAsync(page, pageSize);
        return Ok(result);
    }

    [HttpGet("payouts/batches")]
    public async Task<IActionResult> GetPayoutBatches([FromQuery] int page = 1, [FromQuery] int pageSize = 20)
    {
        var result = await _payouts.GetBatchesAsync(page, pageSize);
        return Ok(result);
    }

    [HttpGet("payouts/batches/{id:guid}")]
    public async Task<IActionResult> GetPayoutBatch(Guid id)
    {
        var batch = await _payouts.GetBatchAsync(id);
        if (batch == null) return NotFound();
        return Ok(batch);
    }

    [HttpPost("payouts/{id:guid}/process")]
    public async Task<IActionResult> ProcessPayout(Guid id, [FromBody] ProcessPayoutRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.TransferReference))
            return BadRequest(new { message = "TransferReference is required." });

        var success = await _payouts.ProcessPayoutAsync(id, request.TransferReference, CurrentUserId);
        if (!success) return NotFound(new { message = "Payout not found or already processed." });
        
        return NoContent();
    }

    [HttpPost("payouts/batches/{id:guid}/complete")]
    public async Task<IActionResult> CompletePayoutBatch(Guid id)
    {
        if (await _payouts.CompleteBatchAsync(id))
            return Ok(new { message = "Batch is complete." });

        var batch = await _payouts.GetBatchAsync(id);
        if (batch == null) return NotFound();

        return BadRequest(new { message = "Cannot complete batch. Not all payouts are processed." });
    }

    // ══════════════════════════════════════════════════════════════════════════
    // STAFF NOTIFICATIONS (plan 09 N6)
    // ══════════════════════════════════════════════════════════════════════════

    [HttpGet("notifications")]
    [ProducesResponseType<StaffNotificationListDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetNotifications(
        [FromQuery] bool unreadOnly = false,
        [FromQuery] int limit = 20,
        CancellationToken ct = default)
    {
        var result = await _admin.GetStaffNotificationsAsync(CurrentUserId, unreadOnly, limit, ct);
        return Ok(result);
    }

    [HttpPost("notifications/{id:int}/read")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> MarkNotificationRead(int id, CancellationToken ct = default)
    {
        var found = await _admin.MarkStaffNotificationReadAsync(id, CurrentUserId, ct);
        return found ? NoContent() : NotFound();
    }

    [HttpPost("notifications/read-all")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> MarkAllNotificationsRead(CancellationToken ct = default)
    {
        await _admin.MarkAllStaffNotificationsReadAsync(CurrentUserId, ct);
        return NoContent();
    }
}
