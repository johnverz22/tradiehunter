using FixoApi.Data;
using FixoApi.Enums;
using FixoApi.Services;
using Microsoft.EntityFrameworkCore;

namespace FixoApi.Services;

/// <summary>
/// P8-05: expires <c>Requested</c> jobs left untouched past the configured
/// threshold (default 24h). Runs every few minutes (default 5), transitions
/// matches to <c>Cancelled</c> with <c>system_expired</c>, releases pending
/// offers, and notifies the homeowner (push + email fallback via
/// <see cref="INotificationService"/>).
/// </summary>
public class ExpirationWorker : BackgroundService
{
    internal const string SystemUserId = "system";

    private readonly IServiceProvider _services;
    private readonly IConfiguration _config;
    private readonly ILogger<ExpirationWorker> _logger;

    public ExpirationWorker(
        IServiceProvider services,
        IConfiguration config,
        ILogger<ExpirationWorker> logger)
    {
        _services = services;
        _config = config;
        _logger = logger;
    }

    private double ThresholdHours => _config.GetValue<double>("JobExpiration:ThresholdHours", 24.0);
    private double IntervalMinutes => _config.GetValue<double>("JobExpiration:IntervalMinutes", 5.0);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation(
            "ExpirationWorker started (threshold={Threshold}h, interval={Interval}m).",
            ThresholdHours, IntervalMinutes);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ExpireOnceAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "ExpirationWorker run failed.");
            }

            try
            {
                await Task.Delay(TimeSpan.FromMinutes(Math.Max(1, IntervalMinutes)), stoppingToken);
            }
            catch (TaskCanceledException) { break; }
        }
    }

    internal async Task<int> ExpireOnceAsync(CancellationToken ct)
    {
        using var scope = _services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<FixoDbContext>();
        var jobs = scope.ServiceProvider.GetRequiredService<IJobStatusService>();
        var notify = scope.ServiceProvider.GetRequiredService<INotificationService>();
        var audit = scope.ServiceProvider.GetRequiredService<IAuditLogService>();

        var cutoff = DateTime.UtcNow.AddHours(-Math.Max(1, ThresholdHours));

        var stale = await db.Jobs
            .Where(j => j.Status == JobStatus.Requested && j.CreatedAtUtc < cutoff)
            .OrderBy(j => j.CreatedAtUtc)
            .Take(50)
            .ToListAsync(ct);

        var expired = 0;
        foreach (var job in stale)
        {
            ct.ThrowIfCancellationRequested();
            try
            {
                var before = new { job.Id, Status = job.Status.ToString(), job.CreatedAtUtc };

                // Release pending offers so tradies stop seeing the job.
                var pending = await db.JobOffers
                    .Where(o => o.JobId == job.Id && o.Response == OfferResponse.Pending)
                    .ToListAsync(ct);
                foreach (var offer in pending)
                    offer.Response = OfferResponse.TimedOut;
                await db.SaveChangesAsync(ct);

                await jobs.TransitionAsync(
                    job.Id, JobStatus.Cancelled, SystemUserId, UserRole.Staff,
                    ReasonCode.system_expired,
                    $"No tradie response within {ThresholdHours:0}h — auto-expired.");

                await audit.LogAsync(SystemUserId, "job.expire", "Job", job.Id.ToString(),
                    before, new { job.Id, Status = "Cancelled", Reason = "system_expired" });

                await notify.SendToUserAsync(
                    job.HomeownerId,
                    "Your job request expired",
                    $"\"{job.Title}\" got no tradie response in time. Try posting again — we're here to help.",
                    new Dictionary<string, string>
                    {
                        ["jobId"] = job.Id.ToString(),
                        ["type"] = CriticalNotificationTypes.JobExpired,
                    },
                    critical: true,
                    emailSubject: "Your Fixo job request expired",
                    emailBody: $"Your job \"{job.Title}\" received no tradie response within the request window and was closed. Post it again from the app any time.",
                    ct);

                expired++;
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Could not expire job {JobId}.", job.Id);
            }
        }

        if (expired > 0)
            _logger.LogInformation("ExpirationWorker expired {Count} job(s).", expired);
        return expired;
    }
}
