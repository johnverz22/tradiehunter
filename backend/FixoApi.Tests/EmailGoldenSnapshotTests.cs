using FixoApi.Email;
using Xunit;

namespace FixoApi.Tests;

/// <summary>
/// §6 golden snapshots: each template's HTML render (sample data, CTA variant)
/// is committed under Goldens/email/ — any layout change diffs in the PR and
/// forces review. Set UPDATE_EMAIL_GOLDENS=1 to regenerate, review the diff,
/// and commit.
/// </summary>
public class EmailGoldenSnapshotTests
{
    private static readonly EmailTemplateRenderer _renderer = SharedEmailRenderer.Instance;

    [Theory]
    [MemberData(nameof(AllTemplates))]
    public async Task Golden_html_matches_committed_snapshot(string name)
    {
        var rendered = await _renderer.RenderAsync(name, ModelFor(name));

        var goldenPath = GoldenPath($"{name}.html");
        if (!File.Exists(goldenPath) || UpdateRequested)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(goldenPath)!);
            await File.WriteAllTextAsync(goldenPath, rendered.Html);
            await File.WriteAllTextAsync(GoldenPath($"{name}.txt"), rendered.Text);
        }

        Assert.True(File.Exists(goldenPath), $"Golden missing for {name}");
        Assert.Equal(await File.ReadAllTextAsync(goldenPath), rendered.Html);
    }

    [Theory]
    [MemberData(nameof(AllTemplates))]
    public async Task Golden_text_matches_committed_snapshot(string name)
    {
        var rendered = await _renderer.RenderAsync(name, ModelFor(name));

        var goldenPath = GoldenPath($"{name}.txt");
        if (!File.Exists(goldenPath) || UpdateRequested)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(goldenPath)!);
            await File.WriteAllTextAsync(goldenPath, rendered.Text);
        }

        Assert.True(File.Exists(goldenPath), $"Golden missing for {name}");
        Assert.Equal(await File.ReadAllTextAsync(goldenPath), rendered.Text);
    }

    private static IEmailTextModel ModelFor(string name) =>
        EmailPreviewSamples.All[name](EmailPreviewSamples.WithFrontend);

    private static bool UpdateRequested =>
        Environment.GetEnvironmentVariable("UPDATE_EMAIL_GOLDENS") == "1";

    private static string GoldenPath(string fileName)
    {
        // Goldens live in the test project source tree and are copied next to
        // the binaries; write/read through the source-tree path when writable
        // (regeneration) so commits pick them up.
        var sourceTree = FindRepoRoot();
        if (sourceTree is not null)
        {
            return Path.Combine(sourceTree, "FixoApi.Tests", "Goldens", "email", fileName);
        }
        return Path.Combine(AppContext.BaseDirectory, "Goldens", "email", fileName);
    }

    private static string? FindRepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        for (int i = 0; i < 8 && dir is not null; i++, dir = dir.Parent!)
        {
            var candidate = Path.Combine(dir.FullName, "FixoApi.Tests");
            if (Directory.Exists(candidate) && File.Exists(Path.Combine(candidate, "FixoApi.Tests.csproj")))
            {
                return dir.FullName;
            }
        }
        return null;
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
