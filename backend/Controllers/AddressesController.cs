using FixoApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace FixoApi.Controllers;

[ApiController]
[Route("api/addresses")]
[Authorize]
[EnableRateLimiting("address-search")]
public sealed class AddressesController(IAddressResolver resolver) : ControllerBase
{
    [HttpGet("search")]
    [ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
    public async Task<ActionResult<AddressSearchResult>> Search([FromQuery] string? query, CancellationToken cancellationToken)
    {
        query = query?.Trim();
        if (string.IsNullOrWhiteSpace(query) || query.Length is < 3 or > 160
            || query.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries).Length > 12)
            return BadRequest(new { message = "Enter between 3 and 160 characters, up to 12 words." });
        try
        {
            return Ok(await resolver.SearchAsync(query, cancellationToken));
        }
        catch (AddressResolutionUnavailableException)
        {
            return StatusCode(503, new { message = "Address search is temporarily unavailable. Please try again." });
        }
    }
}
