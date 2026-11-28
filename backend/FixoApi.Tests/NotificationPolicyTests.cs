using System.Text.RegularExpressions;
using FixoApi.Services;
using Xunit;

namespace FixoApi.Tests;

/// <summary>Plan 09 N1.3: the notification matrix is the contract — these tests pin its invariants.</summary>
public class NotificationPolicyTests
{
    [Fact]
    public void Keys_are_unique_snake_case()
    {
        var keys = NotificationPolicy.All.Select(d => d.Key).ToList();
        Assert.Equal(keys.Count, keys.Distinct(StringComparer.Ordinal).Count());
        foreach (var key in keys)
        {
            Assert.Matches(new Regex("^[a-z]+(_[a-z]+)*$"), key);
        }
    }

    [Fact]
    public void Every_event_constant_has_a_policy_row()
    {
        var constants = typeof(NotificationEvents)
            .GetFields()
            .Where(f => f.IsLiteral && f.FieldType == typeof(string))
            .Select(f => (string)f.GetRawConstantValue()!)
            .ToList();

        Assert.NotEmpty(constants);
        foreach (var key in constants)
        {
            Assert.True(NotificationPolicy.TryGet(key, out _), $"No policy row for '{key}'.");
        }
        // And no orphan rows: every row is reachable through a named constant.
        Assert.Equal(constants.Count, NotificationPolicy.All.Count);
    }

    [Fact]
    public void Every_event_has_an_audience_and_a_summary()
    {
        foreach (var def in NotificationPolicy.All)
        {
            Assert.NotEqual(NotificationAudience.None, def.Audiences);
            Assert.False(string.IsNullOrWhiteSpace(def.Summary), $"{def.Key} has no summary");
        }
    }

    [Fact]
    public void Existing_critical_kinds_stay_critical()
    {
        foreach (var key in new[]
        {
            CriticalNotificationTypes.RefundProcessed,
            CriticalNotificationTypes.AccountSuspended,
            CriticalNotificationTypes.JobCancelled,
            CriticalNotificationTypes.JobExpired,
        })
        {
            Assert.True(NotificationPolicy.Get(key).IsCritical, $"{key} must always email");
        }
    }

    [Fact]
    public void Staff_alerts_email_always_and_never_push()
    {
        // Staff work in the web admin; until the in-app bell (N6) lands, email is the only channel.
        var staff = NotificationPolicy.All.Where(d => d.IsStaffAlert).ToList();
        Assert.NotEmpty(staff);
        foreach (var def in staff)
        {
            Assert.Equal(NotificationAudience.Staff, def.Audiences);
            Assert.Equal(EmailPolicy.Always, def.Email);
            Assert.False(def.Push, $"{def.Key} must not push to staff");
        }
    }

    [Fact]
    public void Email_only_events_are_critical()
    {
        // No push + email policy "fallback" would mean "email only when push fails" for an
        // event that never pushes: a contradiction. Email-only events must be Always.
        foreach (var def in NotificationPolicy.All.Where(d => !d.Push))
        {
            Assert.Equal(EmailPolicy.Always, def.Email);
        }
    }

    [Fact]
    public void Push_only_events_are_the_time_sensitive_ones()
    {
        var pushOnly = NotificationPolicy.All
            .Where(d => d.Push && d.Email == EmailPolicy.None)
            .Select(d => d.Key)
            .OrderBy(k => k, StringComparer.Ordinal)
            .ToList();

        Assert.Equal(
            new[]
            {
                NotificationEvents.AdjustmentReminder,
                NotificationEvents.OfferSuperseded,
                NotificationEvents.OfferWithdrawn,
                NotificationEvents.PreJobReminder,
                NotificationEvents.ReviewReceived,
                NotificationEvents.ReviewRevealed,
            }.OrderBy(k => k, StringComparer.Ordinal).ToList(),
            pushOnly);
    }

    [Fact]
    public void Money_and_decision_events_are_critical()
    {
        foreach (var key in new[]
        {
            NotificationEvents.PayoutProcessed,
            NotificationEvents.DisputeOpened,
            NotificationEvents.DisputeResolved,
            NotificationEvents.CredentialDecision,
        })
        {
            Assert.True(NotificationPolicy.Get(key).IsCritical, $"{key} must always email");
        }
    }

    [Fact]
    public void Unknown_event_throws_from_Get_but_not_TryGet()
    {
        Assert.Throws<KeyNotFoundException>(() => NotificationPolicy.Get("not_an_event"));
        Assert.False(NotificationPolicy.TryGet("not_an_event", out _));
    }
}
