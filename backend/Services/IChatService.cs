using FixoApi.DTOs;

namespace FixoApi.Services;

/// <summary>
/// Application-layer service for real-time chat within a job context (M3-02, M3-03, M3-04).
/// Hub and controllers must not talk to DbContext directly — use this interface.
/// </summary>
public interface IChatService
{
    /// <summary>
    /// Verify that <paramref name="userId"/> is an authorized participant of
    /// <paramref name="jobId"/> (homeowner or matched tradie).
    /// </summary>
    Task<bool> IsParticipantAsync(int jobId, string userId);

    /// <summary>
    /// Persist a message and return the saved DTO.
    /// Does NOT broadcast — the hub broadcasts after calling this.
    /// </summary>
    Task<ChatMessageDto> SaveMessageAsync(int jobId, string senderId, string content);

    /// <summary>
    /// Mark a specific message as read by the recipient.
    /// </summary>
    Task MarkReadAsync(int jobId, int messageId, string readerId);

    /// <summary>
    /// Cursor-based paginated history for GET /api/jobs/{id}/messages.
    /// Returns messages older than (or equal to) <paramref name="beforeId"/>,
    /// newest first. Pass null to start from the most recent message.
    /// </summary>
    Task<ChatHistoryResponse> GetHistoryAsync(int jobId, string requestingUserId,
        int? beforeId, int pageSize);

    /// <summary>
    /// Returns the user IDs of all participants for a job.
    /// </summary>
    Task<(string homeownerId, string? tradieId)> GetParticipantIdsAsync(int jobId);
}
