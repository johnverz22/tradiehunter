using FixoApi.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace FixoApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ConfigController : ControllerBase
{
    private readonly LocaleOptions _localeOptions;

    public ConfigController(IOptions<LocaleOptions> localeOptions)
    {
        _localeOptions = localeOptions.Value;
    }

    [HttpGet("locale")]
    public IActionResult GetLocale()
    {
        return Ok(_localeOptions);
    }
}
