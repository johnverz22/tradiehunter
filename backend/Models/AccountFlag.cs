using FixoApi.Enums;
using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace FixoApi.Models;

/// <summary>
/// An account flag — a counter-based reputation signal for a user.
/// Counters are incremented by the flagging services (no-show reporting,
/// repeat cancellations, manual admin flags). When a counter reaches its
/// threshold the row is marked ThresholdHit and an admin is notified.
/// </summary>
public class AccountFlag
{
    [Key]
    public int Id { get; set; }

    [Required]
    [MaxLength(128)]
    public string UserId { get; set; } = string.Empty;

    public AccountFlagType Type { get; set; }

    public int Counter { get; set; } = 0;

    public bool ThresholdHit { get; set; } = false;

    [MaxLength(128)]
    public string? CreatedBy { get; set; }

    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;

    [MaxLength(2000)]
    public string? Note { get; set; }

    public bool Resolved { get; set; } = false;

    public DateTime? ResolvedAtUtc { get; set; }
}