using FixoApi.DTOs;
using FixoApi.Services;
using FixoApi.Data;
using FixoApi.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace FixoApi.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ProfileController : ControllerBase
{
    private readonly IProfileService _profileService;
    private readonly IValidator<ProfileUpdateDto> _validator;
    private readonly FixoDbContext _context;
    private readonly IAccountFlagService _flags;

    public ProfileController(IProfileService profileService, IValidator<ProfileUpdateDto> validator, FixoDbContext context, IAccountFlagService flags)
    {
        _profileService = profileService;
        _validator = validator;
        _context = context;
        _flags = flags;
    }

    [HttpGet]
    public async Task<IActionResult> GetCurrentProfile()
    {
        var userId = User.FindFirstValue("sub");
        if (userId == null) return Unauthorized();

        var profile = await _profileService.GetProfileAsync(userId, isPublicView: false);
        if (profile == null) return NotFound();

        return Ok(profile);
    }

    [HttpGet("{id}")]
    [AllowAnonymous]
    public async Task<IActionResult> GetPublicProfile(string id)
    {
        var profile = await _profileService.GetProfileAsync(id, isPublicView: true);
        if (profile == null) return NotFound();

        return Ok(profile);
    }

    [HttpPut]
    public async Task<IActionResult> UpdateProfile([FromBody] ProfileUpdateDto dto)
    {
        var validationResult = await _validator.ValidateAsync(dto);
        if (!validationResult.IsValid) return BadRequest(validationResult.Errors);

        var userId = User.FindFirstValue("sub");
        if (userId == null) return Unauthorized();

        var success = await _profileService.UpdateProfileAsync(userId, dto);
        if (!success) return NotFound();

        return NoContent();
    }
    
    [HttpPost("device-token")]
    public async Task<IActionResult> RegisterDeviceToken([FromBody] DeviceTokenRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Token)) return BadRequest("Token cannot be empty.");
        
        var userId = User.FindFirstValue("sub");
        if (userId == null) return Unauthorized();

        var existingToken = await _context.DeviceTokens
            .FirstOrDefaultAsync(dt => dt.UserId == userId && dt.Token == request.Token);

        if (existingToken != null)
        {
            existingToken.LastUpdatedAtUtc = DateTime.UtcNow;
            existingToken.Platform = request.Platform;
        }
        else
        {
            _context.DeviceTokens.Add(new DeviceTokenEntity
            {
                UserId = userId,
                Token = request.Token,
                Platform = request.Platform,
                LastUpdatedAtUtc = DateTime.UtcNow
            });
        }

        await _context.SaveChangesAsync();
        return Ok();
    }

    // ── P8-02: Block & report ────────────────────────────────────────────────

    /// <summary>
    /// Block another user. Idempotent — blocking twice is a no-op.
    /// Blocked users are excluded from future matches in both directions.
    /// </summary>
    [HttpPost("block")]
    public async Task<IActionResult> BlockUser([FromBody] BlockUserRequest request)
    {
        var userId = User.FindFirstValue("sub");
        if (userId == null) return Unauthorized();
        if (string.IsNullOrWhiteSpace(request.BlockedUserId))
            return BadRequest(new { message = "BlockedUserId is required." });
        if (request.BlockedUserId == userId)
            return BadRequest(new { message = "You cannot block yourself." });

        var targetExists = await _context.Users.AnyAsync(u => u.Id == request.BlockedUserId);
        if (!targetExists) return NotFound(new { message = "User not found." });

        var existing = await _context.UserBlocks
            .FirstOrDefaultAsync(b => b.BlockerId == userId && b.BlockedId == request.BlockedUserId);
        if (existing is null)
        {
            _context.UserBlocks.Add(new UserBlock
            {
                BlockerId = userId,
                BlockedId = request.BlockedUserId,
            });
            await _context.SaveChangesAsync();
        }

        return NoContent();
    }

    [HttpDelete("block/{blockedUserId}")]
    public async Task<IActionResult> UnblockUser(string blockedUserId)
    {
        var userId = User.FindFirstValue("sub");
        if (userId == null) return Unauthorized();

        var existing = await _context.UserBlocks
            .FirstOrDefaultAsync(b => b.BlockerId == userId && b.BlockedId == blockedUserId);
        if (existing is null) return NotFound();

        _context.UserBlocks.Remove(existing);
        await _context.SaveChangesAsync();
        return NoContent();
    }

    [HttpGet("blocks")]
    public async Task<IActionResult> GetBlocks()
    {
        var userId = User.FindFirstValue("sub");
        if (userId == null) return Unauthorized();

        var blocks = await _context.UserBlocks
            .Where(b => b.BlockerId == userId)
            .OrderByDescending(b => b.CreatedAtUtc)
            .Select(b => new BlockListItemDto
            {
                BlockedUserId = b.BlockedId,
                CreatedAtUtc = b.CreatedAtUtc,
            })
            .ToListAsync();
        return Ok(blocks);
    }

    /// <summary>
    /// Report another user for abuse. Creates an <c>Abuse</c> account flag
    /// for staff triage (counter-based — 3 reports hit the threshold).
    /// </summary>
    [HttpPost("report")]
    public async Task<IActionResult> ReportUser([FromBody] ReportUserRequest request)
    {
        var userId = User.FindFirstValue("sub");
        if (userId == null) return Unauthorized();
        if (string.IsNullOrWhiteSpace(request.ReportedUserId))
            return BadRequest(new { message = "ReportedUserId is required." });
        if (request.ReportedUserId == userId)
            return BadRequest(new { message = "You cannot report yourself." });

        var targetExists = await _context.Users.AnyAsync(u => u.Id == request.ReportedUserId);
        if (!targetExists) return NotFound(new { message = "User not found." });

        await _flags.LogFlagAsync(
            request.ReportedUserId,
            Enums.AccountFlagType.Abuse,
            string.IsNullOrWhiteSpace(request.Reason)
                ? $"Reported by user {userId}"
                : $"Reported by user {userId}: {request.Reason.Trim()}",
            createdBy: userId);

        return NoContent();
    }

    [HttpPost("availability")]
    public async Task<IActionResult> ToggleAvailability([FromBody] AvailabilityRequest request)
    {
        var userId = User.FindFirstValue("sub");
        if (userId == null) return Unauthorized();

        var tradie = await _context.TradieProfiles.FirstOrDefaultAsync(t => t.UserId == userId);
        if (tradie == null) return Forbid();

        tradie.IsAvailable = request.Available;
        await _context.SaveChangesAsync();

        var updatedProfile = await _profileService.GetProfileAsync(userId, false);
        return Ok(updatedProfile);
    }
}

/// <summary>Request body for POST /api/profile/block (P8-02).</summary>
public class BlockUserRequest
{
    public string BlockedUserId { get; set; } = string.Empty;
}

public class BlockListItemDto
{
    public string BlockedUserId { get; set; } = string.Empty;
    public DateTime CreatedAtUtc { get; set; }
}

/// <summary>Request body for POST /api/profile/report (P8-02).</summary>
public class ReportUserRequest
{
    public string ReportedUserId { get; set; } = string.Empty;
    public string? Reason { get; set; }
}
