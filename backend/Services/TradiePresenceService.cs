using FixoApi.Data;
using Microsoft.EntityFrameworkCore;
using StackExchange.Redis;

namespace FixoApi.Services;

public readonly record struct TradiePresenceStatus(bool Online, DateTime? LastSeenAtUtc);

/// <summary>
/// Tracks live tradie reachability (QA plan §1).
/// Splits intent (<c>TradieProfile.IsAvailable</c>) from presence
/// (active JobHub connection in Redis or <c>LastSeenAtUtc</c> within grace).
/// </summary>
public interface ITradiePresenceService
{
    Task RecordConnectAsync(string userId, string connectionId, CancellationToken ct = default);
    Task RecordHeartbeatAsync(string userId, string connectionId, CancellationToken ct = default);
    Task RecordDisconnectAsync(string userId, string connectionId, CancellationToken ct = default);
    Task SetOfflineAsync(string userId, CancellationToken ct = default);

    Task<bool> IsOnlineAsync(string userId, CancellationToken ct = default);
    Task<HashSet<string>> FilterOnlineAsync(IEnumerable<string> userIds, CancellationToken ct = default);
    Task<Dictionary<string, TradiePresenceStatus>> GetPresenceAsync(
        IEnumerable<string> userIds, CancellationToken ct = default);
}

public class TradiePresenceService : ITradiePresenceService
{
    private static readonly TimeSpan PresenceKeyTtl = TimeSpan.FromSeconds(90);

    private readonly FixoDbContext _context;
    private readonly IConnectionMultiplexer? _redis;
    private readonly IPlatformSettings? _settings;
    private readonly ILogger<TradiePresenceService> _logger;

    public TradiePresenceService(
        FixoDbContext context,
        ILogger<TradiePresenceService> logger,
        IConnectionMultiplexer? redis = null,
        IPlatformSettings? settings = null)
    {
        _context = context;
        _logger = logger;
        _redis = redis;
        _settings = settings;
    }

    public static string PresenceKey(string userId) => $"presence:tradie:{userId}";

    /// <summary>
    /// Pure effective-online rule (QA §1):
    /// <c>IsAvailable &amp;&amp; (hasActiveConnection || LastSeenAtUtc &gt; now - graceMinutes)</c>.
    /// </summary>
    public static bool IsEffectivelyOnline(
        bool isAvailable,
        bool hasActiveConnection,
        DateTime? lastSeenAtUtc,
        DateTime nowUtc,
        int graceMinutes)
    {
        if (!isAvailable) return false;
        if (hasActiveConnection) return true;
        if (!lastSeenAtUtc.HasValue) return false;
        return lastSeenAtUtc.Value > nowUtc.AddMinutes(-graceMinutes);
    }

    public async Task RecordConnectAsync(string userId, string connectionId, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(userId) || string.IsNullOrWhiteSpace(connectionId)) return;

        await AddRedisConnectionAsync(userId, connectionId);
        await TouchLastSeenAsync(userId, DateTime.UtcNow, ct);
    }

    public async Task RecordHeartbeatAsync(string userId, string connectionId, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(userId) || string.IsNullOrWhiteSpace(connectionId)) return;

        await AddRedisConnectionAsync(userId, connectionId);
    }

    public async Task RecordDisconnectAsync(string userId, string connectionId, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(userId) || string.IsNullOrWhiteSpace(connectionId)) return;

        var remaining = await RemoveRedisConnectionAsync(userId, connectionId);
        if (remaining == 0)
        {
            await TouchLastSeenAsync(userId, DateTime.UtcNow, ct);
        }
    }

    public async Task SetOfflineAsync(string userId, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(userId)) return;

        if (_redis != null)
        {
            try
            {
                await _redis.GetDatabase().KeyDeleteAsync(PresenceKey(userId));
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Redis presence clear failed for tradie {UserId}", userId);
            }
        }

        await TouchLastSeenAsync(userId, null, ct);
    }

    public async Task<bool> IsOnlineAsync(string userId, CancellationToken ct = default)
    {
        var map = await GetPresenceAsync([userId], ct);
        return map.TryGetValue(userId, out var status) && status.Online;
    }

    public async Task<HashSet<string>> FilterOnlineAsync(
        IEnumerable<string> userIds, CancellationToken ct = default)
    {
        var map = await GetPresenceAsync(userIds, ct);
        return map.Where(kv => kv.Value.Online).Select(kv => kv.Key).ToHashSet();
    }

    public async Task<Dictionary<string, TradiePresenceStatus>> GetPresenceAsync(
        IEnumerable<string> userIds, CancellationToken ct = default)
    {
        var ids = userIds.Where(id => !string.IsNullOrWhiteSpace(id)).Distinct().ToList();
        var result = new Dictionary<string, TradiePresenceStatus>(ids.Count);
        if (ids.Count == 0) return result;

        var graceMinutes = _settings != null
            ? await _settings.GetPresenceGraceMinutesAsync(ct)
            : PlatformSettingKeys.DefaultPresenceGraceMinutes;

        var profiles = await _context.TradieProfiles
            .AsNoTracking()
            .Where(t => ids.Contains(t.UserId))
            .Select(t => new { t.UserId, t.IsAvailable, t.LastSeenAtUtc })
            .ToDictionaryAsync(t => t.UserId, ct);

        var activeConnections = await GetActiveConnectionFlagsAsync(ids);
        var nowUtc = DateTime.UtcNow;

        foreach (var id in ids)
        {
            if (!profiles.TryGetValue(id, out var p))
            {
                result[id] = new TradiePresenceStatus(false, null);
                continue;
            }

            var hasConn = activeConnections.Contains(id);
            var online = IsEffectivelyOnline(p.IsAvailable, hasConn, p.LastSeenAtUtc, nowUtc, graceMinutes);
            result[id] = new TradiePresenceStatus(online, p.LastSeenAtUtc);
        }

        return result;
    }

    private async Task AddRedisConnectionAsync(string userId, string connectionId)
    {
        if (_redis == null) return;
        try
        {
            var db = _redis.GetDatabase();
            var key = PresenceKey(userId);
            await db.SetAddAsync(key, connectionId);
            await db.KeyExpireAsync(key, PresenceKeyTtl);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Redis presence update failed for tradie {UserId}", userId);
        }
    }

    private async Task<long> RemoveRedisConnectionAsync(string userId, string connectionId)
    {
        if (_redis == null) return 0;
        try
        {
            var db = _redis.GetDatabase();
            var key = PresenceKey(userId);
            await db.SetRemoveAsync(key, connectionId);
            return await db.SetLengthAsync(key);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Redis presence remove failed for tradie {UserId}", userId);
            return 0;
        }
    }

    private async Task<HashSet<string>> GetActiveConnectionFlagsAsync(List<string> userIds)
    {
        var active = new HashSet<string>();
        if (_redis == null) return active;

        try
        {
            var db = _redis.GetDatabase();
            var tasks = userIds.Select(async id =>
            {
                var len = await db.SetLengthAsync(PresenceKey(id));
                return (id, len > 0);
            });
            foreach (var (id, isOnline) in await Task.WhenAll(tasks))
            {
                if (isOnline) active.Add(id);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Redis presence batch check failed");
        }

        return active;
    }

    private async Task TouchLastSeenAsync(string userId, DateTime? timestampUtc, CancellationToken ct)
    {
        var profile = await _context.TradieProfiles
            .FirstOrDefaultAsync(t => t.UserId == userId, ct);
        if (profile == null) return;

        profile.LastSeenAtUtc = timestampUtc;
        await _context.SaveChangesAsync(ct);
    }
}
