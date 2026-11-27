using FixoApi.Data;
using FixoApi.Email;
using FixoApi.Enums;
using FixoApi.Options;
using FixoApi.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace FixoApi.Services;

/// <summary>
/// P8-05: expires <c>Requested</c> jobs left untouched past the configured
/// threshold (default 24h). Runs every few minutes (default 5), transitions
/// matches to <c>Cancelled</c> with <c>system_expired</c>, releases pending
/// offers, and notifies the homeowner (push + email fallback via
/// <see cref="INotificationService"/>).
///
/// Plan 10 (Q7.6): also expires open-board project jobs whose
/// <c>QuotesCloseAtUtc</c> has passed and have no remaining valid quotes —
/// transitions to <c>Expired</c> (a terminal state) and notifies the homeowner.
/// </summary>
public class ExpirationWorker : BackgroundService
{
    internal const string SystemUserId = "system";

    private readonly IServiceProvider _services;
    private readonly IConfiguration _config;
    private readonly BrandOptions _brand;
    private readonly ILogger<ExpirationWorker> _logger;

    public ExpirationWorker(
        IServiceProvider services,
        IConfiguration config,
        IOptions<BrandOptions> brandOptions,
        ILogger<ExpirationWorker> logger)
    {
        _services = services;
        _config = config;
        _brand = brandOptions.Value;
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
                await ExpireBoardJobsAsync(stoppingToken);
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

                // E8 wired (§4.2): the email fallback renders through the
                // JobCancelled template — reason + "post it again" CTA — instead
                // of duplicating the copy here.
                await notify.SendToUserAsync(
                    job.HomeownerId,
                    "Job request expired",
                    $"\"{job.Title}\" expired with no tradie response. Post it again any time.",
                    new Dictionary<string, string>
                    {
                        ["jobId"] = job.Id.ToString(),
                        ["type"] = CriticalNotificationTypes.JobExpired,
                    },
                    new CriticalNoticeModel
                    {
                        Heading = $"Your job \"{job.Title}\" has been closed",
                        Preheader = $"Reason: No tradie response within {ThresholdHours:0}h — auto-expired.",
                        Sections =
                        [
                            new EmailSection(
                                "What happened",
                                $"Your job \"{job.Title}\" received no tradie response within the request window and was closed."),
                            new EmailSection(
                                "What you can do",
                                "Your job details are saved — post it again any time from the app."),
                        ],
                        CtaLabel = string.IsNullOrWhiteSpace(_brand.FrontendBaseUrl) ? null : "Post a job again",
                        CtaUrl = string.IsNullOrWhiteSpace(_brand.FrontendBaseUrl)
                            ? null
                            : _brand.FrontendBaseUrl.TrimEnd('/') + "/jobs/new",
                        Brand = _brand,
                    },
                    critical: true,
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

    /// <summary>
    /// Plan 10 (Q7.6): expire open-board project jobs whose <c>QuotesCloseAtUtc</c>
    /// has passed and have no remaining valid (non-expired, non-declined) quotes.
    /// Uses <c>JobStatus.Expired</c> so the mobile "board closed, no quotes" state
    /// is distinguishable from a regular cancellation.
    /// </summary>
    public async Task<int> ExpireBoardJobsAsync(CancellationToken ct)
    {
        using var scope = _services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<FixoDbContext>();
        var jobStatusSvc = scope.ServiceProvider.GetRequiredService<IJobStatusService>();
        var notify = scope.ServiceProvider.GetRequiredService<INotificationService>();
        var audit = scope.ServiceProvider.GetRequiredService<IAuditLogService>();

        var now = DateTime.UtcNow;

        // Board closed AND still Requested AND no valid quote left.
        // Load up to 50 per run; subsequent runs pick up the rest.
        var closedBoards = await db.Jobs
            .Include(j => j.Quotes)
            .Where(j =>
                j.JobType == JobType.Project &&
                j.Status == JobStatus.Requested &&
                j.OpenToBoard &&
                j.QuotesCloseAtUtc != null && j.QuotesCloseAtUtc <= now)
            .OrderBy(j => j.QuotesCloseAtUtc)
            .Take(50)
            .ToListAsync(ct);

        var expired = 0;
        foreach (var job in closedBoards)
        {
            ct.ThrowIfCancellationRequested();

            // A valid quote is Submitted and not past its ValidUntilUtc.
            var hasValidQuote = job.Quotes.Any(q =>
                q.Status == QuoteStatus.Submitted && q.ValidUntilUtc > now);

            if (hasValidQuote)
                continue; // Board closed but homeowner still has quotes to review.

            try
            {
                var before = new { job.Id, Status = job.Status.ToString(), job.QuotesCloseAtUtc };

                await jobStatusSvc.TransitionAsync(
                    job.Id, JobStatus.Expired, SystemUserId, UserRole.Staff,
                    ReasonCode.system_expired,
                    "Board closed with no valid quotes — auto-expired.");

                await audit.LogAsync(SystemUserId, "job.board_expire", "Job", job.Id.ToString(),
                    before, new { job.Id, Status = "Expired", Reason = "board_closed_no_quotes" });

                await notify.SendToUserAsync(
                    job.HomeownerId,
                    "Project closed — no quotes received",
                    $"\"{job.Title}\" closed without receiving any quotes. Post it again any time.",
                    new Dictionary<string, string>
                    {
                        ["jobId"] = job.Id.ToString(),
                        ["type"] = NotificationEvents.BoardJobExpired,
                    },
                    new CriticalNoticeModel
                    {
                        Heading = $"Your project \"{job.Title}\" closed",
                        Preheader = "The quoting window ended without any quotes.",
                        Sections =
                        [
                            new EmailSection(
                                "What happened",
                                $"Your project \"{job.Title}\" was open for quotes, but no tradies submitted one before the window closed."),
                            new EmailSection(
                                "What you can do",
                                "Post it again — it will be visible to nearby tradies straight away."),
                        ],
                        CtaLabel = string.IsNullOrWhiteSpace(_brand.FrontendBaseUrl) ? null : "Post a project again",
                        CtaUrl = string.IsNullOrWhiteSpace(_brand.FrontendBaseUrl)
                            ? null
                            : _brand.FrontendBaseUrl.TrimEnd('/') + "/jobs/new",
                        Brand = _brand,
                    },
                    critical: false,
                    ct);

                expired++;
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Could not expire board job {JobId}.", job.Id);
            }
        }

        if (expired > 0)
            _logger.LogInformation("ExpirationWorker expired {Count} board job(s).", expired);
        return expired;
    }
}
