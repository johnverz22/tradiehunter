using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace FixoApi.Models;

public class DeviceTokenEntity
{
    [Key]
    public int Id { get; set; }

    [Required]
    public string UserId { get; set; } = string.Empty;

    [ForeignKey("UserId")]
    public ApplicationUser User { get; set; } = null!;

    [Required]
    public string Token { get; set; } = string.Empty;

    public string Platform { get; set; } = string.Empty;
    
    public DateTime LastUpdatedAtUtc { get; set; } = DateTime.UtcNow;
}
