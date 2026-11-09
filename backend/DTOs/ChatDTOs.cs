namespace FixoApi.DTOs;

// ── Chat DTOs ─────────────────────────────────────────────────────────────────

/// <summary>Chat message returned by REST history and broadcast via SignalR.</summary>
public class ChatMessageDto
{
    public int Id { get; set; }
    public int JobId { get; set; }
    public string SenderId { get; set; } = string.Empty;

    /// <summary>Display name of the sender (for the client bubble header).</summary>
    public string SenderName { get; set; } = string.Empty;

    public string Content { get; set; } = string.Empty;
    public DateTime SentAtUtc { get; set; }
    public DateTime? ReadAtUtc { get; set; }
}

/// <summary>
/// Paginated response from GET /api/jobs/{id}/messages.
/// Cursor-based: supply the smallest Id from the current page as BeforeId
/// on the next request to scroll backwards in history.
/// </summary>
public class ChatHistoryResponse
{
    public List<ChatMessageDto> Messages { get; set; } = new();

    /// <summary>True when there are older messages available.</summary>
    public bool HasMore { get; set; }

    /// <summary>
    /// The Id of the oldest message in this page.
    /// Pass this as BeforeId on the next request to load earlier messages.
    /// </summary>
    public int? OldestId { get; set; }
}

/// <summary>Request body for POST /api/jobs/{id}/messages (REST send, optional).</summary>
public class SendMessageRequest
{
    public string Content { get; set; } = string.Empty;
}

/// <summary>
/// One row of GET /api/chat/conversations — a two-party job thread summary.
/// Participant-first: the other party's name leads, the job is the subtitle.
/// Preview and unread state are always real — null when there are no messages.
/// </summary>
public class ConversationSummaryDto
{
    public int JobId { get; set; }
    public string JobTitle { get; set; } = string.Empty;

    /// <summary>Job status enum name (e.g. "Booked") for the status tag.</summary>
    public string Status { get; set; } = string.Empty;

    /// <summary>The counterparty's user id (the matched tradie or the homeowner).</summary>
    public string OtherUserId { get; set; } = string.Empty;

    /// <summary>The counterparty's first name; empty when the account was removed.</summary>
    public string OtherFirstName { get; set; } = string.Empty;

    /// <summary>Content of the newest message; null when the thread is empty.</summary>
    public string? LastMessageContent { get; set; }

    /// <summary>True when the requesting user sent the newest message ("You: …" preview).</summary>
    public bool LastMessageSentByMe { get; set; }

    public DateTime? LastMessageSentAtUtc { get; set; }

    /// <summary>Messages from the other party with no ReadAtUtc — never estimated.</summary>
    public int UnreadCount { get; set; }
}
