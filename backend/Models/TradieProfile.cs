using NetTopologySuite.Geometries;
using FixoApi.Enums;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace FixoApi.Models;

public class TradieProfile
{
    [Key]
    public int Id { get; set; }

    [Required]
    public string UserId { get; set; } = string.Empty;

    [ForeignKey("UserId")]
    public ApplicationUser User { get; set; } = null!;

    public string TradeType { get; set; } = string.Empty;
    
    public string? BusinessName { get; set; }
    
    public bool IsVerified { get; set; } = false;
    
    public bool IsAvailable { get; set; } = true;

    [Column(TypeName = "geometry (Point, 4326)")]
    public Point? Location { get; set; }
    
    public string? Address { get; set; }
    
    [Column(TypeName = "decimal(18,2)")]
    public decimal ServiceRadiusKm { get; set; } = 25m;
    
    public string? DeviceToken { get; set; }
}
