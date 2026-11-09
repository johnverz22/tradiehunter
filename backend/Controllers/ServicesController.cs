using FixoApi.DTOs;
using FixoApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FixoApi.Controllers;

[ApiController]
[Route("api/services")]
[Authorize]
public class ServicesController : ControllerBase
{
    private readonly IMatchingService _matchingService;

    public ServicesController(IMatchingService matchingService) =>
        _matchingService = matchingService;

    /// <summary>Returns verified, available nearby tradies and their service rate.</summary>
    [HttpGet("search")]
    public async Task<ActionResult<List<ServiceSearchResultDto>>> Search(
        [FromQuery] double? lat,
        [FromQuery] double? lng,
        [FromQuery] int? serviceId)
    {
        if (!lat.HasValue || !lng.HasValue || !serviceId.HasValue
            || lat.Value is < -90 or > 90
            || lng.Value is < -180 or > 180
            || serviceId.Value <= 0)
            return BadRequest(new { message = "lat, lng, and a positive serviceId are required." });

        return Ok(await _matchingService.FindTradiesForServiceAsync(lat.Value, lng.Value, serviceId.Value));
    }
}
