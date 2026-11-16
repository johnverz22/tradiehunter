using FixoApi.Email;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FixoApi.Controllers;

/// <summary>
/// §5.7 preview: renders any email template with sample data so designers and
/// staff review renders without touching SMTP. Staff-auth-gated (same policy
/// as the admin dashboard).
///   GET api/admin/email-preview                     → template index
///   GET api/admin/email-preview/{template}          → HTML render (no CTA)
///   GET api/admin/email-preview/{template}?frontend=true → CTA variant
///   GET api/admin/email-preview/{template}?text=true     → plain-text twin
/// </summary>
[Route("api/admin/email-preview")]
[Authorize(Policy = "RequireStaffRole")]
public class EmailPreviewController : ControllerBase
{
    private readonly EmailTemplateRenderer _renderer;

    public EmailPreviewController(EmailTemplateRenderer renderer)
    {
        _renderer = renderer;
    }

    [HttpGet("{template}")]
    public async Task<IActionResult> Preview(string template, bool frontend = false, bool text = false)
    {
        if (!EmailPreviewSamples.All.TryGetValue(template, out var factory))
        {
            return NotFound(new
            {
                error = $"Unknown template '{template}'.",
                available = EmailPreviewSamples.All.Keys.OrderBy(k => k, StringComparer.Ordinal),
            });
        }

        // Sample brand has no FrontendBaseUrl (CTAs omitted, §9 Q1);
        // frontend=true renders the CTA variant for review.
        var model = factory(frontend ? EmailPreviewSamples.WithFrontend : EmailPreviewSamples.SampleBrand);
        var rendered = await _renderer.RenderAsync(template, model);

        if (text)
        {
            return Content(rendered.Text, "text/plain; charset=utf-8");
        }

        return Content(rendered.Html, "text/html; charset=utf-8");
    }

    /// <summary>List the available preview templates.</summary>
    [HttpGet]
    public IActionResult Index() => Ok(new
    {
        templates = EmailPreviewSamples.All.Keys.OrderBy(k => k, StringComparer.Ordinal),
        usage = "GET api/admin/email-preview/{template}?frontend=true&text=true",
    });
}
