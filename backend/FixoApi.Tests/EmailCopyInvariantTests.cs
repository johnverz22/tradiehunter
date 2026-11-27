using System.Text.RegularExpressions;
using FixoApi.Email;
using Xunit;

namespace FixoApi.Tests;

/// <summary>
/// §6 copy invariants: invariant currency, NZT deadline format, subject copy,
/// plain-text discipline (no HTML, absolute URLs), preheader presence.
/// </summary>
public class EmailCopyInvariantTests
{
    private static readonly EmailTemplateRenderer _renderer = SharedEmailRenderer.Instance;

    private static IEmailTextModel ModelFor(string name) =>
        EmailPreviewSamples.All[name](EmailPreviewSamples.SampleBrand);

    private static IEmailTextModel ModelForFrontend(string name) =>
        EmailPreviewSamples.All[name](EmailPreviewSamples.WithFrontend);

    [Fact]
    public void Subjects_match_the_revision_plan()
    {
        Assert.Equal("Your TradieHunter verification code", EmailSubjects.Otp);
        Assert.Equal("You've been invited to the TradieHunter admin panel", EmailSubjects.StaffInvite);
        Assert.Equal("Payment confirmed — Fence repair", EmailSubjects.PaymentVerified("Fence repair"));
        Assert.Equal("Action needed — receipt for Leaking tap", EmailSubjects.PaymentRejected("Leaking tap"));
        Assert.Equal("Your refund is on its way", EmailSubjects.RefundProcessed);
        Assert.Equal("Your TradieHunter account has been suspended", EmailSubjects.AccountSuspended);
        Assert.Equal("Your job \"Deck staining\" has been closed", EmailSubjects.JobCancelled("Deck staining"));
        Assert.Equal("Staff alert — Receipt awaiting verification", EmailSubjects.StaffAlert("Receipt awaiting verification"));
    }

    [Fact]
    public void Amounts_are_culture_invariant_with_explicit_currency()
    {
        // §2.3 #10: {amount:0.00} rendered 1,234.56 vs 1 234,56 by server locale.
        Assert.Equal("1234.56 NZD", Money.Format(1234.56m, "NZD"));
        Assert.Equal("456.00 NZD", Money.Format(456.00m, "NZD"));
        Assert.Equal("0.00 NZD", Money.Format(0m, "NZD"));

        var sample = ModelFor("PaymentVerified");
        Assert.Contains("456.00 NZD", sample.TextSummaryRows.Single(r => r.Label == "Amount").Value);
    }

    [Fact]
    public void Deadlines_render_in_nz_time_lowercase_ampm()
    {
        // §4.2 E4: "d MMM yyyy, h:mm a NZT" — 2026-11-25 04:00 UTC is 5pm NZDT.
        var formatted = NzTime.Format(new DateTime(2026, 11, 25, 4, 0, 0, DateTimeKind.Utc));
        Assert.Matches(@"\d{1,2} Nov 2026, \d{1,2}:00pm", formatted);

        var shortForm = NzTime.Short(new DateTime(2026, 11, 25, 4, 0, 0, DateTimeKind.Utc));
        Assert.Matches(@"[A-Z][a-z]{2} \d{1,2} Nov, \d{1,2}:00pm", shortForm);

        var sample = ModelFor("PaymentRejected");
        Assert.Contains("New deadline:", sample.TextHeroLine);
    }

    [Fact]
    public async Task Plain_text_twin_has_no_html_and_absolute_links()
    {
        foreach (var name in EmailPreviewSamples.All.Keys)
        {
            var rendered = await _renderer.RenderAsync(name, ModelFor(name));
            Assert.DoesNotContain('<', rendered.Text);

            // CTA URLs, when present, are full absolute URLs on their own line.
            if (!string.IsNullOrWhiteSpace(ModelFor(name).TextCtaUrl))
            {
                var url = ModelFor(name).TextCtaUrl!;
                Assert.True(
                    url.StartsWith("http://", StringComparison.OrdinalIgnoreCase) ||
                    url.StartsWith("https://", StringComparison.OrdinalIgnoreCase) ||
                    url.StartsWith("mailto:", StringComparison.OrdinalIgnoreCase),
                    $"{name} CTA is not absolute: {url}");
                Assert.Contains(url, rendered.Text);
            }
        }
    }

    [Fact]
    public async Task Every_template_has_a_preheader()
    {
        // §2.3 #7: no preheader existed at all; now each template supplies one
        // (80–95 chars target, hard ceiling 110 so the preview stays one line).
        foreach (var name in EmailPreviewSamples.All.Keys)
        {
            var preheader = ModelFor(name).TextPreheader;
            Assert.False(string.IsNullOrWhiteSpace(preheader), $"{name} missing preheader");
            Assert.True(preheader!.Length <= 110, $"{name} preheader too long ({preheader.Length}): {preheader}");
        }
    }

    [Fact]
    public void No_marketing_fillers_or_exclamations_in_email_copy()
    {
        foreach (var name in EmailPreviewSamples.All.Keys)
        {
            var model = ModelFor(name);
            var copy = string.Join(' ',
                new[] { model.TextHeading, model.TextPreheader, model.TextHeroLine }
                    .Concat(model.TextBodyLines)
                    .Concat(model.TextSummaryRows.Select(r => r.Value))
                    .Where(s => s != null));

            Assert.DoesNotContain('!', copy);
            Assert.DoesNotContain("we're here to help", copy, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("don't worry", copy, StringComparison.OrdinalIgnoreCase);
        }
    }

/// <summary>
/// One shared renderer for the whole test assembly: RazorLight engine +
/// Roslyn compile cache are memory-heavy (~400 metadata references), and a
/// single instance compiles each template once. Separate instances OOM-killed
/// the test host on constrained CI boxes.
/// </summary>
public static class SharedEmailRenderer
{
    public static readonly EmailTemplateRenderer Instance = new();
}
}
