using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace FixoApi.Models;

/// <summary>
/// Post-job review left by either homeowner or tradie.
/// Unique constraint: one review per reviewer per job (enforced in EF config).
/// Rating range 1–5 enforced via CHECK constraint added in migration.
/// </summary>
public class Review
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public int JobId { get; set; }
    public Job Job { get; set; } = null!;

    public string ReviewerId { get; set; } = null!;
    public ApplicationUser Reviewer { get; set; } = null!;

    public string RevieweeId { get; set; } = null!;
    public ApplicationUser Reviewee { get; set; } = null!;

    [Range(1, 5)]
    public int Rating { get; set; }

    [MaxLength(1000)]
    public string? Comment { get; set; }

    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}
