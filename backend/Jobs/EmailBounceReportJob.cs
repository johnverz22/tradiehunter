using FixoApi.Data;
using FixoApi.Email;
using Microsoft.EntityFrameworkCore;

namespace FixoApi.Jobs;

/// <summary>
/// §5.4/§5.5 observability: weekly LogWarning report of hard-bounced
/// addresses (list hygiene) plus the current send/render counters. Runs as a
/// Hangfire recurring job (registered in Program.cs, cron weekly Monday 06:00 UTC).
/// </summary>
public class EmailBounceReportJob
{
    private readonly FixoDbContext _db;
    private readonly IEmailMetrics _metrics;
    private readonly ILogger<EmailBounceReportJob> _logger;

    public EmailBounceReportJob(
        FixoDbContext db,
        IEmailMetrics metrics,
        ILogger<EmailBounceReportJob> logger)
    {
        _db = db;
        _metrics = metrics;
        _logger = logger;
    }

    public async Task ExecuteAsync(CancellationToken ct = default)
    {
        var since = DateTime.UtcNow.AddDays(-7);
        var bounced = await _db.Users
            .Where(u => u.EmailBouncedAtUtc != null)
            .Select(u => new { u.Id, u.Email, u.EmailBouncedAtUtc })
            .ToListAsync(ct);

        var recent = bounced.Where(u => u.EmailBouncedAtUtc >= since).ToList();

        if (bounced.Count > 0)
        {
            _logger.LogWarning(
                "Email bounce report: {Total} hard-bounced address(es) total, {Recent} in the last 7 days. Addresses: {Addresses}",
                bounced.Count, recent.Count,
                string.Join(", ", bounced.Select(u => $"{u.Email} (at {u.EmailBouncedAtUtc:u})")));
        }
        else
        {
            _logger.LogInformation("Email bounce report: no hard-bounced addresses.");
        }

        var snapshot = _metrics.Snapshot();
        foreach (var (template, m) in snapshot.Templates)
        {
            _logger.LogInformation(
                "Email metrics {Template}: sent {Sent}, failed {Failed}, avg render {AvgRender:F1}ms",
                template, m.Sent, m.Failed, m.AvgRenderMs);
        }
    }
}
