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

    public ProfileController(IProfileService profileService, IValidator<ProfileUpdateDto> validator, FixoDbContext context)
    {
        _profileService = profileService;
        _validator = validator;
        _context = context;
    }

    [HttpGet]
    public async Task<IActionResult> GetCurrentProfile()
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
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

        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (userId == null) return Unauthorized();

        var success = await _profileService.UpdateProfileAsync(userId, dto);
        if (!success) return NotFound();

        return NoContent();
    }
    
    [HttpPost("device-token")]
    public async Task<IActionResult> RegisterDeviceToken([FromBody] DeviceTokenRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Token)) return BadRequest("Token cannot be empty.");
        
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
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
}
