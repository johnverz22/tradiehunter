using System.ComponentModel.DataAnnotations;
using FixoApi.Enums;

namespace FixoApi.Models;

public class Service
{
    [Key]
    public int Id { get; set; }

    [Required]
    public string Name { get; set; } = string.Empty;

    public TradeCategory Category { get; set; }

    public bool RequiresLicence { get; set; } = false;
    public string? LicenceBoard { get; set; }
}
