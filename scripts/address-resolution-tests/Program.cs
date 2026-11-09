using System.Net;
using System.Xml.Linq;
using FixoApi.Controllers;
using FixoApi.Options;
using FixoApi.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

if (args.Contains("--live"))
{
    await LiveProbe.Run();
    return;
}

var passed = 0;
void Check(bool condition, string name)
{
    if (!condition) throw new Exception(name);
    Console.WriteLine($"PASS {name}");
    passed++;
}
async Task Unavailable(Func<Task> action, string name)
{
    try { await action(); }
    catch (AddressResolutionUnavailableException) { Check(true, name); return; }
    throw new Exception(name);
}

const string fixture = """
{"features":[
  {"properties":{"address_id":123,"full_address":"1 Test Road, Auckland","suburb_locality":"Test","town_city":"Auckland"},"geometry":{"type":"Point","coordinates":[174.76,-36.85]}},
  {"properties":{"address_id":456,"full_address":"Invalid coordinate"},"geometry":{"type":"Point","coordinates":[174.76,-136.85]}}
]}
""";
var handler = new FixtureHandler(fixture);
var settings = new AddressResolutionOptions { Linz = new() { ApiKey = "fixture-only-key" } };
var resolver = new LinzAddressResolver(new HttpClient(handler), Options.Create(settings));
var result = await resolver.SearchAsync("1 Test O'Road & *?", default);
Check(result.Items.Count == 1, "invalid coordinates are excluded");
Check(result.Items[0].Latitude == -36.85 && result.Items[0].Longitude == 174.76, "CRS84 longitude latitude axis order");
Check(result.Items[0].Id == "linz:123113:123", "provider-scoped stable identity");
Check(result.Attribution.Contains("CC BY 4.0") && result.Provider == "Linz", "provider and attribution are returned");
var xml = XDocument.Parse(handler.Body!);
Check(xml.Root!.Attribute("count")!.Value == "8", "bounded result count");
Check(handler.Body!.Contains("matchCase=\"false\"") && handler.Body.Contains("!*!?"), "case insensitive search and escaped wildcards");
Check(handler.Body.Contains("Current") && handler.Body.Contains("CRS84"), "current addresses and explicit coordinate system");
Check(handler.Body.Contains("O'Road") && handler.Body.Contains("&amp;"), "XML escapes user input");

var missingKey = new LinzAddressResolver(new HttpClient(handler), Options.Create(new AddressResolutionOptions()));
await Unavailable(() => missingKey.SearchAsync("Test Road", default), "missing key fails safely");
handler.Status = HttpStatusCode.Unauthorized;
await Unavailable(() => resolver.SearchAsync("Test Road", default), "upstream authentication failure is sanitized");
handler.Status = HttpStatusCode.OK;
handler.Response = "<ExceptionReport/>";
await Unavailable(() => resolver.SearchAsync("Test Road", default), "WFS exception is not an empty success");
handler.Response = "{\"features\":[]}";
Check((await resolver.SearchAsync("Test Road", default)).Items.Count == 0, "genuine no results stays empty");
handler.Response = "{\"features\":[{}]}";
await Unavailable(() => resolver.SearchAsync("Test Road", default), "malformed data is unavailable");
var controller = new AddressesController(resolver);
Check((await controller.Search("ab", default)).Result is BadRequestObjectResult, "short query validation");
Check((await controller.Search(new string('a', 161), default)).Result is BadRequestObjectResult, "long query validation");
handler.Status = HttpStatusCode.ServiceUnavailable;
Check((await controller.Search("Test Road", default)).Result is ObjectResult { StatusCode: 503 }, "safe provider failure HTTP status");
var authorization = typeof(AddressesController).GetCustomAttributes(typeof(Microsoft.AspNetCore.Authorization.AuthorizeAttribute), true);
Check(authorization.Length == 1, "endpoint requires authentication");
Console.WriteLine($"{passed} address resolution assertions passed");

sealed class FixtureHandler(string response) : HttpMessageHandler
{
    public string Response { get; set; } = response;
    public HttpStatusCode Status { get; set; } = HttpStatusCode.OK;
    public string? Body { get; private set; }
    protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        Body = await request.Content!.ReadAsStringAsync(cancellationToken);
        return new HttpResponseMessage(Status) { Content = new StringContent(Response) };
    }
}
