using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Models;
using FixoApi.Services;
using FixoApi.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using FluentValidation;
using Google.Apis.Auth;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;

namespace FixoApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly SignInManager<ApplicationUser> _signInManager;
    private readonly TokenService _tokenService;
    private readonly FixoDbContext _context;
    private readonly IValidator<RegisterRequest> _registerValidator;
    private readonly IValidator<LoginRequest> _loginValidator;
    private readonly IConfiguration _config;

    public AuthController(
        UserManager<ApplicationUser> userManager,
        SignInManager<ApplicationUser> signInManager,
        TokenService tokenService,
        FixoDbContext context,
        IValidator<RegisterRequest> registerValidator,
        IValidator<LoginRequest> loginValidator,
        IConfiguration config)
    {
        _userManager = userManager;
        _signInManager = signInManager;
        _tokenService = tokenService;
        _context = context;
        _registerValidator = registerValidator;
        _loginValidator = loginValidator;
        _config = config;
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        var validationResult = await _registerValidator.ValidateAsync(request);
        if (!validationResult.IsValid)
            return BadRequest(validationResult.Errors);

        if (await _userManager.FindByEmailAsync(request.Email) != null)
            return Conflict(new { message = "Email already exists" });

        var user = new ApplicationUser
        {
            UserName = request.Email,
            Email = request.Email,
            FirstName = request.FirstName,
            LastName = request.LastName,
            Role = request.Role
        };

        var result = await _userManager.CreateAsync(user, request.Password);
        if (!result.Succeeded)
            return BadRequest(result.Errors);

        if (request.Role == UserRole.Tradie)
        {
            var tradieProfile = new TradieProfile
            {
                UserId = user.Id,
                TradeType = "General" // stub
            };
            _context.TradieProfiles.Add(tradieProfile);
            await _context.SaveChangesAsync();
        }

        var token = _tokenService.CreateToken(user);
        return Ok(new AuthResponse { Token = token, RefreshToken = "stub-refresh-token" });
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        var validationResult = await _loginValidator.ValidateAsync(request);
        if (!validationResult.IsValid)
            return BadRequest(validationResult.Errors);

        var user = await _userManager.FindByEmailAsync(request.Email);
        if (user == null)
            return Unauthorized(new { message = "Invalid email or password." });
        if (!user.IsActive)
            return Unauthorized(new { message = "Account is deactivated." });

        var result = await _signInManager.CheckPasswordSignInAsync(user, request.Password, false);
        if (!result.Succeeded)
            return Unauthorized(new { message = "Invalid email or password." });

        var token = _tokenService.CreateToken(user);
        return Ok(new AuthResponse { Token = token, RefreshToken = "stub-refresh-token" });
    }

    [HttpPost("refresh")]
    public IActionResult Refresh([FromBody] RefreshRequest request)
    {
        // Stub implementation
        return Ok(new AuthResponse { Token = "new-stub-token", RefreshToken = "new-stub-refresh-token" });
    }

    [HttpPost("google")]
    public async Task<IActionResult> GoogleLogin([FromBody] GoogleAuthRequest request)
    {
        var googleClientId = _config["Authentication:Google:ClientId"]
            ?? throw new InvalidOperationException("Authentication:Google:ClientId is not configured.");

        GoogleJsonWebSignature.Payload payload;
        try
        {
            payload = await GoogleJsonWebSignature.ValidateAsync(
                request.IdToken,
                new GoogleJsonWebSignature.ValidationSettings
                {
                    Audience = new[] { googleClientId }
                });
        }
        catch (InvalidJwtException)
        {
            return Unauthorized(new { message = "Invalid Google token." });
        }

        if (!payload.EmailVerified)
            return Unauthorized(new { message = "Google email is not verified." });

        var user = await _userManager.FindByEmailAsync(payload.Email);
        if (user == null)
        {
            // New user — create a stub account and return RequiresRegistration
            // so the client can show the role-select screen, then call
            // PATCH /api/auth/complete-registration?userId=... with the chosen role.
            user = new ApplicationUser
            {
                UserName  = payload.Email,
                Email     = payload.Email,
                FirstName = payload.GivenName  ?? "Unknown",
                LastName  = payload.FamilyName ?? "Unknown",
            };

            var result = await _userManager.CreateAsync(user);
            if (!result.Succeeded)
                return BadRequest(result.Errors);

            return Ok(new { RequiresRegistration = true, UserId = user.Id });
        }

        if (!user.IsActive)
            return Unauthorized(new { message = "Account is deactivated." });

        var token = _tokenService.CreateToken(user);
        return Ok(new AuthResponse { Token = token, RefreshToken = "stub-refresh-token" });
    }

    [HttpPatch("complete-registration")]
    public async Task<IActionResult> CompleteRegistration(
        [FromBody] CompleteRegistrationRequest request,
        [FromQuery] string userId)
    {
        var user = await _userManager.FindByIdAsync(userId);
        if (user == null) return NotFound();

        user.Role = request.Role;
        await _userManager.UpdateAsync(user);

        if (request.Role == UserRole.Tradie)
        {
            var exists = _context.TradieProfiles.Any(t => t.UserId == user.Id);
            if (!exists)
            {
                var tradieProfile = new TradieProfile
                {
                    UserId    = user.Id,
                    TradeType = "General" // stub
                };
                _context.TradieProfiles.Add(tradieProfile);
                await _context.SaveChangesAsync();
            }
        }

        var token = _tokenService.CreateToken(user);
        return Ok(new AuthResponse { Token = token, RefreshToken = "stub-refresh-token" });
    }
}
