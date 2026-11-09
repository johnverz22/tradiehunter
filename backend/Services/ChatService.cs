using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Hubs;
using FixoApi.Models;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using StackExchange.Redis;

namespace FixoApi.Services;

/// <summary>
/// Implementation of <see cref="IChatService"/> (M3-02, M3-03, M3-04).
///
/// Responsibilities:
///   • Persist chat messages via EF Core
///   • Broadcast new messages via IHubContext&lt;ChatHub&gt;
///   • Gate FCM push when recipient is offline (tracked via Redis online set)
///   • Rate-limit FCM: max 1 push per 30 s per (job, recipient)
/// </summary>
public class ChatService : IChatService
{
    private readonly FixoDbContext _context;
    private readonly IHubContext<ChatHub> _chatHub;
    private readonly PushNotificationService _push;
    private readonly IConnectionMultiplexer? _redis;
    private readonly ILogger<ChatService> _logger;

    private const int FcmRateLimitSeconds = 30;

    public ChatService(
        FixoDbContext context,
        IHubContext<ChatHub> chatHub,
        PushNotificationService push,
        ILogger<ChatService> logger,
        IConnectionMultiplexer? redis = null)
    {
        _context = context;
        _chatHub  = chatHub;
        _push     = push;
        _logger   = logger;
        _redis    = redis;
    }

    // ── Participant guard ─────────────────────────────────────────────────────

    public async Task<bool> IsParticipantAsync(int jobId, string userId)
    {
        var job = await _context.Jobs
            .AsNoTracking()
            .Where(j => j.Id == jobId)
            .Select(j => new { j.HomeownerId, j.MatchedTradieId })
            .FirstOrDefaultAsync();

        if (job == null) return false;
        return job.HomeownerId == userId || job.MatchedTradieId == userId;
    }

    // ── Chat access guard (P5-08) ─────────────────────────────────────────────

    /// Returns true when the job is in an active state where chat is permitted.
    /// Chat is open for: Matched, AwaitingPayment, PaymentReview, Booked, InProgress.
    /// Chat is locked (read-only) for: Completed, Cancelled, Disputed, Expired.
    public async Task<bool> IsChatOpenAsync(int jobId)
    {
        var status = await _context.Jobs
            .AsNoTracking()
            .Where(j => j.Id == jobId)
            .Select(j => (JobStatus?)j.Status)
            .FirstOrDefaultAsync();

        if (status == null) return false;

        return status is not (JobStatus.Completed or JobStatus.Cancelled or JobStatus.Disputed);
    }

    // ── Save & broadcast ──────────────────────────────────────────────────────

    public async Task<ChatMessageDto> SaveMessageAsync(int jobId, string senderId, string content)
    {
        // P5-08: Reject messages once the job is closed to new chat.
        if (!await IsChatOpenAsync(jobId))
            throw new InvalidOperationException("Chat is closed for this job.");

        var message = new ChatMessage
        {
            JobId     = jobId,
            SenderId  = senderId,
            Content   = content,
            SentAtUtc = DateTime.UtcNow,
        };

        _context.ChatMessages.Add(message);
        await _context.SaveChangesAsync();

        // Eager-load sender name for the DTO.
        var senderName = await _context.Users
            .Where(u => u.Id == senderId)
            .Select(u => u.FullName)
            .FirstOrDefaultAsync() ?? string.Empty;

        var dto = ToDto(message, senderName);

        // Broadcast to all hub clients subscribed to this job's group.
        await _chatHub.Clients
            .Group(ChatHub.GroupName(jobId))
            .SendAsync("NewChatMessage", dto);

        // FCM push to the offline recipient (fire-and-forget).
        _ = SendChatPushAsync(jobId, senderId, content);

        return dto;
    }

    // ── Mark read ─────────────────────────────────────────────────────────────

    public async Task MarkReadAsync(int jobId, int messageId, string readerId)
    {
        var msg = await _context.ChatMessages
            .Where(m => m.Id == messageId && m.JobId == jobId && m.SenderId != readerId)
            .FirstOrDefaultAsync();

        if (msg == null || msg.ReadAtUtc.HasValue) return;

        msg.ReadAtUtc = DateTime.UtcNow;
        await _context.SaveChangesAsync();
    }

    // ── History (cursor pagination) ───────────────────────────────────────────

