using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using FixoApi.Models;

namespace FixoApi.Models;

public class RefreshToken
{
    [Key]
    public int Id { get; set; }

    [Required]
    [MaxLength(450)]
    public string UserId { get; set; } = null!;

    [ForeignKey(nameof(UserId))]
    public ApplicationUser User { get; set; } = null!;

    [Required]
    [MaxLength(64)] // Hex string of SHA256 is 64 chars
    public string TokenHash { get; set; } = null!;

    [Required]
    public DateTime ExpiresAtUtc { get; set; }

    public DateTime? ConsumedAtUtc { get; set; }

    [MaxLength(64)]
    public string? ReplacedByTokenHash { get; set; }

    [Required]
    public DateTime CreatedAtUtc { get; set; }
}
