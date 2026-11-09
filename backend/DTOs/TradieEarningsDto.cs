namespace FixoApi.DTOs;

public sealed class TradieEarningsDto
{
    public DateTime PeriodStartUtc { get; init; }
    public DateTime PeriodEndUtc { get; init; }
    public DateTime AsOfUtc { get; init; }
    public string TimeZone { get; init; } = "Pacific/Auckland";
    public string EarnedNet { get; init; } = "0.00";
    public string ProcessedNet { get; init; } = "0.00";
    public string PendingNet { get; init; } = "0.00";
    public string FailedNet { get; init; } = "0.00";
}
