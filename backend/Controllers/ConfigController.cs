using FixoApi.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace FixoApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ConfigController : ControllerBase
{
    private readonly LocaleOptions _localeOptions;
    private readonly FixoApi.Options.PayoutOptions _payoutOptions;
    private readonly FixoApi.Options.BrandOptions _brandOptions;

    public ConfigController(
        IOptions<LocaleOptions> localeOptions,
        IOptions<FixoApi.Options.PayoutOptions> payoutOptions,
        IOptions<FixoApi.Options.BrandOptions> brandOptions)
    {
        _localeOptions = localeOptions.Value;
        _payoutOptions = payoutOptions.Value;
        _brandOptions = brandOptions.Value;
    }

    [HttpGet("locale")]
    public IActionResult GetLocale()
    {
        var response = new
        {
            Locale = _localeOptions,
            CommissionPercent = _payoutOptions.CommissionPercent,
            Brand = _brandOptions
        };
        
        return Ok(response);
    }
}
