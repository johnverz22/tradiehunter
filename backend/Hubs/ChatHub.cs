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
    /// Refreshes the connection's presence heartbeat for a joined job chat (~30-60 s cadence).
    /// </summary>
    public async Task PingChat(string jobId)
    {
        if (!int.TryParse(jobId, out var id)) return;
        var userId = Context.UserIdentifier;
        if (userId == null) return;

        await SetOnlineAsync(id, userId, online: true);
    }

    /// <summary>
    /// Persist the message, broadcast to all job-group members, and return the
    /// persisted DTO as a server ack so the sender confirms its optimistic row.
    /// Content is trimmed and capped at 2000 chars server-side.
    /// Throws HubException when the job's chat is closed (P5-08).
    /// </summary>
    public async Task<ChatMessageDto?> SendMessage(string jobId, string content)
    {
        if (!int.TryParse(jobId, out var id)) return null;

        var userId = Context.UserIdentifier;
        if (userId == null) return null;

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
        if (string.IsNullOrEmpty(content)) return null;
        if (content.Length > 2000) content = content[..2000];

        // Persist + broadcast (ChatService handles both) and return ack.
        return await _chatService.SaveMessageAsync(id, userId, content);
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
        await ClearConnectionPresenceAsync(Context.ConnectionId);
        _logger.LogInformation("ChatHub disconnected: {Conn}", Context.ConnectionId);
        await base.OnDisconnectedAsync(exception);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    public static string GroupName(int jobId) => $"chat-{jobId}";
    public static string GroupName(string jobId) => $"chat-{jobId}";

    /// <summary>Redis sorted-set key for tracking live connections in a job chat.</summary>
    public static string OnlineSetKey(int jobId) => $"chat:online:{jobId}";

    /// <summary>Member format in <see cref="OnlineSetKey"/>: "{userId}:{connectionId}".</summary>
    public static string OnlineMember(string userId, string connectionId) => $"{userId}:{connectionId}";

    private static string ConnUserKey(string connectionId) => $"chat:conn:user:{connectionId}";
    private static string ConnJobsKey(string connectionId) => $"chat:conn:jobs:{connectionId}";

    private static readonly TimeSpan PresenceWindowTtl = TimeSpan.FromHours(2);

    private async Task SetOnlineAsync(int jobId, string userId, bool online)
    {
        if (_redis == null) return;
        try
        {
            var db = _redis.GetDatabase();
            var key = OnlineSetKey(jobId);
            var member = OnlineMember(userId, Context.ConnectionId);
            var connUserKey = ConnUserKey(Context.ConnectionId);
            var connJobsKey = ConnJobsKey(Context.ConnectionId);

            if (online)
            {
                var nowUnix = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
                await db.SortedSetAddAsync(key, member, nowUnix);
                await db.KeyExpireAsync(key, PresenceWindowTtl);

                await db.StringSetAsync(connUserKey, userId, PresenceWindowTtl);
                await db.SetAddAsync(connJobsKey, jobId.ToString());
                await db.KeyExpireAsync(connJobsKey, PresenceWindowTtl);
            }
            else
            {
                await db.SortedSetRemoveAsync(key, member);
                await db.SetRemoveAsync(connJobsKey, jobId.ToString());
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Redis presence update failed for job {Job} user {User}", jobId, userId);
        }
    }

    private async Task ClearConnectionPresenceAsync(string connectionId)
    {
        if (_redis == null) return;
        try
        {
            var db = _redis.GetDatabase();
            var connUserKey = ConnUserKey(connectionId);
            var connJobsKey = ConnJobsKey(connectionId);

            var userId = await db.StringGetAsync(connUserKey);
            var jobIds = await db.SetMembersAsync(connJobsKey);

            if (!userId.IsNullOrEmpty && jobIds.Length > 0)
            {
                var uid = userId.ToString();
                var member = OnlineMember(uid, connectionId);
                foreach (var j in jobIds)
                {
                    if (int.TryParse(j.ToString(), out var jobId))
                    {
                        await db.SortedSetRemoveAsync(OnlineSetKey(jobId), member);
                    }
                }
            }

            await db.KeyDeleteAsync(new RedisKey[] { connUserKey, connJobsKey });
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Redis disconnect cleanup failed for connection {Conn}", connectionId);
        }
    }
}
