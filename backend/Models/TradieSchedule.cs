using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace FixoApi.Models;

public class TradieSchedule
{
    [Key]
    public int Id { get; set; }

    public int TradieProfileId { get; set; }

    [ForeignKey("TradieProfileId")]
    public TradieProfile TradieProfile { get; set; } = null!;

    public int Weekday { get; set; }
    
    public TimeSpan StartTime { get; set; }
    
    public TimeSpan EndTime { get; set; }
}
