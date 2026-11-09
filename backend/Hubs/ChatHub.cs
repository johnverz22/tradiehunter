using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using FixoApi.DTOs;
using FixoApi.Services;
using StackExchange.Redis;

namespace FixoApi.Hubs;

/// <summary>
/// SignalR hub for real-time chat within a job context (M3-02).
/// Registered at /hubs/chat.
///
/// Client → Server methods:
///   • JoinJob(jobId)                   — subscribe to a job's chat group (auth check)
///   • SendMessage(jobId, content)      — persist + broadcast to job group
///   • MarkRead(jobId, messageId)       — set ReadAtUtc on a message
///
/// Server → Client methods:
///   • NewChatMessage(ChatMessageDto)   — broadcast to job group after send
/// </summary>
[Authorize]
public class ChatHub : Hub
{
    private readonly IChatService _chatService;
    private readonly IConnectionMultiplexer? _redis;
    private readonly ILogger<ChatHub> _logger;

    public ChatHub(
        IChatService chatService,
        ILogger<ChatHub> logger,
        IConnectionMultiplexer? redis = null)
    {
        _chatService = chatService;
        _logger      = logger;
        _redis       = redis;
    }

    /// <summary>
    /// Client calls this once it opens the chat screen.
    /// Validates participation before adding to the hub group.
    /// </summary>
    public async Task JoinJob(string jobId)
    {
        if (!int.TryParse(jobId, out var id)) return;

        var userId = Context.UserIdentifier;
        if (userId == null) return;

        if (!await _chatService.IsParticipantAsync(id, userId))
        {
            _logger.LogWarning("Unauthorised JoinJob attempt: user={User} job={Job}", userId, id);
            throw new HubException("Not authorized to join this job chat.");
        }

        await Groups.AddToGroupAsync(Context.ConnectionId, GroupName(id));

        // Track online presence in Redis for the FCM offline-push gate.
        await SetOnlineAsync(id, userId, online: true);

        _logger.LogInformation("User {User} joined chat group for job {Job}", userId, id);
    }

    /// <summary>
    /// Client calls this when it leaves the chat screen (or disconnects).
    /// </summary>
    public async Task LeaveJob(string jobId)
    {
        if (!int.TryParse(jobId, out var id)) return;

        await Groups.RemoveFromGroupAsync(Context.ConnectionId, GroupName(id));

        var userId = Context.UserIdentifier;
        if (userId != null)
            await SetOnlineAsync(id, userId, online: false);
    }

    /// <summary>
    /// Persist the message and broadcast to all job-group members.
    /// Content is trimmed and capped at 2000 chars server-side.
    /// Throws HubException when the job's chat is closed (P5-08).
    /// </summary>
    public async Task SendMessage(string jobId, string content)
    {
        if (!int.TryParse(jobId, out var id)) return;

        var userId = Context.UserIdentifier;
        if (userId == null) return;

        if (!await _chatService.IsParticipantAsync(id, userId))
        {
            throw new HubException("Not authorized to send messages to this job.");
        }

        // P5-08: Block new messages when the job is Completed or Cancelled.
        if (!await _chatService.IsChatOpenAsync(id))
        {
            throw new HubException("Chat is closed for this job.");
        }

        content = content.Trim();
        if (string.IsNullOrEmpty(content)) return;
        if (content.Length > 2000) content = content[..2000];

        // Persist + broadcast (ChatService handles both).
        await _chatService.SaveMessageAsync(id, userId, content);
    }

    /// <summary>
    /// Mark a message as read. Only the recipient (non-sender) may call this.
    /// </summary>
    public async Task MarkRead(string jobId, int messageId)
    {
        if (!int.TryParse(jobId, out var id)) return;

        var userId = Context.UserIdentifier;
        if (userId == null) return;

        await _chatService.MarkReadAsync(id, messageId, userId);
    }

    // ── Hub lifecycle ─────────────────────────────────────────────────────────

    public override async Task OnConnectedAsync()
    {
        _logger.LogInformation("ChatHub connected: {Conn} user={User}",
            Context.ConnectionId, Context.UserIdentifier);
        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        // Redis presence cleanup is job-scoped, so we can't clear here without knowing
        // which jobs the user was in. The LeaveJob call handles it for clean disconnects;
        // stale presence keys expire via TTL in ChatService.
        _logger.LogInformation("ChatHub disconnected: {Conn}", Context.ConnectionId);
        await base.OnDisconnectedAsync(exception);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    public static string GroupName(int jobId) => $"chat-{jobId}";
    public static string GroupName(string jobId) => $"chat-{jobId}";

    /// <summary>Redis set key for tracking which users are online in a job chat.</summary>
    public static string OnlineSetKey(int jobId) => $"chat:online:{jobId}";

    private async Task SetOnlineAsync(int jobId, string userId, bool online)
    {
        if (_redis == null) return;
        try
        {
            var db = _redis.GetDatabase();
            var key = OnlineSetKey(jobId);
            if (online)
                await db.SetAddAsync(key, userId);
            else
                await db.SetRemoveAsync(key, userId);

            // Expire the presence set after 24 h to avoid stale keys.
            await db.KeyExpireAsync(key, TimeSpan.FromHours(24));
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Redis presence update failed for job {Job} user {User}", jobId, userId);
        }
    }
}
