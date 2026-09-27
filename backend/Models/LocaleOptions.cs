namespace FixoApi.Models;

public class LocaleOptions
{
    public string DefaultCurrency { get; set; } = "NZD";
    public string CurrencySymbol { get; set; } = "$";
    public string PhoneCountryCode { get; set; } = "+64";
    public string DefaultTimezone { get; set; } = "Pacific/Auckland";
    public string DistanceUnit { get; set; } = "km";
}
