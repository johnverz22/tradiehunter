using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace FixoApi.Models;

public class TradieRate
{
    [Key]
    public int Id { get; set; }

    public int TradieProfileId { get; set; }

    [ForeignKey("TradieProfileId")]
    public TradieProfile TradieProfile { get; set; } = null!;

    public int ServiceId { get; set; }

    [ForeignKey("ServiceId")]
    public Service Service { get; set; } = null!;

    public decimal HourlyRate { get; set; }
}
