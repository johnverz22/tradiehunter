namespace FixoApi.Options;

public class PayoutOptions
{
    public decimal CommissionPercent { get; set; } = 12.5m;
    public string PayoutDay { get; set; } = "Monday";
    public decimal MinimumPayoutAmount { get; set; } = 0m;
    public string PayoutBatchCron { get; set; } = "0 2 * * 1";
}
