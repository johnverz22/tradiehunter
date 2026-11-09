using FixoApi.DTOs;
using FixoApi.Services;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace FixoApi.Controllers;

/// <summary>
/// Tradie onboarding & profile resources (P1-06): weekly schedule,
/// per-service rates, and verification credential uploads.
/// All endpoints require a tradie account.
/// </summary>
[ApiController]
[Route("api/tradie")]
[Authorize]
public class TradieController : ControllerBase
{
    private const long MaxCredentialBytes = 10 * 1024 * 1024;

    private readonly IProfileService _profiles;
    private readonly IValidator<UpdateScheduleRequest> _scheduleValidator;
    private readonly IValidator<UpdateRatesRequest> _ratesValidator;

    public TradieController(
        IProfileService profiles,
        IValidator<UpdateScheduleRequest> scheduleValidator,
        IValidator<UpdateRatesRequest> ratesValidator)
    {
        _profiles = profiles;
        _scheduleValidator = scheduleValidator;
        _ratesValidator = ratesValidator;
    }

    private string? CurrentUserId => User.FindFirstValue("sub");

    [HttpGet("earnings")]
    [Authorize(Roles = "Tradie")]
    [ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
    public async Task<IActionResult> GetEarnings(
        [FromServices] FixoApi.Services.Payout.TradieEarningsService earnings)
    {
        var userId = CurrentUserId ?? User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (userId is null) return Unauthorized();
        return Ok(await earnings.GetAsync(userId, DateTime.UtcNow));
    }

    // ── Schedule ─────────────────────────────────────────────────────────────

    [HttpGet("schedule")]
    public async Task<IActionResult> GetSchedule()
    {
        var userId = CurrentUserId;
        if (userId is null) return Unauthorized();

        var schedule = await _profiles.GetScheduleAsync(userId);
        if (schedule is null) return Forbid();
        return Ok(schedule);
    }

    [HttpPost("schedule")]
    public async Task<IActionResult> UpdateSchedule([FromBody] UpdateScheduleRequest request)
    {
        var validation = await _scheduleValidator.ValidateAsync(request);
        if (!validation.IsValid) return BadRequest(validation.Errors);

        var userId = CurrentUserId;
        if (userId is null) return Unauthorized();

        if (!await _profiles.UpdateScheduleAsync(userId, request)) return Forbid();
        return Ok(await _profiles.GetScheduleAsync(userId));
    }

    // ── Rates ────────────────────────────────────────────────────────────────

    [HttpGet("services")]
    public async Task<IActionResult> GetServices() =>
        Ok(await _profiles.GetServicesAsync());

    [HttpGet("rates")]
    public async Task<IActionResult> GetRates()
    {
        var userId = CurrentUserId;
        if (userId is null) return Unauthorized();

        var rates = await _profiles.GetRatesAsync(userId);
        if (rates is null) return Forbid();
        return Ok(rates);
    }

    [HttpPost("rates")]
    public async Task<IActionResult> UpdateRates([FromBody] UpdateRatesRequest request)
    {
        var validation = await _ratesValidator.ValidateAsync(request);
        if (!validation.IsValid) return BadRequest(validation.Errors);

        var userId = CurrentUserId;
        if (userId is null) return Unauthorized();

        var result = await _profiles.UpdateRatesAsync(userId, request);
        if (result is null) return Forbid();
        if (result == false) return BadRequest(new { message = "One or more service ids are unknown." });
        return Ok(await _profiles.GetRatesAsync(userId));
    }

    // ── Credentials ──────────────────────────────────────────────────────────

    [HttpGet("credentials")]
    public async Task<IActionResult> GetCredentials()
    {
        var userId = CurrentUserId;
        if (userId is null) return Unauthorized();

        var creds = await _profiles.GetCredentialsAsync(userId);
        if (creds is null) return Forbid();
        return Ok(creds);
    }

    [HttpPost("credentials")]
    [RequestSizeLimit(MaxCredentialBytes + 4096)]
    public async Task<IActionResult> UploadCredential([FromForm] IFormFile file, [FromForm] string type)
    {
        var userId = CurrentUserId;
        if (userId is null) return Unauthorized();

        if (file is null || file.Length == 0)
            return BadRequest(new { message = "No file provided." });
        if (file.Length > MaxCredentialBytes)
            return BadRequest(new { message = "File exceeds the 10 MB limit." });
        if (string.IsNullOrWhiteSpace(type))
            return BadRequest(new { message = "Credential type is required (License, Insurance, Certification, Other)." });

        var result = await _profiles.UploadCredentialAsync(
            userId, file.OpenReadStream(), file.FileName, file.ContentType, type);

        if (!result.Succeeded)
            return result.Error switch
            {
                "NotTradie" => Forbid(),
                "InvalidType" => BadRequest(new { message = "Unknown credential type." }),
                _ => BadRequest(new { message = "File type is not allowed. Use JPEG, PNG, or PDF." }),
            };

        return Ok(result.Credential);
    }
}
