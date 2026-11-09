namespace FixoApi.Services;

public record AddressCandidate(string Id, string Address, string? Suburb, string? City,
    double Latitude, double Longitude);

public record AddressSearchResult(string Provider, string Attribution, string AttributionUrl,
    IReadOnlyList<AddressCandidate> Items);

public interface IAddressResolver
{
    Task<AddressSearchResult> SearchAsync(string query, CancellationToken cancellationToken);
}

public sealed class AddressResolutionUnavailableException : Exception;
