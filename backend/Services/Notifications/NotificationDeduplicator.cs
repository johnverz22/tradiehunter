using System.Collections.Concurrent;

namespace FixoApi.Services;

/// <summary>
/// Guards staff alerts against duplicates (plan 09 §3.5): a Hangfire retry or a
/// repeating SLA job must not email the team twice for the same entity.
/// </summary>
public interface INotificationDeduplicator
{
    /// <summary>
    /// Returns true the first time <paramref name="key"/> is seen inside
    /// <paramref name="window"/> (and records it); false for repeats.
    /// </summary>
    bool TryAcquire(string key, TimeSpan window);
}

/// <summary>
/// Per-process implementation. Good enough for single-instance and for retry
/// bursts; the durable cross-instance guard arrives with the persisted staff
/// notification table (N6). Thread-safe, bounded by opportunistic purging.
/// </summary>
public sealed class InMemoryNotificationDeduplicator : INotificationDeduplicator
{
    private const int PurgeThreshold = 1024;

    private readonly ConcurrentDictionary<string, DateTimeOffset> _seen = new(StringComparer.Ordinal);
    private readonly TimeProvider _time;

    public InMemoryNotificationDeduplicator(TimeProvider? time = null)
    {
        _time = time ?? TimeProvider.System;
    }

    public bool TryAcquire(string key, TimeSpan window)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(key);
        if (window <= TimeSpan.Zero) return true; // no window = no dedup

        var now = _time.GetUtcNow();
        var expires = now + window;

        if (_seen.Count > PurgeThreshold) Purge(now);

        while (true)
        {
            if (_seen.TryAdd(key, expires)) return true;
            if (!_seen.TryGetValue(key, out var existing)) continue; // removed meanwhile, retry add
            if (existing > now) return false;                        // still inside the window
            if (_seen.TryUpdate(key, expires, existing)) return true; // expired, we took it
        }
    }

    private void Purge(DateTimeOffset now)
    {
        foreach (var pair in _seen)
        {
            if (pair.Value <= now) _seen.TryRemove(pair);
        }
    }
}
