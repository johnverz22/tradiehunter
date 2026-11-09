using System.Text;
using System.Text.Json;
using System.Xml.Linq;
using FixoApi.Options;
using Microsoft.Extensions.Options;

namespace FixoApi.Services;

public sealed class LinzAddressResolver(HttpClient client, IOptions<AddressResolutionOptions> options)
    : IAddressResolver
{
    private const string Attribution = "Sourced from the LINZ Data Service and licensed for reuse under CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).";
    private static readonly XNamespace Wfs = "http://www.opengis.net/wfs/2.0";
    private static readonly XNamespace Fes = "http://www.opengis.net/fes/2.0";

    public async Task<AddressSearchResult> SearchAsync(string query, CancellationToken cancellationToken)
    {
        var config = options.Value.Linz;
        if (string.IsNullOrWhiteSpace(config.ApiKey) || config.LayerId <= 0)
            throw new AddressResolutionUnavailableException();
        var tokens = query.Trim().Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
        if (query.Trim().Length is < 3 or > 160 || tokens.Length > 12)
            throw new ArgumentException("Enter between 3 and 160 characters, up to 12 words.", nameof(query));

        var filters = tokens.Select(token => new XElement(Fes + "PropertyIsLike",
            new XAttribute("wildCard", "*"), new XAttribute("singleChar", "?"),
            new XAttribute("escapeChar", "!"), new XAttribute("matchCase", "false"),
            new XElement(Fes + "ValueReference", "full_address"),
            new XElement(Fes + "Literal", "*" + token.Replace("!", "!!").Replace("*", "!*").Replace("?", "!?") + "*")));
        var document = new XElement(Wfs + "GetFeature",
            new XAttribute(XNamespace.Xmlns + "wfs", Wfs), new XAttribute(XNamespace.Xmlns + "fes", Fes),
            new XAttribute("service", "WFS"), new XAttribute("version", "2.0.0"),
            new XAttribute("count", "8"), new XAttribute("outputFormat", "application/json"),
            new XElement(Wfs + "Query", new XAttribute("typeNames", $"layer-{config.LayerId}"),
                new XAttribute("srsName", "urn:ogc:def:crs:OGC::CRS84"),
                new XElement(Fes + "Filter", new XElement(Fes + "And",
                    new XElement(Fes + "PropertyIsEqualTo",
                        new XElement(Fes + "ValueReference", "address_lifecycle"),
                        new XElement(Fes + "Literal", "Current")), filters)),
                new XElement(Fes + "SortBy", new XElement(Fes + "SortProperty",
                    new XElement(Fes + "ValueReference", "full_address"),
                    new XElement(Fes + "SortOrder", "ASC")))));
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Post,
                $"https://data.linz.govt.nz/services;key={Uri.EscapeDataString(config.ApiKey)}/wfs")
            {
                Content = new StringContent(document.ToString(), Encoding.UTF8, "text/xml")
            };
            using var response = await client.SendAsync(request, cancellationToken);
            response.EnsureSuccessStatusCode();
            using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync(cancellationToken));
            if (!json.RootElement.TryGetProperty("features", out var features) || features.ValueKind != JsonValueKind.Array)
                throw new AddressResolutionUnavailableException();
            var items = new List<AddressCandidate>();
            foreach (var feature in features.EnumerateArray().Take(8))
            {
                var properties = feature.GetProperty("properties");
                var geometry = feature.GetProperty("geometry");
                if (geometry.ValueKind != JsonValueKind.Object || geometry.GetProperty("type").GetString() != "Point")
                    continue;
                var coordinates = geometry.GetProperty("coordinates");
                var longitude = coordinates[0].GetDouble();
                var latitude = coordinates[1].GetDouble();
                var address = properties.GetProperty("full_address").GetString();
                var id = properties.GetProperty("address_id").ToString();
                if (!double.IsFinite(latitude) || !double.IsFinite(longitude) || latitude is < -90 or > 90
                    || longitude is < -180 or > 180 || string.IsNullOrWhiteSpace(address) || string.IsNullOrWhiteSpace(id))
                    continue;
                items.Add(new AddressCandidate($"linz:{config.LayerId}:{id}", address,
                    properties.TryGetProperty("suburb_locality", out var suburb) ? suburb.GetString() : null,
                    properties.TryGetProperty("town_city", out var city) ? city.GetString() : null, latitude, longitude));
            }
            return new AddressSearchResult("Linz", Attribution, "https://data.linz.govt.nz/", items);
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            throw new AddressResolutionUnavailableException();
        }
        catch (Exception exception) when (exception is HttpRequestException or JsonException or InvalidOperationException
            or KeyNotFoundException or IndexOutOfRangeException or FormatException)
        {
            throw new AddressResolutionUnavailableException();
        }
    }
}
