using System.Globalization;
using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Enums;
using Microsoft.EntityFrameworkCore;

namespace FixoApi.Services.Payout;

public sealed class TradieEarningsService(FixoDbContext context)
{
    public async Task<TradieEarningsDto> GetAsync(string tradieId, DateTime nowUtc)
    {
        var (start, end) = EarningsWeek.Containing(nowUtc);
        var totals = await Totals(context.TradiePayouts.AsNoTracking(), tradieId, start, end, nowUtc)
            .SingleOrDefaultAsync();

        return new TradieEarningsDto
        {
            PeriodStartUtc = start,
            PeriodEndUtc = end,
            AsOfUtc = nowUtc,
            TimeZone = EarningsWeek.TimeZoneId,
            EarnedNet = (totals?.Earned ?? 0m).ToString("0.00", CultureInfo.InvariantCulture),
            ProcessedNet = (totals?.Processed ?? 0m).ToString("0.00", CultureInfo.InvariantCulture),
            PendingNet = (totals?.Pending ?? 0m).ToString("0.00", CultureInfo.InvariantCulture),
            FailedNet = (totals?.Failed ?? 0m).ToString("0.00", CultureInfo.InvariantCulture),
        };
    }

    public sealed record EarningsTotals(decimal Earned, decimal Processed, decimal Pending, decimal Failed);

    public static IQueryable<EarningsTotals> Totals(
        IQueryable<FixoApi.Models.TradiePayout> payouts, string tradieId,
        DateTime start, DateTime end, DateTime nowUtc) => payouts
            .Where(p => p.TradieId == tradieId)
            .GroupBy(p => p.TradieId)
            .Select(g => new EarningsTotals(
                g.Sum(p => p.CreatedAtUtc >= start && p.CreatedAtUtc < end && p.CreatedAtUtc <= nowUtc ? p.NetAmount : 0m),
                g.Sum(p => p.Status == PayoutStatus.Processed && p.ProcessedAtUtc >= start && p.ProcessedAtUtc < end && p.ProcessedAtUtc <= nowUtc ? p.NetAmount : 0m),
                g.Sum(p => p.Status == PayoutStatus.Pending || p.Status == PayoutStatus.Scheduled ? p.NetAmount : 0m),
                g.Sum(p => p.Status == PayoutStatus.Failed ? p.NetAmount : 0m)));
}
