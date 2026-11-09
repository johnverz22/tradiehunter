using System;
using System.Collections.Generic;

namespace FixoApi.DTOs;

public class ProcessPayoutRequest
{
    public string TransferReference { get; set; } = string.Empty;
}

/// <summary>
/// One row of the admin payout queue.
///
/// Projected rather than serialised from <c>TradiePayout</c> on purpose: the entity
/// carries the full <c>ApplicationUser</c> navigation (password hash, security
/// stamp, lockout state) and the untruncated account number. Staff only ever need
/// the tradie's name and enough of the account to match a bank statement, so the
/// account is reduced to its last four digits here.
/// </summary>
public class PayoutQueueItemDto
{
    public Guid Id { get; set; }
    public string TradieId { get; set; } = string.Empty;
    public string TradieName { get; set; } = string.Empty;

    public int JobId { get; set; }
    public string JobReferenceCode { get; set; } = string.Empty;
    public string JobTitle { get; set; } = string.Empty;

    public decimal GrossAmount { get; set; }
    public decimal CommissionPercent { get; set; }
    public decimal CommissionAmount { get; set; }
    public decimal NetAmount { get; set; }

    /// <summary>Pending | Scheduled | Processed | Failed.</summary>
    public string Status { get; set; } = string.Empty;

    public Guid? PayoutBatchId { get; set; }

    public string? BankAccountName { get; set; }

    /// <summary>Last four digits of the tradie's account, for statement matching.</summary>
    public string? BankAccountLast4 { get; set; }

    /// <summary>False when the payout was created before the tradie supplied details.</summary>
    public bool HasBankDetails { get; set; }

    public DateTime CreatedAtUtc { get; set; }
    public DateTime? ProcessedAtUtc { get; set; }
    public string? TransferReference { get; set; }
}

public class PayoutBatchSummaryDto
{
    public Guid Id { get; set; }
    public DateTime PeriodStartUtc { get; set; }
    public DateTime PeriodEndUtc { get; set; }
    public decimal TotalAmount { get; set; }
    public int PayoutCount { get; set; }

    /// <summary>Payouts already marked Processed — the admin's progress indicator.</summary>
    public int ProcessedCount { get; set; }

    /// <summary>Open | Processing | Completed.</summary>
    public string Status { get; set; } = string.Empty;

    public DateTime CreatedAtUtc { get; set; }
    public DateTime? CompletedAtUtc { get; set; }
}

public class PayoutBatchDetailDto : PayoutBatchSummaryDto
{
    public List<PayoutQueueItemDto> Payouts { get; set; } = new();
}