    public async Task<ChatHistoryResponse> GetHistoryAsync(
        int jobId, string requestingUserId, int? beforeId, int pageSize)
    {
        if (!await IsParticipantAsync(jobId, requestingUserId))
            return new ChatHistoryResponse();

        pageSize = Math.Clamp(pageSize, 1, 50);

        // Build base query: messages for this job, newest first.
        var query = _context.ChatMessages
            .AsNoTracking()
            .Where(m => m.JobId == jobId);

        // Cursor: only messages older than (Id <) the cursor.
        if (beforeId.HasValue)
            query = query.Where(m => m.Id < beforeId.Value);

        var messages = await query
            .OrderByDescending(m => m.SentAtUtc)
            .Take(pageSize + 1)           // +1 to detect HasMore
            .Include(m => m.Sender)
            .ToListAsync();

        var hasMore = messages.Count > pageSize;
        if (hasMore) messages = messages.Take(pageSize).ToList();

        var dtos = messages
            .Select(m => ToDto(m, m.Sender?.FullName ?? string.Empty))
            .ToList();

        return new ChatHistoryResponse
        {
            Messages  = dtos,
            HasMore   = hasMore,
            OldestId  = dtos.Count > 0 ? dtos[^1].Id : null,
        };
    }

    // ── Participant IDs ───────────────────────────────────────────────────────

    public async Task<(string homeownerId, string? tradieId)> GetParticipantIdsAsync(int jobId)
    {
        var job = await _context.Jobs
            .AsNoTracking()
            .Where(j => j.Id == jobId)
            .Select(j => new { j.HomeownerId, j.MatchedTradieId })
            .FirstOrDefaultAsync();

        return job == null ? (string.Empty, null) : (job.HomeownerId, job.MatchedTradieId);
    }

    // ── Conversation summaries (inbox) ─────────────────────────────────────

    /// <inheritdoc />
    public async Task<List<ConversationSummaryDto>> GetConversationsAsync(
        string userId, int limit = 50)
    {
        // Only jobs with a real two-party thread: a matched counterparty must
        // exist, otherwise there is nobody to talk to (fixture-title-only rows).
        var jobs = await _context.Jobs
            .AsNoTracking()
            .Where(j => j.MatchedTradieId != null &&
                        (j.HomeownerId == userId || j.MatchedTradieId == userId))
            .Select(j => new
            {
                j.Id,
                j.Title,
                j.Status,
                j.UpdatedAtUtc,
                OtherId = j.HomeownerId == userId ? j.MatchedTradieId! : j.HomeownerId,
            })
            .ToListAsync();

        if (jobs.Count == 0) return new List<ConversationSummaryDto>();

        var jobIds = jobs.Select(j => j.Id).ToList();

        // Newest message id per job (Ids are sequential = chronological).
        var lastIds = await _context.ChatMessages
            .AsNoTracking()
            .Where(m => jobIds.Contains(m.JobId))
            .GroupBy(m => m.JobId)
            .Select(g => new { JobId = g.Key, MaxId = g.Max(m => m.Id) })
            .ToListAsync();
        var maxIds = lastIds.Select(x => x.MaxId).ToList();
        var lastMessages = await _context.ChatMessages
            .AsNoTracking()
            .Where(m => maxIds.Contains(m.Id))
            .Select(m => new { m.JobId, m.Content, m.SenderId, m.SentAtUtc })
            .ToListAsync();

        // Real unread count: messages from the other party never marked read.
        var unread = await _context.ChatMessages
            .AsNoTracking()
            .Where(m => jobIds.Contains(m.JobId) &&
                        m.SenderId != userId && m.ReadAtUtc == null)
            .GroupBy(m => m.JobId)
            .Select(g => new { JobId = g.Key, Count = g.Count() })
            .ToListAsync();

        var otherIds = jobs.Select(j => j.OtherId).Distinct().ToList();
        var names = await _context.Users
            .AsNoTracking()
            .Where(u => otherIds.Contains(u.Id))
            .Select(u => new { u.Id, u.FirstName })
            .ToListAsync();

        var lastByJob = lastMessages.ToDictionary(m => m.JobId);
        var unreadByJob = unread.ToDictionary(u => u.JobId);
        var nameById = names.ToDictionary(u => u.Id);

        return jobs
            .Select(j =>
            {
                lastByJob.TryGetValue(j.Id, out var last);
                var dto = new ConversationSummaryDto
                {
                    JobId = j.Id,
                    JobTitle = j.Title,
                    Status = j.Status.ToString(),
                    OtherUserId = j.OtherId,
                    OtherFirstName = nameById.TryGetValue(j.OtherId, out var n)
                        ? n.FirstName
                        : string.Empty,
                    LastMessageContent = last?.Content,
                    LastMessageSentByMe = last?.SenderId == userId,
                    LastMessageSentAtUtc = last?.SentAtUtc,
                    UnreadCount = unreadByJob.TryGetValue(j.Id, out var u) ? u.Count : 0,
                };
                return (dto, sortKey: last?.SentAtUtc ?? j.UpdatedAtUtc);
            })
            .OrderByDescending(x => x.sortKey)
            .Take(Math.Clamp(limit, 1, 100))
            .Select(x => x.dto)
            .ToList();
    }

