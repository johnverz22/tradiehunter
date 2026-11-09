using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace FixoApi.DTOs;

public class CreateDisputeRequest
{
    [Required]
    public int JobId { get; set; }

    [Required]
    [MaxLength(2000)]
    public string Reason { get; set; } = string.Empty;
}

public class AddEvidenceTextRequest
{
    [Required]
    [MaxLength(4000)]
    public string TextContent { get; set; } = string.Empty;
}

public class DisputeDto
{
    public int Id { get; set; }
    public int JobId { get; set; }
    public string OpenedBy { get; set; } = string.Empty;
    public DateTime OpenedAtUtc { get; set; }
    public string Status { get; set; } = string.Empty;
    public string Outcome { get; set; } = string.Empty;
    public string? DecidedBy { get; set; }
    public DateTime? DecidedAtUtc { get; set; }
    public string? DecisionNote { get; set; }
    public string? OpenReason { get; set; }
    public DateTime? ResolvedAtUtc { get; set; }
    public List<DisputeEvidenceDto> Evidence { get; set; } = new();
}

public class DisputeEvidenceDto
{
    public int Id { get; set; }
    public string SubmittedBy { get; set; } = string.Empty;
    public string Type { get; set; } = string.Empty;
    public string? FileKey { get; set; }
    public string? TextContent { get; set; }
    public DateTime CreatedAtUtc { get; set; }

    /// <summary>
    /// P8-03: short-lived signed read URL for private dispute evidence.
    /// Null for text evidence or when the SAS could not be issued.
    /// </summary>
    public string? DownloadUrl { get; set; }
}
