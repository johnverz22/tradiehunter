namespace FixoApi.Options;

public sealed class AddressResolutionOptions
{
    public string Provider { get; set; } = "Linz";
    public LinzAddressOptions Linz { get; set; } = new();
}

public sealed class LinzAddressOptions
{
    public string ApiKey { get; set; } = "";
    public int LayerId { get; set; } = 123113;
}
