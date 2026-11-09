using FixoApi.Services;
using Hangfire;
using Microsoft.Extensions.Logging;

namespace FixoApi.Jobs;

/// <summary>
/// Hangfire entry point for starting a sequential matching run (P3-03).
///
/// This exists so the work happens in its own DI scope rather than on the
/// request that triggered it: <see cref="IMatchingService"/> is scoped and
/// needs a live <c>FixoDbContext</c>, the SignalR hub context, and the
/// Hangfire client for the per-offer timeout job. Kicked off by
/// POST /api/jobs/{id}/match.
/// </summary>
public class SendOfferJob
{
    private readonly IMatchingService _matching;
    private readonly ILogger<SendOfferJob> _logger;

    public SendOfferJob(IMatchingService matching, ILogger<SendOfferJob> logger)
    {
        _matching = matching;
        _logger   = logger;
    }

    /// <summary>
    /// Offers the job to its next top-ranked candidate. Retries are safe:
    /// <see cref="IMatchingService.SendNextOfferAsync"/> skips tradies who
    /// already hold an offer for the job and is a no-op once the job has
    /// left the Requested state.
    /// </summary>
    [AutomaticRetry(Attempts = 2)]
    public Task ExecuteAsync(int jobId, string actorUserId) =>
        _matching.SendNextOfferAsync(jobId, actorUserId);
}
