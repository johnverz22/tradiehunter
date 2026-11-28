using FixoApi.Data;
using FixoApi.Models;
using FixoApi.Options;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using System.Globalization;

namespace FixoApi.Services;

/// <summary>Plan 10 (Q7): the two quote time windows, in hours.</summary>
/// <param name="BoardWindowHours">How long a posted open project accepts new quotes.</param>
/// <param name="ValidityHours">How long a submitted quote stays valid.</param>
public readonly record struct QuoteWindowSettings(int BoardWindowHours, int ValidityHours);

public static class PlatformSettingKeys
{
    public const string QuotesBoardWindowHours = "Quotes.BoardWindowHours";
    public const string QuotesValidityHours = "Quotes.ValidityHours";
    public const string PresenceGraceMinutes = "Presence.GraceMinutes";

    public const int MinHours = 1;
    public const int MaxHours = 720; // 30 days
    public const int DefaultPresenceGraceMinutes = 3;
    public const int MinPresenceGraceMinutes = 1;
    public const int MaxPresenceGraceMinutes = 60;
}

/// <summary>
/// DB-backed, admin-editable platform settings (plan 10 Q7.1). Reads fall back
/// to <see cref="JobFlowOptions"/> when no row exists or the stored value is
/// unusable, so a bad row can never break quoting.
/// </summary>
public interface IPlatformSettings
{
    Task<QuoteWindowSettings> GetQuoteWindowsAsync(CancellationToken ct = default);

    /// <exception cref="ArgumentOutOfRangeException">A value is outside 1-720 hours.</exception>
    Task<QuoteWindowSettings> SetQuoteWindowsAsync(
        int boardWindowHours, int validityHours, string? userId, CancellationToken ct = default);

    Task<int> GetPresenceGraceMinutesAsync(CancellationToken ct = default);
}

public class PlatformSettings : IPlatformSettings
{
    private readonly FixoDbContext _context;
    private readonly IOptions<JobFlowOptions> _flow;
    private readonly IAuditLogService _audit;

    public PlatformSettings(
        FixoDbContext context, IOptions<JobFlowOptions> flow, IAuditLogService audit)
    {
        _context = context;
        _flow = flow;
        _audit = audit;
    }

    /// <summary>Pure rule: stored text to a usable hour count, else the fallback.</summary>
    public static int ParseHours(string? stored, int fallback) =>
        int.TryParse(stored, NumberStyles.Integer, CultureInfo.InvariantCulture, out var v)
        && v >= PlatformSettingKeys.MinHours && v <= PlatformSettingKeys.MaxHours
            ? v
            : fallback;

    public async Task<QuoteWindowSettings> GetQuoteWindowsAsync(CancellationToken ct = default)
    {
        var keys = new[] { PlatformSettingKeys.QuotesBoardWindowHours, PlatformSettingKeys.QuotesValidityHours };
        var rows = await _context.PlatformSettings
            .AsNoTracking()
            .Where(s => keys.Contains(s.Key))
            .ToDictionaryAsync(s => s.Key, s => s.Value, ct);

        rows.TryGetValue(PlatformSettingKeys.QuotesBoardWindowHours, out var board);
        rows.TryGetValue(PlatformSettingKeys.QuotesValidityHours, out var validity);

        var o = _flow.Value;
        return new QuoteWindowSettings(
            ParseHours(board, Clamp(o.QuoteBoardWindowHours)),
            ParseHours(validity, Clamp(o.QuoteWindowHours)));
    }

    public async Task<QuoteWindowSettings> SetQuoteWindowsAsync(
        int boardWindowHours, int validityHours, string? userId, CancellationToken ct = default)
    {
        Validate(boardWindowHours, nameof(boardWindowHours));
        Validate(validityHours, nameof(validityHours));

        var before = await GetQuoteWindowsAsync(ct);
        await UpsertAsync(PlatformSettingKeys.QuotesBoardWindowHours, boardWindowHours, userId, ct);
        await UpsertAsync(PlatformSettingKeys.QuotesValidityHours, validityHours, userId, ct);
        await _context.SaveChangesAsync(ct);

        var after = new QuoteWindowSettings(boardWindowHours, validityHours);
        await _audit.LogAsync(userId, "settings.quotes.update", "PlatformSettings", null,
            before, after, ct: ct);
        return after;
    }

    public async Task<int> GetPresenceGraceMinutesAsync(CancellationToken ct = default)
    {
        var row = await _context.PlatformSettings
            .AsNoTracking()
            .Where(s => s.Key == PlatformSettingKeys.PresenceGraceMinutes)
            .Select(s => s.Value)
            .FirstOrDefaultAsync(ct);

        return int.TryParse(row, NumberStyles.Integer, CultureInfo.InvariantCulture, out var v)
            && v >= PlatformSettingKeys.MinPresenceGraceMinutes
            && v <= PlatformSettingKeys.MaxPresenceGraceMinutes
                ? v
                : PlatformSettingKeys.DefaultPresenceGraceMinutes;
    }

    private async Task UpsertAsync(string key, int hours, string? userId, CancellationToken ct)
    {
        var value = hours.ToString(CultureInfo.InvariantCulture);
        var row = await _context.PlatformSettings.FirstOrDefaultAsync(s => s.Key == key, ct);
        if (row == null)
        {
            _context.PlatformSettings.Add(new PlatformSetting
            {
                Key = key,
                Value = value,
                UpdatedAtUtc = DateTime.UtcNow,
                UpdatedByUserId = userId,
            });
            return;
        }
        row.Value = value;
        row.UpdatedAtUtc = DateTime.UtcNow;
        row.UpdatedByUserId = userId;
    }

    private static void Validate(int hours, string name)
    {
        if (hours < PlatformSettingKeys.MinHours || hours > PlatformSettingKeys.MaxHours)
            throw new ArgumentOutOfRangeException(name, hours,
                $"Must be between {PlatformSettingKeys.MinHours} and {PlatformSettingKeys.MaxHours} hours.");
    }

    private static int Clamp(int configured) =>
        Math.Clamp(configured, PlatformSettingKeys.MinHours, PlatformSettingKeys.MaxHours);
}
