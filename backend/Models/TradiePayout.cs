using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using FixoApi.Enums;

namespace FixoApi.Models;

public class TradiePayout
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    public string TradieId { get; set; } = string.Empty;

    [ForeignKey("TradieId")]
    public ApplicationUser Tradie { get; set; } = null!;

    public int JobId { get; set; }

    [ForeignKey("JobId")]
    public Job Job { get; set; } = null!;

    public decimal GrossAmount { get; set; }
    public decimal CommissionPercent { get; set; }
    public decimal CommissionAmount { get; set; }
    public decimal NetAmount { get; set; }

    public PayoutStatus Status { get; set; } = PayoutStatus.Pending;

    public Guid? PayoutBatchId { get; set; }

    [ForeignKey("PayoutBatchId")]
    public PayoutBatch? PayoutBatch { get; set; }

    public string? BankAccountName { get; set; }
    public string? BankAccountNumber { get; set; }
    
    public string? TransferReference { get; set; }

    public string? ProcessedById { get; set; }
    
    [ForeignKey("ProcessedById")]
    public ApplicationUser? ProcessedBy { get; set; }

    public DateTime? ProcessedAtUtc { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}
