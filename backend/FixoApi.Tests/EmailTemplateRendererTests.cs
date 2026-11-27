using FixoApi.Email;
using Xunit;

namespace FixoApi.Tests;

/// <summary>
/// §6 Renderer tests: every template renders a non-empty (html, text) pair.
/// This doubles as the RazorLight-on-.NET-10 smoke test — if embedded resource
/// keys or the Razor compiler break, these fail first.
/// </summary>
public class EmailTemplateRendererTests
{
    private static readonly EmailTemplateRenderer _renderer = SharedEmailRenderer.Instance;

    [Fact]
    public void Embedded_templates_are_present()
    {
        var names = EmailTemplateRenderer.ListEmbeddedTemplates();
        Assert.Contains(names, n => n.Contains("Otp.cshtml"));
        Assert.Contains(names, n => n.Contains("_EmailLayout.cshtml"));
        Assert.Contains(names, n => n.Contains("_CtaButton.cshtml"));
    }

    [Theory]
    [MemberData(nameof(AllTemplates))]
    public async Task Every_template_renders_nonempty_html_and_text(string name)
    {
        var model = EmailPreviewSamples.All[name](EmailPreviewSamples.SampleBrand);
        var rendered = await _renderer.RenderAsync(name, model);

        Assert.False(string.IsNullOrWhiteSpace(rendered.Html), $"{name} html empty");
        Assert.False(string.IsNullOrWhiteSpace(rendered.Text), $"{name} text empty");

        // Shared chrome (§3.3): navy header band, white card, footer, preheader slot.
        Assert.Contains("lang=\"en-NZ\"", rendered.Html);

        // Regression: the layout must render the body as markup (RawString),
        // not as HTML-escaped text — this was a real RazorLight bug.
        Assert.DoesNotContain("&lt;h1", rendered.Html);
        Assert.DoesNotContain("&lt;p", rendered.Html);
        Assert.Contains("<h1", rendered.Html);
        Assert.Contains("#1E3A8A", rendered.Html);   // v2 brand header + headings
        Assert.Contains("#F4F6FB", rendered.Html);   // v2 paper page + footer
        Assert.Contains("TradieHunter", rendered.Html);

        // Plain-text twin (§3.4): no HTML tags, heading underlined with ====.
        Assert.DoesNotContain("<", rendered.Text);
        Assert.Contains(model.TextHeading.ToUpperInvariant(), rendered.Text);
        Assert.Contains("====", rendered.Text);
        Assert.Contains("support@tradiehunter.nz", rendered.Text);
    }

    [Fact]
    public async Task Otp_template_shows_code_and_expiry()
    {
        var rendered = await _renderer.RenderAsync("Otp", EmailPreviewSamples.All["Otp"](EmailPreviewSamples.SampleBrand));
        Assert.Contains("482913", rendered.Html);
        Assert.Contains("482913", rendered.Text);
        Assert.Contains("10 minutes", rendered.Html);
        Assert.Contains("10 minutes", rendered.Text);
        // No CTA button on OTP — the code IS the CTA (§4.1).
        Assert.DoesNotContain("v:roundrect", rendered.Html);
    }

    [Fact]
    public async Task Cta_button_omitted_when_no_frontend_url()
    {
        // Sample brand has FrontendBaseUrl = "" (§9 Q1: no web app yet — CTA omitted).
        var noCta = new FixoApi.Email.JobClosedModel
        {
            JobTitle = "Deck staining",
            Reason = "No tradie response within 24h — auto-expired.",
            PostAgainUrl = null,
            Brand = new FixoApi.Options.BrandOptions(),
        };
        var rendered = await _renderer.RenderAsync("JobCancelled", noCta);
        Assert.DoesNotContain("v:roundrect", rendered.Html);
        Assert.DoesNotContain("Post a job again", rendered.Html);
        // But the text twin still stands alone.
        Assert.Contains("post it again any time", rendered.Text);
    }

    [Fact]
    public async Task StaffAlert_renders_summary_rows_and_admin_cta_with_frontend()
    {
        var model = EmailPreviewSamples.All["StaffAlert"](EmailPreviewSamples.WithFrontend);
        var rendered = await _renderer.RenderAsync("StaffAlert", model);

        Assert.Contains("Receipt awaiting verification", rendered.Html);
        Assert.Contains("Fence repair (#1042)", rendered.Html);
        Assert.Contains("456.00 NZD", rendered.Html);
        Assert.Contains("v:roundrect", rendered.Html);
        Assert.Contains("Open in admin", rendered.Html);
        Assert.Contains("https://app.tradiehunter.nz/payments", rendered.Html);

        Assert.Contains("https://app.tradiehunter.nz/payments", rendered.Text);
        Assert.Contains("Waiting", rendered.Text);
    }

    [Fact]
    public async Task StaffAlert_omits_the_cta_when_no_frontend_url()
    {
        var model = EmailPreviewSamples.All["StaffAlert"](EmailPreviewSamples.SampleBrand);
        var rendered = await _renderer.RenderAsync("StaffAlert", model);

        Assert.DoesNotContain("v:roundrect", rendered.Html);
        Assert.DoesNotContain("Open in admin", rendered.Html);
        Assert.Contains("waiting for staff", rendered.Text);
    }

    [Fact]
    public void StaffAlert_preheader_defaults_to_a_trimmed_body()
    {
        var longBody = new string('a', 300);
        var model = new StaffAlertModel
        {
            Heading = "Heading",
            Body = longBody,
            Brand = EmailPreviewSamples.SampleBrand,
        };

        Assert.True(model.TextPreheader!.Length <= 110);
        Assert.EndsWith("…", model.TextPreheader);
    }

    public static IEnumerable<object[]> AllTemplates() =>
        EmailPreviewSamples.All.Keys.Select(k => new object[] { k });

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
