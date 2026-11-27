using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Models;
using FixoApi.Options;
using FixoApi.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FixoApi.Tests;

/// <summary>Plan 10 (Q7.1): DB-backed quote windows with config fallback.</summary>
public class PlatformSettingsTests
{
    private sealed class RecordingAudit : IAuditLogService
    {
        public List<(string? UserId, string Action, object? Old, object? New)> Entries { get; } = [];

        public Task LogAsync(string? userId, string action, string? entityType = null,
            string? entityId = null, object? oldValues = null, object? newValues = null,
            string? ipAddress = null, CancellationToken ct = default)
        {
            Entries.Add((userId, action, oldValues, newValues));
            return Task.CompletedTask;
        }

        public Task<PagedResult<AuditLogDto>> QueryAsync(DateTime? fromUtc, DateTime? toUtc,
            string? action, string? userId, int page, int pageSize, CancellationToken ct = default)
            => throw new NotSupportedException();
    }

    private static (PlatformSettings Sut, FixoDbContext Db, RecordingAudit Audit) Make(
        JobFlowOptions? flow = null)
    {
        var db = new FixoDbContext(new DbContextOptionsBuilder<FixoDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options);
        var audit = new RecordingAudit();
        var sut = new PlatformSettings(db, Microsoft.Extensions.Options.Options.Create(flow ?? new JobFlowOptions()), audit);
        return (sut, db, audit);
    }

    [Theory]
    [InlineData("72", 5, 72)]
    [InlineData("1", 5, 1)]
    [InlineData("720", 5, 720)]
    [InlineData("0", 5, 5)]
    [InlineData("721", 5, 5)]
    [InlineData("-3", 5, 5)]
    [InlineData("abc", 5, 5)]
    [InlineData("", 5, 5)]
    [InlineData(null, 5, 5)]
    public void ParseHours_accepts_only_1_to_720(string? stored, int fallback, int expected) =>
        Assert.Equal(expected, PlatformSettings.ParseHours(stored, fallback));

    [Fact]
    public async Task No_rows_means_config_defaults_of_72_hours()
    {
        var (sut, _, _) = Make();
        var w = await sut.GetQuoteWindowsAsync();
        Assert.Equal(72, w.BoardWindowHours);
        Assert.Equal(72, w.ValidityHours);
    }

    [Fact]
    public async Task No_rows_uses_configured_fallbacks()
    {
        var (sut, _, _) = Make(new JobFlowOptions { QuoteBoardWindowHours = 48, QuoteWindowHours = 96 });
        var w = await sut.GetQuoteWindowsAsync();
        Assert.Equal(48, w.BoardWindowHours);
        Assert.Equal(96, w.ValidityHours);
    }

    [Fact]
    public async Task Set_persists_and_overrides_config()
    {
        var (sut, db, _) = Make();
        var saved = await sut.SetQuoteWindowsAsync(24, 120, "admin-1");

        Assert.Equal(new QuoteWindowSettings(24, 120), saved);
        Assert.Equal(new QuoteWindowSettings(24, 120), await sut.GetQuoteWindowsAsync());
        Assert.Equal(2, await db.PlatformSettings.CountAsync());
        var row = await db.PlatformSettings.SingleAsync(s => s.Key == PlatformSettingKeys.QuotesBoardWindowHours);
        Assert.Equal("24", row.Value);
        Assert.Equal("admin-1", row.UpdatedByUserId);
    }

    [Fact]
    public async Task Second_set_updates_rows_instead_of_adding()
    {
        var (sut, db, _) = Make();
        await sut.SetQuoteWindowsAsync(24, 120, "a");
        await sut.SetQuoteWindowsAsync(36, 48, "b");

        Assert.Equal(2, await db.PlatformSettings.CountAsync());
        Assert.Equal(new QuoteWindowSettings(36, 48), await sut.GetQuoteWindowsAsync());
    }

    [Theory]
    [InlineData(0, 72)]
    [InlineData(72, 0)]
    [InlineData(721, 72)]
    [InlineData(72, 721)]
    [InlineData(-1, 72)]
    public async Task Out_of_range_is_rejected_and_nothing_is_written(int board, int validity)
    {
        var (sut, db, audit) = Make();
        await Assert.ThrowsAsync<ArgumentOutOfRangeException>(
            () => sut.SetQuoteWindowsAsync(board, validity, "a"));

        Assert.Equal(0, await db.PlatformSettings.CountAsync());
        Assert.Empty(audit.Entries);
    }

    [Fact]
    public async Task Change_is_audited_with_old_and_new_values()
    {
        var (sut, _, audit) = Make();
        await sut.SetQuoteWindowsAsync(24, 120, "admin-1");

        var e = Assert.Single(audit.Entries);
        Assert.Equal("admin-1", e.UserId);
        Assert.Equal("settings.quotes.update", e.Action);
        Assert.Equal(new QuoteWindowSettings(72, 72), e.Old);
        Assert.Equal(new QuoteWindowSettings(24, 120), e.New);
    }

    [Fact]
    public async Task Unusable_stored_value_falls_back_instead_of_breaking_quoting()
    {
        var (sut, db, _) = Make();
        db.PlatformSettings.Add(new PlatformSetting { Key = PlatformSettingKeys.QuotesValidityHours, Value = "soon" });
        db.PlatformSettings.Add(new PlatformSetting { Key = PlatformSettingKeys.QuotesBoardWindowHours, Value = "5000" });
        await db.SaveChangesAsync();

        Assert.Equal(new QuoteWindowSettings(72, 72), await sut.GetQuoteWindowsAsync());
    }

    [Fact]
    public async Task Misconfigured_fallback_is_clamped_into_range()
    {
        var (sut, _, _) = Make(new JobFlowOptions { QuoteBoardWindowHours = 0, QuoteWindowHours = 99999 });
        var w = await sut.GetQuoteWindowsAsync();
        Assert.Equal(1, w.BoardWindowHours);
        Assert.Equal(720, w.ValidityHours);
    }
}
