using FixoApi.Services.Payout;
using Microsoft.EntityFrameworkCore;

var assertions = 0;
void Equal<T>(T actual, T expected)
{
    assertions++;
    if (!Equals(actual, expected)) throw new Exception($"Expected {expected}, received {actual}");
}
DateTime Utc(string value) => DateTime.Parse(value, null, System.Globalization.DateTimeStyles.AdjustToUniversal);

var winter = EarningsWeek.Containing(Utc("2026-07-08T00:00:00Z"));
Equal(winter.StartUtc, Utc("2026-07-05T12:00:00Z"));
Equal(winter.EndUtc, Utc("2026-07-12T12:00:00Z"));
var summer = EarningsWeek.Containing(Utc("2026-01-07T00:00:00Z"));
Equal(summer.StartUtc, Utc("2026-01-04T11:00:00Z"));
Equal(summer.EndUtc, Utc("2026-01-11T11:00:00Z"));
var spring = EarningsWeek.Containing(Utc("2026-09-27T00:00:00Z"));
Equal(spring.EndUtc - spring.StartUtc, TimeSpan.FromHours(167));
var autumn = EarningsWeek.Containing(Utc("2026-04-05T00:00:00Z"));
Equal(autumn.EndUtc - autumn.StartUtc, TimeSpan.FromHours(169));
Equal(EarningsWeek.Containing(winter.StartUtc).StartUtc, winter.StartUtc);
Equal(EarningsWeek.Containing(winter.EndUtc.AddTicks(-1)).StartUtc, winter.StartUtc);
Equal(EarningsWeek.Containing(winter.EndUtc).StartUtc, winter.EndUtc);
Equal(winter.StartUtc.Kind, DateTimeKind.Utc);
Equal(winter.EndUtc.Kind, DateTimeKind.Utc);
var now = Utc("2026-07-08T00:00:00Z");
FixoApi.Models.TradiePayout Row(decimal net, DateTime created, FixoApi.Enums.PayoutStatus status, DateTime? processed = null, string owner = "a") => new()
{
    TradieId = owner, NetAmount = net, CreatedAtUtc = created, Status = status, ProcessedAtUtc = processed,
};
var rows = new[]
{
    Row(0.10m, winter.StartUtc, FixoApi.Enums.PayoutStatus.Pending),
    Row(0.20m, now, FixoApi.Enums.PayoutStatus.Scheduled),
    Row(5m, winter.StartUtc.AddTicks(-1), FixoApi.Enums.PayoutStatus.Processed, now),
    Row(7m, now, FixoApi.Enums.PayoutStatus.Failed),
    Row(100m, winter.EndUtc, FixoApi.Enums.PayoutStatus.Processed, winter.EndUtc),
    Row(900m, now, FixoApi.Enums.PayoutStatus.Pending, owner: "b"),
};
var totals = TradieEarningsService.Totals(rows.AsQueryable(), "a", winter.StartUtc, winter.EndUtc, now).Single();
Equal(totals.Earned, 7.30m);
Equal(totals.Processed, 5m);
Equal(totals.Pending, 0.30m);
Equal(totals.Failed, 7m);
Equal(TradieEarningsService.Totals(rows.AsQueryable(), "missing", winter.StartUtc, winter.EndUtc, now).SingleOrDefault(), null);
var action = typeof(FixoApi.Controllers.TradieController).GetMethod("GetEarnings")!;
Equal(action.GetCustomAttributes(typeof(Microsoft.AspNetCore.Authorization.AuthorizeAttribute), false)
    .Cast<Microsoft.AspNetCore.Authorization.AuthorizeAttribute>().Single().Roles, "Tradie");
using var context = new FixoApi.Data.FixoDbContext(
    new DbContextOptionsBuilder<FixoApi.Data.FixoDbContext>()
        .UseNpgsql("Host=localhost;Database=unused", options => options.UseNetTopologySuite()).Options);
var sql = TradieEarningsService.Totals(context.TradiePayouts, "a", winter.StartUtc, winter.EndUtc, now).ToQueryString();
Equal(sql.Contains("GROUP BY"), true);
Equal(sql.Contains("SUM", StringComparison.OrdinalIgnoreCase), true);
Console.WriteLine($"{assertions} earnings assertions passed.");
