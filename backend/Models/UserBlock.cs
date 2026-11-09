using System.ComponentModel.DataAnnotations;

namespace FixoApi.Models;

/// <summary>
/// A directional block: <see cref="BlockerId"/> no longer wants to see or be
/// matched with <see cref="BlockedId"/> (P8-02). Reports are stored separately
/// as <see cref="AccountFlag"/> rows of type <c>Abuse</c>.
/// </summary>
public class UserBlock
{
    [Key]
    public int Id { get; set; }

    [Required]
    [MaxLength(128)]
    public string BlockerId { get; set; } = string.Empty;

    [Required]
    [MaxLength(128)]
    public string BlockedId { get; set; } = string.Empty;

    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}
