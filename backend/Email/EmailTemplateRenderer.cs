using System.Reflection;
using FixoApi.Options;
using Microsoft.CodeAnalysis;
using Microsoft.Extensions.DependencyModel;
using RazorLight;

namespace FixoApi.Email;

/// <summary>HTML + plain-text twin produced from one model (multipart/alternative, §3.4).</summary>
public sealed record RenderedEmail(string Html, string Text);

/// <summary>
/// Renders email templates with RazorLight (embedded .cshtml resources — work
/// in containers and published output with no on-disk content copies) and
/// derives the plain-text twin from the same model via <see cref="PlainTextComposer"/>.
/// Composition strategy: the template renders the card body, then the renderer
/// wraps it in <c>Layouts/_EmailLayout</c> — one layout, four partials, §3.3.
/// Template rendering is a new failure mode, so callers log render time and
/// never let a render failure break a business transition.
/// </summary>
public sealed class EmailTemplateRenderer
{
    private readonly RazorLightEngine _engine;

    public EmailTemplateRenderer()
    {
        _engine = BuildEngine();
    }

    /// <summary>
    /// Render a template from <c>backend/Email/Templates/{name}.cshtml</c> plus
    /// its plain-text twin. Names are stable template keys — "Otp", "StaffInvite", …
    /// </summary>
    public async Task<RenderedEmail> RenderAsync<TModel>(string templateName, TModel model)
        where TModel : IEmailTextModel
    {
        var bodyHtml = await _engine.CompileRenderAsync($"{TemplatesRoot}.{templateName}", model);
        var layoutModel = new EmailLayoutModel
        {
            BodyHtml = bodyHtml.Trim(),
            Preheader = model.TextPreheader,
            FooterNote = model.TextFooterNote,
            Brand = model.Brand,
        };
        var html = await _engine.CompileRenderAsync(LayoutKey, layoutModel);
        var text = PlainTextComposer.Compose(model, model.Brand);
        return new RenderedEmail(html.Trim(), text);
    }

    /// <summary>Diagnostic: embedded template resource names as RazorLight resolves them.</summary>
    public static IReadOnlyList<string> ListEmbeddedTemplates() =>
        typeof(EmailTemplateRenderer).Assembly
            .GetManifestResourceNames()
            .Where(n => n.EndsWith(".cshtml", StringComparison.Ordinal))
            .OrderBy(n => n, StringComparer.Ordinal)
            .ToList();

    private static RazorLightEngine BuildEngine()
    {
        var apiAssembly = typeof(EmailTemplateRenderer).Assembly;
        var builder = new RazorLightEngineBuilder()
            // Root namespace must be explicit: the (Assembly)-only overload does
            // not prefix it, and embedded manifest names are FixoApi.Email.*.cshtml.
            .UseEmbeddedResourcesProject(apiAssembly, "FixoApi")
            // Metadata references resolve from THIS assembly's compilation
            // context (FixoApi.csproj sets PreserveCompilationContext) — not the
            // entry assembly, which breaks under a test host.
            .SetOperatingAssembly(apiAssembly)
            .UseMemoryCachingProvider();

        var seenPaths = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var additionalReferences = new List<MetadataReference>();
        void AddReference(Assembly? assembly)
        {
            if (assembly == null || assembly.IsDynamic || string.IsNullOrWhiteSpace(assembly.Location)) return;
            if (!seenPaths.Add(assembly.Location)) return;
            additionalReferences.Add(MetadataReference.CreateFromFile(assembly.Location));
        }

        // Shared-framework and platform compile libraries ship without reference
        // assemblies, so RazorLight's resolver can't find their ref/ paths in a
        // test host. Exclude everything it cannot resolve, then hand the
        // compiler explicit metadata references from runtime binaries instead —
        // Assembly.Load resolves them through the host's normal binding.
        var unresolvable = new List<string>();
        var dependencyContext = DependencyContext.Load(apiAssembly);
        if (dependencyContext != null)
        {
            foreach (var library in dependencyContext.CompileLibraries)
            {
                try
                {
                    // Empty (no ref pack resolvable) counts too — platform
                    // libraries return nothing rather than throwing.
                    if (!library.ResolveReferencePaths().Any())
                    {
                        unresolvable.Add(library.Name);
                    }
                }
                catch (InvalidOperationException)
                {
                    unresolvable.Add(library.Name);
                }
            }
        }

        if (unresolvable.Count > 0)
        {
            builder.ExcludeAssemblies(unresolvable.ToArray());

            foreach (var library in dependencyContext!.CompileLibraries)
            {
                if (!unresolvable.Contains(library.Name)) continue;
                try { AddReference(Assembly.Load(library.Name)); } catch { /* not an assembly name (platform lib) */ }
                foreach (var assemblyName in library.Assemblies)
                {
                    try { AddReference(Assembly.Load(Path.GetFileNameWithoutExtension(assemblyName))); }
                    catch { /* not available at runtime — templates never use it */ }
                }
            }
        }

        // Everything already loaded in the process (covers platform assemblies
        // whose compile library has no member list)…
        foreach (var assembly in AppDomain.CurrentDomain.GetAssemblies())
        {
            AddReference(assembly);
        }

        // …and the core plumbing Razor-generated code references: BCL basics
        // plus the encoders RazorLight's TemplatePage uses for @Model output.
        foreach (var name in new[]
        {
            "System.Runtime", "System.Runtime.Extensions", "System.Collections",
            "System.Linq", "System.Linq.Expressions", "System.Threading.Tasks",
            "System.Text.Encodings.Web", "System.Net.Primitives", "System.IO",
            "System.Text.RegularExpressions",
        })
        {
            try { AddReference(Assembly.Load(name)); } catch { }
        }

        // NOTE: AddMetadataReferences REPLACES the set on every call — one call only.
        if (additionalReferences.Count > 0)
        {
            builder.AddMetadataReferences(additionalReferences.ToArray());
        }

        return builder.Build();
    }

    // Embedded-resource keys (dotted, extension-less — RazorLight project convention).
    private const string TemplatesRoot = "Email.Templates";
    private const string LayoutKey = "Email.Layouts._EmailLayout";
}
