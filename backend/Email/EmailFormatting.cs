using System.Globalization;
using System.Text;
using FixoApi.Options;

namespace FixoApi.Email;

/// <summary>
/// NZ-timezone formatting for deadlines shown to users (§4.2 E4). The old
/// <c>ToLocalTime()</c> calls rendered the *server* timezone — a latent bug for
/// NZ users whenever the API is hosted offshore. Everything here is explicit
/// Pacific/Auckland and invariant-culture so output is stable regardless of
/// server locale.
/// </summary>
public static class NzTime
{
    private static readonly TimeZoneInfo Zone = ResolveZone();

    private static TimeZoneInfo ResolveZone()
    {
        // IANA id everywhere except Windows; fall back to the Windows id, then UTC.
        try
        {
            return TimeZoneInfo.FindSystemTimeZoneById("Pacific/Auckland");
        }
        catch (TimeZoneNotFoundException)
        {
            try
            {
                return TimeZoneInfo.FindSystemTimeZoneById("New Zealand Standard Time");
            }
            catch (TimeZoneNotFoundException)
            {
                return TimeZoneInfo.Utc;
            }
        }
        catch (InvalidOperationException)
        {
            return TimeZoneInfo.Utc;
        }
    }

    /// <summary>Convert a UTC value to NZ local time (input may be Unspecified — treated as UTC).</summary>
    public static DateTime ToNz(DateTime utc) =>
        TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(utc, DateTimeKind.Utc), Zone);

    /// <summary>"d MMM yyyy, h:mm tt" NZT — e.g. "25 Nov 2026, 5:00pm".</summary>
    public static string Format(DateTime utc) => Format(utc, "d MMM yyyy, h:mm tt");

    /// <summary>Arbitrary invariant pattern, lowercase am/pm, NZT.</summary>
    public static string Format(DateTime utc, string pattern)
    {
        var s = ToNz(utc).ToString(pattern, CultureInfo.InvariantCulture);
        return LowercaseAmPm(s);
    }

    /// <summary>Short form for push bodies / hero lines — e.g. "Tue 25 Nov, 5:00pm".</summary>
    public static string Short(DateTime utc) => Format(utc, "ddd d MMM, h:mm tt");

    private static string LowercaseAmPm(string s) =>
        s.Replace(" AM", "am", StringComparison.Ordinal)
         .Replace(" PM", "pm", StringComparison.Ordinal);
}

/// <summary>
/// Invariant money formatting (§2.3 #10): <c>{amount:0.00}</c> was
/// culture-sensitive (1,234.56 vs 1 234,56 depending on server locale).
/// All email amounts render as <c>1234.56 NZD</c> — invariant, explicit currency.
/// </summary>
public static class Money
{
    public static string Format(decimal amount, string currency) =>
        $"{amount.ToString("0.00", CultureInfo.InvariantCulture)} {currency}";
}

/// <summary>
/// Splits a brand name so its final segment can carry the hero-gold accent in
/// the email header wordmark — mirrors web/src/features/branding/splitBrandName.ts
/// ("TradieHunter" → "Tradie" + "Hunter"). The boundary is the last uppercase
/// letter preceded by a lowercase letter or digit; names without one render
/// with no accent segment.
/// </summary>
public static class BrandWordmark
{
    public static (string Lead, string Accent) Split(string name)
    {
        var last = -1;
        for (var i = 1; i < name.Length; i++)
        {
            if (char.IsUpper(name[i]) && (char.IsLower(name[i - 1]) || char.IsDigit(name[i - 1])))
            {
                last = i;
            }
        }

        return last <= 0 ? (name, string.Empty) : (name[..last], name[last..]);
    }
}

/// <summary>
/// Builds the plain-text twin of every email (§3.4): 72-column wrap, "===="
/// under headings, summary rows as aligned label/value lines, and CTA URLs on
/// their own line (full URLs only — no shortened links, deliverability).
/// HTML and text render from the same model, so they never disagree.
/// </summary>
public static class PlainTextComposer
{
    private const int WrapWidth = 72;

    public static string Compose(IEmailTextModel model, BrandOptions brand)
    {
        var sb = new StringBuilder();

        // H1 + ==== underline.
        sb.AppendLine(model.TextHeading.ToUpperInvariant());
        sb.AppendLine(new string('=', Math.Min(model.TextHeading.Length, WrapWidth)));
        sb.AppendLine();

        // Hero line (OTP code / amount / deadline).
        if (!string.IsNullOrWhiteSpace(model.TextHeroLine))
        {
            sb.AppendLine($"    {model.TextHeroLine}");
            sb.AppendLine();
        }

        foreach (var line in model.TextBodyLines)
        {
            AppendWrapped(sb, line);
            sb.AppendLine();
        }

        // Summary rows: label left, value right, aligned.
        if (model.TextSummaryRows.Count > 0)
        {
            var labelWidth = Math.Max(4, model.TextSummaryRows.Max(r => r.Label.Length)) + 1;
            foreach (var row in model.TextSummaryRows)
            {
                sb.AppendLine($"  {row.Label.PadRight(labelWidth)}{row.Value}");
            }
            sb.AppendLine();
        }

        // CTA — URL on its own line, nothing shortened.
        if (!string.IsNullOrWhiteSpace(model.TextCtaLabel) && !string.IsNullOrWhiteSpace(model.TextCtaUrl))
        {
            sb.AppendLine($"{model.TextCtaLabel}:");
            sb.AppendLine(model.TextCtaUrl);
            sb.AppendLine();
        }
        else if (!string.IsNullOrWhiteSpace(model.TextCtaUrl))
        {
            // URL without label — still on its own line.
            sb.AppendLine(model.TextCtaUrl);
            sb.AppendLine();
        }

        // Footer.
        sb.AppendLine(new string('-', 72));
        AppendWrapped(sb, model.TextFooterNote ?? "You received this because you have a TradieHunter account.");
        sb.AppendLine();

        var appName = string.IsNullOrWhiteSpace(brand.AppName) ? "TradieHunter" : brand.AppName;
        var support = string.IsNullOrWhiteSpace(brand.SupportEmail) ? "support@tradiehunter.nz" : brand.SupportEmail;
        var hours = string.IsNullOrWhiteSpace(brand.SupportHoursDisplay) ? "8am - 6pm NZT, Mon-Fri" : brand.SupportHoursDisplay;
        var address = string.IsNullOrWhiteSpace(brand.PostalAddress) ? "Auckland, New Zealand" : brand.PostalAddress;

        AppendWrapped(sb, $"{appName} · {support} · {hours}");
        sb.AppendLine(address);

        return sb.ToString().TrimEnd() + Environment.NewLine;
    }

    private static void AppendWrapped(StringBuilder sb, string text)
    {
        foreach (var word in text.Split(' ', StringSplitOptions.RemoveEmptyEntries))
        {
            var currentLineLength = GetLastLineLength(sb);
            if (currentLineLength == 0)
            {
                sb.Append(word);
            }
            else if (currentLineLength + 1 + word.Length <= WrapWidth)
            {
                sb.Append(' ').Append(word);
            }
            else
            {
                sb.AppendLine();
                sb.Append(word);
            }
        }
        sb.AppendLine();
    }

    private static int GetLastLineLength(StringBuilder sb)
    {
        for (var i = sb.Length - 1; i >= 0; i--)
        {
            if (sb[i] == '\n') return sb.Length - 1 - i;
        }
        return sb.Length;
    }
}
