using System.Reflection;

namespace FixoApi.Email;

/// <summary>
/// Embedded binary assets for email templates (e.g. inline CID logo PNG).
/// </summary>
public static class EmailAssets
{
    private const string MarkResourceName = "FixoApi.Email.Assets.th-mark.png";

    private static readonly Lazy<byte[]> LazyMark = new(() =>
    {
        var assembly = typeof(EmailAssets).Assembly;
        using var stream = assembly.GetManifestResourceStream(MarkResourceName)
            ?? throw new InvalidOperationException(
                $"Embedded email asset '{MarkResourceName}' not found.");
        using var ms = new MemoryStream();
        stream.CopyTo(ms);
        return ms.ToArray();
    });

    /// <summary>96x96 white TradieHunter emblem PNG for the navy email header.</summary>
    public static byte[] Mark => LazyMark.Value;
}
