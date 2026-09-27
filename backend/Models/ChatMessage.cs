using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace FixoApi.Models;

/// <summary>
/// A chat message sent within the context of a specific job.
/// Transport is the SignalR ChatHub; history is served via REST.
/// Cascade-deleted when the parent Job is deleted.
/// </summary>
public class ChatMessage
{
    [Key]
    public int Id { get; set; }

    /// <summary>The job this conversation belongs to.</summary>
    public int JobId { get; set; }

    [ForeignKey(nameof(JobId))]
    public Job Job { get; set; } = null!;

    /// <summary>The user who sent the message.</summary>
    [Required]
    public string SenderId { get; set; } = string.Empty;

    [ForeignKey(nameof(SenderId))]
    public ApplicationUser Sender { get; set; } = null!;

    /// <summary>Message body — max 2000 characters.</summary>
    [Required]
    [MaxLength(2000)]
    public string Content { get; set; } = string.Empty;

    public DateTime SentAtUtc { get; set; } = DateTime.UtcNow;

    /// <summary>Null until the recipient calls MarkRead.</summary>
    public DateTime? ReadAtUtc { get; set; }
}
