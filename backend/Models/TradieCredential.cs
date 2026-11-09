using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using FixoApi.Enums;

namespace FixoApi.Models;

public class TradieCredential
{
    [Key]
    public int Id { get; set; }

    public int TradieProfileId { get; set; }

    [ForeignKey("TradieProfileId")]
    public TradieProfile TradieProfile { get; set; } = null!;

    public CredentialType Type { get; set; }
    
    [Required]
    public string FileKey { get; set; } = string.Empty;
    
    [Required]
    public string OriginalFileName { get; set; } = string.Empty;
    
    public CredentialStatus Status { get; set; } = CredentialStatus.Pending;

    public string? ReviewedById { get; set; }

    [ForeignKey("ReviewedById")]
    public ApplicationUser? ReviewedBy { get; set; }

    public DateTime? ReviewedAtUtc { get; set; }
    
    public string? RejectReason { get; set; }
}
