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

    /// <summary>Self-written "About" blurb shown on the public profile (H17). Max 500 chars.</summary>
    [MaxLength(500)]
    public string? Bio { get; set; }

    /// <summary>Trade registration number shown on the public profile (H17), e.g. "E2491". Max 30 chars.</summary>
    [MaxLength(30)]
    public string? RegistrationNumber { get; set; }

    public bool IsVerified { get; set; } = false;
    
    public bool IsAvailable { get; set; } = true;

    /// <summary>
    /// Last UTC timestamp when the tradie's app was confirmed reachable (JobHub
    /// connect, heartbeat, or last disconnect). Used with <see cref="IsAvailable"/>
    /// and active SignalR connections to compute effective online presence (QA §1).
    /// Cleared to null on explicit logout.
    /// </summary>
    public DateTime? LastSeenAtUtc { get; set; }

    public bool HasInsurance { get; set; } = false;

    [Column(TypeName = "geometry (Point, 4326)")]
    public Point? Location { get; set; }
    
    public string? Address { get; set; }
    
    [Column(TypeName = "decimal(18,2)")]
    public decimal ServiceRadiusKm { get; set; } = 25m;
    
    public string? DeviceToken { get; set; }

    public string? BankAccountName { get; set; }
    
    // TODO: Consider encryption for this field as per P10 implementation notes
    public string? BankAccountNumber { get; set; }
    
    public bool BankAccountVerified { get; set; } = false;

    /// <summary>Running total of tradie-initiated cancellations (P6-02). Used to flag repeated cancellers.</summary>
    public int CancellationCount { get; set; } = 0;

    /// <summary>
    /// v1.7 (P12-05/D8): GST registration flag. Drives consumer-price labelling —
    /// registered tradies' listed rates are GST-inclusive ("Incl. GST");
    /// unregistered tradies legally cannot charge GST ("No GST charged").
    /// NZ businesses under $60k turnover need not register (NZ Fair Trading Act).
    /// </summary>
    public bool IsGstRegistered { get; set; } = false;
}