    // ── Private: FCM push for chat ────────────────────────────────────────────

    /// <summary>
    /// Send a FCM push to the offline recipient.
    /// Only fires when the recipient has no active hub connections (tracked via Redis).
    /// Rate-limited to 1 push per 30 s per (jobId, recipientId).
    /// Failures are logged, never thrown.
    /// </summary>
    private async Task SendChatPushAsync(int jobId, string senderId, string content)
    {
        try
        {
            var (homeownerId, tradieId) = await GetParticipantIdsAsync(jobId);
            var recipientId = senderId == homeownerId ? tradieId : homeownerId;
            if (recipientId == null || recipientId == senderId) return;

            // Check online presence via Redis (set by ChatHub on connect/disconnect).
            // If Redis is not available we fall back to always-push to avoid silent failure.
            if (_redis != null)
            {
                var db = _redis.GetDatabase();
                var isOnline = await db.SetContainsAsync(ChatHub.OnlineSetKey(jobId), recipientId);
                if (isOnline)
                {
                    _logger.LogDebug("Chat push skipped — recipient {R} online on job {J}", recipientId, jobId);
                    return;
                }

                // Rate limit: max 1 push per 30 s per (job, recipient).
                var rateLimitKey = $"chat:push:rl:{jobId}:{recipientId}";
                var set = await db.StringSetAsync(rateLimitKey, "1",
                    TimeSpan.FromSeconds(FcmRateLimitSeconds), When.NotExists);
                if (!set)
                {
                    _logger.LogDebug("Chat push rate-limited for job {J} recipient {R}", jobId, recipientId);
                    return;
                }
            }

            var tokens = await _context.DeviceTokens
                .Where(dt => dt.UserId == recipientId)
                .Select(dt => dt.Token)
                .ToListAsync();

            if (tokens.Count == 0) return;

            var preview = content.Length > 100 ? content[..100] + "…" : content;

            var senderName = await _context.Users
                .Where(u => u.Id == senderId)
                .Select(u => u.FullName)
                .FirstOrDefaultAsync() ?? "Someone";

            var staleTokens = await _push.SendMulticastAsync(
                tokens,
                title: senderName,
                body: preview,
                data: new Dictionary<string, string>
                {
                    { "type",  "chat" },
                    { "jobId", jobId.ToString() },
                });

            await CleanStaleTokensAsync(recipientId, staleTokens);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Chat FCM push failed for job {JobId} sender {SenderId}", jobId, senderId);
        }
    }

    private async Task CleanStaleTokensAsync(string userId, IReadOnlyList<string> staleTokens)
    {
        if (staleTokens.Count == 0) return;
        var toRemove = await _context.DeviceTokens
            .Where(dt => dt.UserId == userId && staleTokens.Contains(dt.Token))
            .ToListAsync();
        _context.DeviceTokens.RemoveRange(toRemove);
        await _context.SaveChangesAsync();
    }

    // ── Mapping ───────────────────────────────────────────────────────────────

    private static ChatMessageDto ToDto(ChatMessage m, string senderName) => new()
    {
        Id         = m.Id,
        JobId      = m.JobId,
        SenderId   = m.SenderId,
        SenderName = senderName,
        Content    = m.Content,
        SentAtUtc  = m.SentAtUtc,
        ReadAtUtc  = m.ReadAtUtc,
    };
}
