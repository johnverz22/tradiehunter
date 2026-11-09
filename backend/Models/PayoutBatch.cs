using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using FixoApi.Enums;

namespace FixoApi.Models;

public class PayoutBatch
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    public DateTime PeriodStartUtc { get; set; }
    public DateTime PeriodEndUtc { get; set; }
    
    public decimal TotalAmount { get; set; }
    public int PayoutCount { get; set; }
    
    public PayoutBatchStatus Status { get; set; } = PayoutBatchStatus.Open;
    
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime? CompletedAtUtc { get; set; }
    
    public ICollection<TradiePayout> Payouts { get; set; } = new List<TradiePayout>();
}
