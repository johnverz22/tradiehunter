using FixoApi.Enums;
using FixoApi.Models;
using Microsoft.AspNetCore.Identity;

namespace FixoApi.Services;

/// <summary>
/// Startup service that ensures a default admin user exists.
/// Runs once on app start via IHostedService. Safe to run on every deploy —
/// it does nothing if the admin email already exists.
///
/// Credentials are driven by configuration (AdminSeed section in appsettings.json).
/// Never hardcode production passwords in source — use secrets management
/// (e.g., Docker secrets, Azure Key Vault, AWS Secrets Manager).
/// </summary>
public class AdminSeedService : IHostedService
{
    private readonly IServiceProvider _services;
    private readonly ILogger<AdminSeedService> _logger;

    public AdminSeedService(IServiceProvider services, ILogger<AdminSeedService> logger)
    {
        _services = services;
        _logger = logger;
    }

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        using var scope = _services.CreateScope();
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var config = scope.ServiceProvider.GetRequiredService<IConfiguration>();

        var email = config["AdminSeed:Email"] ?? "admin@fixo.nz";
        var password = config["AdminSeed:Password"] ?? "Admin1!Fixo";
        var firstName = config["AdminSeed:FirstName"] ?? "Fixo";
        var lastName = config["AdminSeed:LastName"] ?? "Admin";

        var existing = await userManager.FindByEmailAsync(email);
        if (existing is not null)
        {
            // P1-03: heal pre-OTP accounts so the seeded admin can still log in.
            if (!existing.EmailVerified)
            {
                existing.EmailVerified = true;
                existing.EmailVerifiedAtUtc ??= DateTime.UtcNow;
                await userManager.UpdateAsync(existing);
            }
            _logger.LogDebug("Admin seed: user {Email} already exists, skipping.", email);
            return;
        }

        var admin = new ApplicationUser
        {
            UserName  = email,
            Email     = email,
            FirstName = firstName,
            LastName  = lastName,
            Role      = UserRole.Superadmin,
            IsActive  = true,
            AuthProvider = "password",
            EmailVerified = true,
            EmailVerifiedAtUtc = DateTime.UtcNow,
        };

        var result = await userManager.CreateAsync(admin, password);

        if (result.Succeeded)
            _logger.LogInformation("Admin seed: created admin user {Email}.", email);
        else
            _logger.LogError(
                "Admin seed: failed to create {Email}: {Errors}",
                email,
                string.Join(", ", result.Errors.Select(e => e.Description)));
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
