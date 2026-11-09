namespace FixoApi.Services.Payout;

public static class EarningsWeek
{
    public const string TimeZoneId = "Pacific/Auckland";

    public static (DateTime StartUtc, DateTime EndUtc) Containing(DateTime nowUtc)
    {
        var zone = TimeZoneInfo.FindSystemTimeZoneById(TimeZoneId);
        var local = TimeZoneInfo.ConvertTimeFromUtc(nowUtc.ToUniversalTime(), zone);
        var monday = DateTime.SpecifyKind(local.Date.AddDays(-((int)local.DayOfWeek + 6) % 7), DateTimeKind.Unspecified);
        return (TimeZoneInfo.ConvertTimeToUtc(monday, zone),
            TimeZoneInfo.ConvertTimeToUtc(monday.AddDays(7), zone));
    }
}
