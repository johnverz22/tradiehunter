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

/// <summary>Request body for POST /api/jobs/{id}/cancel.</summary>
public class CancelJobRequest
{
    public string Reason { get; set; } = string.Empty;
}

/// <summary>
/// Payload broadcast on the JobHub's JobStatusChanged server → client method.
/// Richer than the original (jobId, status) pair — includes title for push copy.
/// </summary>
public class JobStatusChangedPayload
{
    public int JobId { get; set; }
    public string NewStatus { get; set; } = string.Empty;
    public string JobTitle { get; set; } = string.Empty;
}
