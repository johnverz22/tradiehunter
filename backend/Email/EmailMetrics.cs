using System.Collections.Concurrent;

namespace FixoApi.Email;

/// <summary>
/// Per-template send/render counters + render duration histogram (§5.5 —
/// observability). No prometheus-net dependency in v1: the counters are plain
/// in-memory longs exposed via structured logs and the weekly bounce report;
/// wiring a /metrics endpoint is an infra decision (see docs/email-ops.md §Metrics).
/// </summary>
public interface IEmailMetrics
{
    void IncrementSent(string template);
    void IncrementFailed(string template);
    void RecordRender(string template, long elapsedMs);
    EmailMetricsSnapshot Snapshot();
}

public sealed record EmailMetricTemplate(long Sent, long Failed, long RenderMsTotal, long RenderMsCount)
{
    public double AvgRenderMs => RenderMsCount == 0 ? 0 : (double)RenderMsTotal / RenderMsCount;
}

public sealed record EmailMetricsSnapshot(IReadOnlyDictionary<string, EmailMetricTemplate> Templates);

public sealed class EmailMetrics : IEmailMetrics
{
    private sealed class Counters
    {
        public long Sent;
        public long Failed;
        public long RenderMsTotal;
        public long RenderMsCount;
    }

    private readonly ConcurrentDictionary<string, Counters> _counters = new(StringComparer.Ordinal);

    private Counters For(string template) =>
        _counters.GetOrAdd(template ?? "unknown", _ => new Counters());

    public void IncrementSent(string template) => Interlocked.Increment(ref For(template).Sent);

    public void IncrementFailed(string template) => Interlocked.Increment(ref For(template).Failed);

    public void RecordRender(string template, long elapsedMs)
    {
        var c = For(template);
        Interlocked.Add(ref c.RenderMsTotal, Math.Max(0, elapsedMs));
        Interlocked.Increment(ref c.RenderMsCount);
    }

    public EmailMetricsSnapshot Snapshot()
    {
        var templates = new Dictionary<string, EmailMetricTemplate>(StringComparer.Ordinal);
        foreach (var (name, c) in _counters)
        {
            templates[name] = new EmailMetricTemplate(
                Interlocked.Read(ref c.Sent),
                Interlocked.Read(ref c.Failed),
                Interlocked.Read(ref c.RenderMsTotal),
                Interlocked.Read(ref c.RenderMsCount));
        }
        return new EmailMetricsSnapshot(templates);
    }
}
