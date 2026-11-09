using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Services;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System;
using System.Collections.Generic;
using System.Security.Claims;
using System.Threading;
using System.Threading.Tasks;

namespace FixoApi.Controllers;

/// <summary>
/// Homeowner-facing manual payment endpoints (P4-04):
/// <list type="bullet">
///   <item><c>GET /api/jobs/{id}/payment</c> — instructions and current state</item>
///   <item><c>POST /api/jobs/{id}/payment/upload-receipt</c> — submit the bank receipt</item>
/// </list>
///
/// Controller purity: no EF access here. Ownership, hashing, duplicate detection,
/// blob storage and the job transition all live in <see cref="IPaymentService"/>;
/// this class only unwraps the request and maps domain outcomes to status codes.
/// </summary>
[ApiController]
[Route("api/jobs")]
[Authorize]
public class PaymentController : ControllerBase
{
    private const long MaxReceiptBytes = 10 * 1024 * 1024; // 10 MB
    private static readonly string[] AllowedContentTypes =
        ["image/jpeg", "image/png", "image/heic", "image/heif", "application/pdf"];

    private readonly IPaymentService _payments;
    private readonly ILogger<PaymentController> _logger;

    public PaymentController(IPaymentService payments, ILogger<PaymentController> logger)
    {
        _payments = payments;
        _logger = logger;
    }

    // ── GET /api/jobs/{id}/payment ───────────────────────────────────────────

    /// <summary>
    /// Payment instructions (amount, bank details, job-specific reference) and the
    /// current state of the receipt. Safe to call repeatedly — the payment is
    /// opened on first call, not on every call.
    /// </summary>
    [HttpGet("{jobId:int}/payment")]
    [ProducesResponseType<PaymentStatusDto>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetPayment(int jobId, CancellationToken ct)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        try
        {
            return Ok(await _payments.GetPaymentAsync(jobId, userId, ct));
        }
        catch (KeyNotFoundException)
        {
            // Also covers "job exists but belongs to someone else" — the service
            // throws the same not-found so the endpoint doesn't leak job existence.
            return NotFound(new { message = $"Job {jobId} not found." });
        }
    }

    // ── POST /api/jobs/{id}/payment/upload-receipt ───────────────────────────

    /// <summary>
    /// Upload the bank-transfer receipt. Moves the job to PaymentReview and parks
    /// it in the admin queue until staff verify or reject it.
    /// </summary>
    [HttpPost("{jobId:int}/payment/upload-receipt")]
    [RequestSizeLimit(MaxReceiptBytes + 4096)]
    [ProducesResponseType<PaymentStatusDto>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> UploadReceipt(int jobId, [FromForm] IFormFile receipt, CancellationToken ct)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        if (receipt is null || receipt.Length == 0)
            return BadRequest(new { message = "A receipt file is required." });

        if (receipt.Length > MaxReceiptBytes)
            return BadRequest(new { message = "Receipt exceeds the 10 MB limit." });

        if (!AllowedContentTypes.Contains(receipt.ContentType?.ToLowerInvariant() ?? string.Empty))
            return BadRequest(new { message = "Receipt must be a JPEG, PNG, HEIC or PDF file." });

        try
        {
            var payment = await _payments.UploadReceiptAsync(jobId, userId, new ReceiptUpload
            {
                Content     = receipt.OpenReadStream(),
                FileName    = receipt.FileName,
                ContentType = receipt.ContentType ?? "application/octet-stream",
                Length      = receipt.Length,
            }, ct);

            return Ok(payment);
        }
        catch (KeyNotFoundException)
        {
            return NotFound(new { message = $"Job {jobId} not found." });
        }
        catch (InvalidOperationException ex)
        {
            // Job is not awaiting payment, already verified, or this receipt was
            // used on another payment. All are conflicts with current state.
            _logger.LogInformation("Receipt upload rejected for job {JobId}: {Reason}", jobId, ex.Message);
            return Conflict(new { message = ex.Message });
        }
    }

    private string? GetUserId() => User.FindFirstValue("sub");
}
