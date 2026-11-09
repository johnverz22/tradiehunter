using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace FixoApi.Models;

/// <summary>
/// Photo attached to a job. Stored as a blob under jobs/{jobId}/{guid}.{ext}.
/// </summary>
public class JobPhoto
{
    [Key]
    public int Id { get; set; }

    public int JobId { get; set; }

    [ForeignKey(nameof(JobId))]
    public Job Job { get; set; } = null!;

    /// <summary>Blob name, e.g. jobs/42/3fa85f64-5717-4562-b3fc-2c963f66afa6.jpg</summary>
    /// <remarks>Column keeps the legacy S3Key name to avoid a data migration.</remarks>
    [Required]
    [MaxLength(500)]
    [Column("S3Key")]
    public string BlobKey { get; set; } = string.Empty;

    [MaxLength(260)]
    public string? OriginalFileName { get; set; }

    [MaxLength(100)]
    public string? ContentType { get; set; }

    public DateTime UploadedAtUtc { get; set; } = DateTime.UtcNow;
}
