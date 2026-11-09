namespace FixoApi.Models;

public class LocaleOptions
{
    public string DefaultCurrency { get; set; } = "NZD";
    public string CurrencySymbol { get; set; } = "$";
    public string PhoneCountryCode { get; set; } = "+64";
    public string DefaultTimezone { get; set; } = "Pacific/Auckland";
    public string DistanceUnit { get; set; } = "km";
    
    // P10-15 Brand & Legal
    public string? LegalEntityName { get; set; }
    public string? LegalEntityCountry { get; set; }
    public string? TermsOfServiceUrl { get; set; }
    public string? PrivacyPolicyUrl { get; set; }
    public string? PilotRegion { get; set; }
    public double MaxSearchRadiusKm { get; set; } = 50.0;
    public double DefaultSearchRadiusKm { get; set; } = 25.0;
    public string MaterialsDisclaimer { get; set; } = "Materials are not included in the quoted price and are settled directly between you and the tradie.";
}
