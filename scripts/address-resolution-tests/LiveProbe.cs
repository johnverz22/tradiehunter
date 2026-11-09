using System.Net;
using System.Xml.Linq;
using FixoApi.Options;
using FixoApi.Services;
using Microsoft.Extensions.Options;

static class LiveProbe
{
    public static async Task Run()
    {
        var key = Environment.GetEnvironmentVariable("AddressResolution__Linz__ApiKey") ?? "";
        if (string.IsNullOrWhiteSpace(key))
        {
            Console.WriteLine("LINZ key is not configured in the container environment.");
            Environment.ExitCode = 1;
            return;
        }
        var handler = new ProbeHandler();
        using var client = new HttpClient(handler) { Timeout = TimeSpan.FromSeconds(15), MaxResponseContentBufferSize = 1024 * 1024 };
        var settings = new AddressResolutionOptions
        {
            Linz = new() { ApiKey = key, LayerId = int.TryParse(Environment.GetEnvironmentVariable("AddressResolution__Linz__LayerId"), out var layer) ? layer : 123113 }
        };
        var resolver = new LinzAddressResolver(client, Options.Create(settings));
        try
        {
            foreach (var query in new[] { "70 Symonds Street Auckland", "701/145 Symonds Street Auckland",
                "116 Herbert Road Mangateparu", "Ōtaki", "ZZZNoSuchRoadFixture987654 Auckland" })
            {
                var result = await resolver.SearchAsync(query, default);
                var validCoordinates = result.Items.All(item => double.IsFinite(item.Latitude) && double.IsFinite(item.Longitude)
                    && Math.Abs(item.Latitude) <= 90 && Math.Abs(item.Longitude) <= 180);
                Console.WriteLine($"LINZ search query={query}; HTTP {(int?)handler.Status}; provider={result.Provider}; results={result.Items.Count}; validCoordinates={validCoordinates}");
                if (!validCoordinates || (query.StartsWith("ZZZ") ? result.Items.Count != 0 : result.Items.Count == 0))
                    Environment.ExitCode = 1;
            }
        }
        catch (AddressResolutionUnavailableException)
        {
            Console.WriteLine($"LINZ search unavailable; HTTP status={(int?)handler.Status}; content-type={handler.ContentType ?? "none"}; transport={handler.TransportError ?? "none"}");
            try
            {
                var xml = XDocument.Parse(handler.Body ?? "");
                foreach (var exception in xml.Descendants().Where(node => node.Name.LocalName == "Exception"))
                {
                    Console.WriteLine($"WFS exception code={exception.Attribute("exceptionCode")?.Value}");
                    foreach (var text in exception.Descendants().Where(node => node.Name.LocalName == "ExceptionText"))
                    {
                        var safe = text.Value.Replace(key, "[REDACTED]").Replace(Uri.EscapeDataString(key), "[REDACTED]");
                        Console.WriteLine(safe[..Math.Min(1000, safe.Length)]);
                    }
                }
            }
            catch (System.Xml.XmlException) { }
            Environment.ExitCode = 1;
        }
    }

    private sealed class ProbeHandler() : DelegatingHandler(new HttpClientHandler { AllowAutoRedirect = false })
    {
        public HttpStatusCode? Status { get; private set; }
        public string? ContentType { get; private set; }
        public string? Body { get; private set; }
        public string? TransportError { get; private set; }

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            try
            {
                var response = await base.SendAsync(request, cancellationToken);
                Status = response.StatusCode;
                ContentType = response.Content.Headers.ContentType?.MediaType;
                Body = await response.Content.ReadAsStringAsync(cancellationToken);
                return response;
            }
            catch (HttpRequestException exception)
            {
                TransportError = exception.HttpRequestError.ToString();
                throw;
            }
            catch (OperationCanceledException)
            {
                TransportError = "timeout/cancellation";
                throw;
            }
        }
    }
}
