using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Models;
using FixoApi.Services;
using FixoApi.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using FluentValidation;
using Google.Apis.Auth;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Authentication;

namespace FixoApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    // P1-03: OTP policy constants.
    private static readonly TimeSpan OtpLifetime = TimeSpan.FromMinutes(10);
    private static readonly TimeSpan ResendCooldown = TimeSpan.FromSeconds(60);
    private const int MaxVerifyAttempts = 5;
    private const int MaxOtpsPerHour = 5;

    private readonly UserManager<ApplicationUser> _userManager;
    private readonly SignInManager<ApplicationUser> _signInManager;
    private readonly TokenService _tokenService;
    private readonly FixoDbContext _context;
    private readonly IEmailSender _emailSender;
    private readonly IValidator<RegisterRequest> _registerValidator;
    private readonly IValidator<CompleteRegistrationRequest> _completeRegValidator;
    private readonly IValidator<LoginRequest> _loginValidator;
    private readonly IValidator<VerifyEmailRequest> _verifyValidator;
    private readonly IValidator<ResendOtpRequest> _resendValidator;
    private readonly IConfiguration _config;

    public AuthController(
        UserManager<ApplicationUser> userManager,
        SignInManager<ApplicationUser> signInManager,
        TokenService tokenService,
        FixoDbContext context,
        IEmailSender emailSender,
        IValidator<RegisterRequest> registerValidator,
        IValidator<CompleteRegistrationRequest> completeRegValidator,
        IValidator<LoginRequest> loginValidator,
        IValidator<VerifyEmailRequest> verifyValidator,
        IValidator<ResendOtpRequest> resendValidator,
        IConfiguration config)
    {
        _userManager = userManager;
        _signInManager = signInManager;
        _tokenService = tokenService;
        _context = context;
        _emailSender = emailSender;
        _registerValidator = registerValidator;
        _completeRegValidator = completeRegValidator;
        _loginValidator = loginValidator;
        _verifyValidator = verifyValidator;
        _resendValidator = resendValidator;
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
            Role = request.Role,
            AuthProvider = "password",
            EmailVerified = false,
            EmailVerifiedAtUtc = null,
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

        // P1-03: issue an OTP instead of a JWT — the account is unverified.
        var otpCode = await IssueOtpAsync(user);
        await _emailSender.SendOtpAsync(user.Email!, otpCode);

        return Ok(new { RequiresVerification = true, Email = user.Email });
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

        var result = await _signInManager.CheckPasswordSignInAsync(user, request.Password, true);
        if (result.IsLockedOut)
            return StatusCode(429, new { message = "Account temporarily locked. Please try again later." });
        if (!result.Succeeded)
            return Unauthorized(new { message = "Invalid email or password." });

        // P1-03: unverified accounts must complete OTP verification first —
        // no JWT is issued here; the client routes to the OTP screen.
        if (!user.EmailVerified)
            return StatusCode(403, new { RequiresVerification = true, Email = user.Email });

        var (_, authResponse) = await CreateAuthResponseAsync(user);
        return Ok(authResponse);
    }

    [HttpPost("verify-email")]
    public async Task<IActionResult> VerifyEmail([FromBody] VerifyEmailRequest request)
    {
        var validationResult = await _verifyValidator.ValidateAsync(request);
        if (!validationResult.IsValid)
            return BadRequest(validationResult.Errors);

        var user = await _userManager.FindByEmailAsync(request.Email);
        if (user == null)
            return BadRequest(new { message = "Invalid email or code." });

        if (user.EmailVerified)
            return BadRequest(new { message = "Email is already verified." });

        var otp = await _context.EmailOtps
            .Where(o => o.UserId == user.Id
                && o.ConsumedAtUtc == null
                && o.ExpiresAtUtc > DateTime.UtcNow)
            .OrderByDescending(o => o.ExpiresAtUtc)
            .FirstOrDefaultAsync();

        if (otp == null)
            return BadRequest(new { message = "Code has expired. Please request a new one." });

        if (otp.Attempts >= MaxVerifyAttempts)
        {
            // Attempt cap reached — invalidate so a fresh code must be requested.
            otp.ConsumedAtUtc = DateTime.UtcNow;
            await _context.SaveChangesAsync();
            return BadRequest(new { message = "Too many incorrect attempts. Please request a new code." });
        }

        otp.Attempts++;
        if (!VerifyCodeHash(request.Code, otp.CodeHash))
        {
            await _context.SaveChangesAsync();
            return BadRequest(new { message = "Invalid email or code." });
        }

        otp.ConsumedAtUtc = DateTime.UtcNow;
        user.EmailVerified = true;
        user.EmailVerifiedAtUtc = DateTime.UtcNow;
        await _userManager.UpdateAsync(user);
        await _context.SaveChangesAsync();

        var (_, authResponse) = await CreateAuthResponseAsync(user);
        return Ok(authResponse);
    }

    [HttpPost("resend-otp")]
    public async Task<IActionResult> ResendOtp([FromBody] ResendOtpRequest request)
    {
        var validationResult = await _resendValidator.ValidateAsync(request);
        if (!validationResult.IsValid)
            return BadRequest(validationResult.Errors);

        var user = await _userManager.FindByEmailAsync(request.Email);
        if (user == null)
            return BadRequest(new { message = "Invalid email address." });

        if (user.EmailVerified)
            return BadRequest(new { message = "Email is already verified." });

        var now = DateTime.UtcNow;

        // EmailOtp has no CreatedAt — ExpiresAtUtc is the proxy:
        // a code issued at T expires at T + OtpLifetime.
        var recentCutoff = now.AddHours(-1).Add(OtpLifetime);
        var recentCount = await _context.EmailOtps
            .CountAsync(o => o.UserId == user.Id && o.ExpiresAtUtc > recentCutoff);
        if (recentCount >= MaxOtpsPerHour)
            return StatusCode(429, new { message = "Too many codes requested. Please try again later." });

        var latestExpiry = await _context.EmailOtps
            .Where(o => o.UserId == user.Id && o.ConsumedAtUtc == null && o.ExpiresAtUtc > now)
            .OrderByDescending(o => o.ExpiresAtUtc)
            .Select(o => (DateTime?)o.ExpiresAtUtc)
            .FirstOrDefaultAsync();
        if (latestExpiry.HasValue && latestExpiry.Value - OtpLifetime > now - ResendCooldown)
            return StatusCode(429, new { message = "Please wait before requesting a new code." });

        var otpCode = await IssueOtpAsync(user);
        await _emailSender.SendOtpAsync(user.Email!, otpCode);

        return Ok(new { RequiresVerification = true, Email = user.Email });
    }

    [HttpPost("refresh")]
    public async Task<IActionResult> Refresh([FromBody] RefreshRequest request)
    {
        if (string.IsNullOrEmpty(request.RefreshToken))
            return Unauthorized(new { message = "Refresh token is required." });

        var hash = TokenService.HashToken(request.RefreshToken);
        var stored = await _context.RefreshTokens
            .Include(r => r.User)
            .FirstOrDefaultAsync(r => r.TokenHash == hash);

        var now = DateTime.UtcNow;

        // Fail on: not found, already consumed (possible replay), or expired.
        if (stored == null || stored.ConsumedAtUtc != null || stored.ExpiresAtUtc < now)
            return Unauthorized(new { message = "Invalid or expired refresh token." });

        // Rotation-on-use: mark old token consumed then issue a fresh pair.
        var (newJwt, authResponse) = await CreateAuthResponseAsync(stored.User);
        stored.ConsumedAtUtc = now;
        stored.ReplacedByTokenHash = TokenService.HashToken(authResponse.RefreshToken);
        await _context.SaveChangesAsync();

        return Ok(authResponse);
    }

    [HttpDelete("refresh")]
    public async Task<IActionResult> RevokeRefreshToken([FromBody] RefreshRequest request)
    {
        if (string.IsNullOrEmpty(request.RefreshToken))
            return BadRequest();

        var hash = TokenService.HashToken(request.RefreshToken);
        var stored = await _context.RefreshTokens
            .FirstOrDefaultAsync(r => r.TokenHash == hash && r.ConsumedAtUtc == null);

        if (stored != null)
        {
            stored.ConsumedAtUtc = DateTime.UtcNow;
            await _context.SaveChangesAsync();
        }

        // Return 200 even if token wasn't found — idempotent logout.
        return Ok();
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
            // New user — Google has already verified this email, so the OTP
            // flow is skipped. Create a verified stub account and return
            // RequiresRegistration so the client can show the role-select
            // screen, then call PATCH /api/auth/complete-registration?userId=...
            // with the chosen role.
            user = new ApplicationUser
            {
                UserName  = payload.Email,
                Email     = payload.Email,
                FirstName = payload.GivenName  ?? "Unknown",
                LastName  = payload.FamilyName ?? "Unknown",
                AuthProvider = "google",
                EmailVerified = true,
                EmailVerifiedAtUtc = DateTime.UtcNow,
            };

            var result = await _userManager.CreateAsync(user);
            if (!result.Succeeded)
                return BadRequest(result.Errors);

            var regToken = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
            user.RegistrationToken = HashCode(regToken);
            user.RegistrationTokenExpiresAtUtc = DateTime.UtcNow.AddMinutes(10);
            await _userManager.UpdateAsync(user);

            return Ok(new { RequiresRegistration = true, UserId = user.Id, RegistrationToken = regToken });
        }

        if (!user.IsActive)
            return Unauthorized(new { message = "Account is deactivated." });

        // P1-04: only link a Google login to an existing password-based
        // account if that account already completed email verification.
        // Otherwise the OTP gate could be bypassed via Google SSO.
        if (!user.EmailVerified)
            return StatusCode(403, new
            {
                message = "This email is registered but not yet verified. Please complete email verification before linking Google sign-in.",
                RequiresVerification = true,
                Email = user.Email,
            });

        var (_, authResponse) = await CreateAuthResponseAsync(user);
        return Ok(authResponse);
    }

    [HttpPatch("complete-registration")]
    public async Task<IActionResult> CompleteRegistration(
        [FromBody] CompleteRegistrationRequest request,
        [FromQuery] string userId,
        [FromQuery] string registrationToken)
    {
        // P9-02: constrain the role before touching the account — the caller
        // must hold a valid registration token AND may only pick a self-service
        // role (Staff/Superadmin remain invite-only via P9-01).
        var validationResult = await _completeRegValidator.ValidateAsync(request);
        if (!validationResult.IsValid)
            return BadRequest(validationResult.Errors);

        if (string.IsNullOrEmpty(registrationToken))
            return BadRequest(new { message = "Registration token is required." });

        var user = await _userManager.FindByIdAsync(userId);
        if (user == null) return NotFound();

        if (user.RegistrationToken == null || user.RegistrationTokenExpiresAtUtc < DateTime.UtcNow)
            return BadRequest(new { message = "Registration token is missing or expired." });

        if (!VerifyCodeHash(registrationToken, user.RegistrationToken))
            return BadRequest(new { message = "Invalid registration token." });

        // P9-02: consume the token immediately (one-time use) so a captured
        // token cannot be replayed to re-run complete-registration.
        user.RegistrationToken = null;
        user.RegistrationTokenExpiresAtUtc = null;
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

        var (_, authResponse) = await CreateAuthResponseAsync(user);
        return Ok(authResponse);
    }

    [HttpPost("admin-login")]
    public async Task<IActionResult> AdminLogin([FromBody] LoginRequest request)
    {
        var validationResult = await _loginValidator.ValidateAsync(request);
        if (!validationResult.IsValid)
            return BadRequest(validationResult.Errors);

        var user = await _userManager.FindByEmailAsync(request.Email);
        if (user == null)
            return Unauthorized(new { message = "Invalid email or password." });

        if (!user.EmailVerified)
            return StatusCode(403, new { message = "Please verify your email before logging in.", RequiresVerification = true, Email = user.Email });

        if (!user.IsActive)
            return Unauthorized(new { message = "Account is deactivated." });

        if (user.Role != UserRole.Staff && user.Role != UserRole.Superadmin)
            return StatusCode(403, new { message = "Access denied." });

        var result = await _signInManager.CheckPasswordSignInAsync(user, request.Password, true);
        if (result.IsLockedOut)
            return StatusCode(429, new { message = "Account temporarily locked. Please try again later." });
        if (!result.Succeeded)
            return Unauthorized(new { message = "Invalid email or password." });

        var claims = new List<Claim>
        {
            new Claim(ClaimTypes.NameIdentifier, user.Id),
            new Claim(ClaimTypes.Email, user.Email!),
            new Claim(ClaimTypes.Role, user.Role.ToString()),
            new Claim(ClaimTypes.Name, $"{user.FirstName} {user.LastName}")
        };

        var identity = new ClaimsIdentity(claims, "AdminCookie");
        var principal = new ClaimsPrincipal(identity);

        await HttpContext.SignInAsync("AdminCookie", principal);

        return Ok(new { name = $"{user.FirstName} {user.LastName}", role = user.Role.ToString() });
    }

    [HttpPost("admin-logout")]
    public async Task<IActionResult> AdminLogout()
    {
        await HttpContext.SignOutAsync("AdminCookie");
        return Ok();
    }

    [Authorize(Policy = "RequireStaffRole")]
    [HttpGet("admin-me")]
    public IActionResult AdminMe()
    {
        var name = User.FindFirstValue(ClaimTypes.Name);
        var role = User.FindFirstValue(ClaimTypes.Role);
        return Ok(new { name, role });
    }

    // ── P9-06 helpers ─────────────────────────────────────────────────────────

    /// <summary>
    /// Issues a JWT + persisted refresh token for the user and returns
    /// both as an <see cref="AuthResponse"/>. The plaintext refresh token
    /// is included once in the response; only its hash is stored.
    /// </summary>
    private async Task<(string jwt, AuthResponse response)> CreateAuthResponseAsync(ApplicationUser user)
    {
        var jwt = _tokenService.CreateToken(user);
        var (plaintext, hash) = TokenService.GenerateRefreshToken();

        _context.RefreshTokens.Add(new RefreshToken
        {
            UserId       = user.Id,
            TokenHash    = hash,
            ExpiresAtUtc = DateTime.UtcNow.Add(TokenService.RefreshTokenLifetime),
            CreatedAtUtc = DateTime.UtcNow,
        });
        await _context.SaveChangesAsync();

        return (jwt, new AuthResponse { Token = jwt, RefreshToken = plaintext });
    }

    // ── P1-03 helpers ─────────────────────────────────────────────────────────

    /// <summary>
    /// Voids any pending OTPs for the user, stores a fresh hashed code, and
    /// returns the plaintext code for email delivery. Caller sends the email.
    /// </summary>
    private async Task<string> IssueOtpAsync(ApplicationUser user)
    {
        var now = DateTime.UtcNow;
        var pending = await _context.EmailOtps
            .Where(o => o.UserId == user.Id && o.ConsumedAtUtc == null && o.ExpiresAtUtc > now)
            .ToListAsync();
        foreach (var old in pending)
            old.ConsumedAtUtc = now;

        var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
        _context.EmailOtps.Add(new EmailOtp
        {
            UserId = user.Id,
            CodeHash = HashCode(code),
            ExpiresAtUtc = now.Add(OtpLifetime),
            Attempts = 0,
        });
        await _context.SaveChangesAsync();
        return code;
    }

    private static string HashCode(string code)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(code));
        return Convert.ToHexString(bytes);
    }

    private static bool VerifyCodeHash(string code, string expectedHash)
    {
        var actual = SHA256.HashData(Encoding.UTF8.GetBytes(code.Trim()));
        var expected = Convert.FromHexString(expectedHash);
        return CryptographicOperations.FixedTimeEquals(actual, expected);
    }
}
