using FixoApi.Enums;
using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace FixoApi.Models;

/// <summary>
/// Evidence attached to a dispute: a photo, a free-text note, or a private
/// document. Photos/documents are stored in Azure Blob (Azurite locally);
/// text is stored inline.
/// </summary>
public class DisputeEvidence
{
    [Key]
    public int Id { get; set; }

    public int DisputeId { get; set; }

    [ForeignKey(nameof(DisputeId))]
    public Dispute Dispute { get; set; } = null!;

    [Required]
    [MaxLength(128)]
    public string SubmittedBy { get; set; } = string.Empty;

    public DisputeEvidenceType Type { get; set; } = DisputeEvidenceType.Text;

    /// <summary>Blob key for Photo / Document evidence. Null for Text.</summary>
    [MaxLength(512)]
    public string? FileKey { get; set; }

    [MaxLength(4000)]
    public string? TextContent { get; set; }

    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}