using FixoApi.Services;
using Xunit;

namespace FixoApi.Tests;

/// <summary>Plan 09 N1.7: staff alerts are idempotent per (event, entity) inside a window.</summary>
public class NotificationDeduplicatorTests
{
    private static readonly TimeSpan Hour = TimeSpan.FromHours(1);

    [Fact]
    public void First_call_acquires_and_repeat_inside_window_is_suppressed()
    {
        var time = new ManualTimeProvider();
        var dedup = new InMemoryNotificationDeduplicator(time);

        Assert.True(dedup.TryAcquire("payment_sla_breach:42", Hour));
        Assert.False(dedup.TryAcquire("payment_sla_breach:42", Hour));
        time.Advance(TimeSpan.FromMinutes(59));
        Assert.False(dedup.TryAcquire("payment_sla_breach:42", Hour));
    }

    [Fact]
    public void Acquires_again_once_the_window_has_passed()
    {
        var time = new ManualTimeProvider();
        var dedup = new InMemoryNotificationDeduplicator(time);

        Assert.True(dedup.TryAcquire("k", Hour));
        time.Advance(Hour + TimeSpan.FromSeconds(1));
        Assert.True(dedup.TryAcquire("k", Hour));
        Assert.False(dedup.TryAcquire("k", Hour));
    }

    [Fact]
    public void Different_keys_do_not_interfere()
    {
        var dedup = new InMemoryNotificationDeduplicator(new ManualTimeProvider());
        Assert.True(dedup.TryAcquire("payment_sla_breach:42", Hour));
        Assert.True(dedup.TryAcquire("payment_sla_breach:43", Hour));
        Assert.True(dedup.TryAcquire("job_needs_review:42", Hour));
    }

    [Fact]
    public void Zero_window_disables_dedup()
    {
        var dedup = new InMemoryNotificationDeduplicator(new ManualTimeProvider());
        Assert.True(dedup.TryAcquire("k", TimeSpan.Zero));
        Assert.True(dedup.TryAcquire("k", TimeSpan.Zero));
    }

    [Fact]
    public void Blank_key_is_rejected()
    {
        var dedup = new InMemoryNotificationDeduplicator(new ManualTimeProvider());
        Assert.ThrowsAny<ArgumentException>(() => dedup.TryAcquire(" ", Hour));
    }

    [Fact]
    public async Task Concurrent_callers_acquire_exactly_once()
    {
        var dedup = new InMemoryNotificationDeduplicator(new ManualTimeProvider());
        var results = await Task.WhenAll(Enumerable.Range(0, 64)
            .Select(_ => Task.Run(() => dedup.TryAcquire("race", Hour))));
        Assert.Equal(1, results.Count(r => r));
    }
}

/// <summary>Minimal controllable clock so the tests need no extra package.</summary>
internal sealed class ManualTimeProvider : TimeProvider
{
    private DateTimeOffset _now = new(2026, 11, 27, 0, 0, 0, TimeSpan.Zero);
    public override DateTimeOffset GetUtcNow() => _now;
    public void Advance(TimeSpan by) => _now += by;
}
