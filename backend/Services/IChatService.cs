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
    /// P5-08: Returns true when the job is in an active phase where chat is
    /// permitted (Matched, AwaitingPayment, PaymentReview, Booked, InProgress).
    /// Returns false for Completed, Cancelled, or Disputed.
    /// </summary>
    Task<bool> IsChatOpenAsync(int jobId);

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

    /// <summary>
    /// Thread summaries for the signed-in user's inbox: every job that has a
    /// matched counterparty, with the newest message preview and a real
    /// unread count. Sorted by last activity, newest first.
    /// </summary>
    Task<List<ConversationSummaryDto>> GetConversationsAsync(string userId, int limit = 50);
}
