using FixoApi.Data;
using FixoApi.Email;
using FixoApi.Options;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace FixoApi.Services;

public interface INotificationService
{
    /// <summary>
    /// P8-06: push-first fan-out with email fallback. Sends FCM to every
    /// registered device token; when the user has no tokens (push disabled),
    /// all pushes fail, or <paramref name="critical"/> is set, also sends an
    /// email when an address is available. Notification failures never throw —
    /// callers must not fail a job transition because a push or mail server
    /// is down.
    /// </summary>
    Task SendToUserAsync(
        string userId,
        string title,
        string body,
        Dictionary<string, string>? data = null,
        bool critical = false,
        string? emailSubject = null,
        string? emailBody = null,
        CancellationToken ct = default);

    /// <summary>
    /// E5 structured variant (§4.2 of EMAIL-TEMPLATE-REVISION-PLAN): the email
    /// fallback renders through the CriticalNotice template with sections and
    /// a CTA instead of pre-flattened strings. Push behaviour identical.
    /// </summary>
    Task SendToUserAsync(
        string userId,
        string title,
        string body,
        Dictionary<string, string>? data,
        CriticalNoticeModel emailNotice,
        bool critical = false,
        CancellationToken ct = default);

    /// <summary>
    /// Push-only fan-out to every device the user has registered. Per-token
    /// failures never abort the remaining tokens; tokens FCM reports as
    /// unregistered are deleted. Returns true when at least one push was sent.
    /// This replaces the hand-rolled DeviceTokens loops (plan 09, N1.5).
    /// Call it after your own SaveChanges: stale-token cleanup saves the shared context.
    /// </summary>
    Task<bool> SendPushToUserAsync(
        string userId,
        string title,
        string body,
        Dictionary<string, string>? data = null,
        CancellationToken ct = default);

    /// <summary>
    /// Policy-driven notification: <see cref="NotificationPolicy"/> decides push
    /// and email for <paramref name="eventKey"/> (Always = critical, Fallback =
    /// only when push missed, None = push only). The event key is added to the
    /// push data as <c>type</c>. Email renders through the design-system
    /// CriticalNotice template; pass <paramref name="emailNotice"/> for structured
    /// sections, otherwise one is built from title and body. Never throws.
    /// </summary>
    Task NotifyAsync(
        string eventKey,
        string userId,
        string title,
        string body,
        Dictionary<string, string>? data = null,
        CriticalNoticeModel? emailNotice = null,
        CancellationToken ct = default);

    /// <summary>
    /// Plan 10 (Q7.7): policy-driven batch notification to many users (loads
    /// tokens and emails in one batch instead of N round-trips, still respects
    /// push + email-fallback rules per user).
    /// </summary>
    async Task NotifyManyAsync(
        string eventKey,
        IReadOnlyCollection<string> userIds,
        string title,
        string body,
        Dictionary<string, string>? data = null,
        CriticalNoticeModel? emailNotice = null,
        CancellationToken ct = default)
    {
        foreach (var uid in userIds)
            await NotifyAsync(eventKey, uid, title, body, data, emailNotice, ct);
    }

    /// <summary>
    /// Alert the admin team (plan 09 §3.2). Deduplicated per event + entity,
    /// resolved to active staff by <see cref="IStaffRecipientResolver"/>, and
    /// emailed through the StaffAlert template. Never throws.
    /// </summary>
    Task SendToStaffAsync(StaffAlert alert, CancellationToken ct = default);
}

/// <summary>Critical notification kinds (P8-06) — these always get the email fallback.</summary>
public static class CriticalNotificationTypes
{
    public const string RefundProcessed = "refund_processed";
    public const string AccountSuspended = "account_suspended";
    public const string JobCancelled = "job_cancelled";
    public const string JobExpired = "job_expired";
}

public class NotificationService : INotificationService
{
    private readonly FixoDbContext _db;
    private readonly IPushSender _push;
    private readonly IEmailSender _email;
    private readonly IStaffRecipientResolver _staff;
    private readonly INotificationDeduplicator _dedup;
    private readonly BrandOptions _brand;
    private readonly ILogger<NotificationService> _logger;

    public NotificationService(
        FixoDbContext db,
        IPushSender push,
        IEmailSender email,
        IStaffRecipientResolver staff,
        INotificationDeduplicator dedup,
        IOptions<BrandOptions> brand,
        ILogger<NotificationService> logger)
    {
        _db = db;
        _push = push;
        _email = email;
        _staff = staff;
        _dedup = dedup;
        _brand = brand.Value;
        _logger = logger;
    }

    public async Task SendToUserAsync(
        string userId,
        string title,
        string body,
        Dictionary<string, string>? data = null,
        bool critical = false,
        string? emailSubject = null,
        string? emailBody = null,
        CancellationToken ct = default)
    {
        var (tokens, email) = await LoadTargetsAsync(userId, ct);

        var pushOk = await SendPushAsync(userId, tokens, title, body, data);

        // Fallback: no tokens (push disabled), all pushes failed, or critical event.
        if ((!pushOk || critical) && !string.IsNullOrWhiteSpace(email))
        {
            try
            {
                await _email.SendCriticalAsync(
                    email!, emailSubject ?? title, emailBody ?? body);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Fallback email to {Email} failed.", email);
            }
        }
    }

    public async Task SendToUserAsync(
        string userId,
        string title,
        string body,
        Dictionary<string, string>? data,
        CriticalNoticeModel emailNotice,
        bool critical = false,
        CancellationToken ct = default)
    {
        var (tokens, email) = await LoadTargetsAsync(userId, ct);

        var pushOk = await SendPushAsync(userId, tokens, title, body, data);

        if ((!pushOk || critical) && !string.IsNullOrWhiteSpace(email))
        {
            try
            {
                await _email.SendCriticalNoticeAsync(email!, emailNotice);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Fallback email to {Email} failed.", email);
            }
        }
    }

    private async Task<(List<string> Tokens, string? Email)> LoadTargetsAsync(string userId, CancellationToken ct)
    {
        var tokens = new List<string>();
        string? email = null;
        try
        {
            tokens = await _db.DeviceTokens
                .Where(dt => dt.UserId == userId)
                .Select(dt => dt.Token)
                .ToListAsync(ct);
            email = await _db.Users
                .Where(u => u.Id == userId)
                .Select(u => u.Email)
                .FirstOrDefaultAsync(ct);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not load tokens/email for user {UserId}.", userId);
        }
        return (tokens, email);
    }

    public async Task<bool> SendPushToUserAsync(
        string userId,
        string title,
        string body,
        Dictionary<string, string>? data = null,
        CancellationToken ct = default)
    {
        var (tokens, _) = await LoadTargetsAsync(userId, ct);
        return await SendPushAsync(userId, tokens, title, body, data);
    }

    public async Task NotifyAsync(
        string eventKey,
        string userId,
        string title,
        string body,
        Dictionary<string, string>? data = null,
        CriticalNoticeModel? emailNotice = null,
        CancellationToken ct = default)
    {
        try
        {
            if (!NotificationPolicy.TryGet(eventKey, out var def))
            {
                _logger.LogWarning("Notification skipped: unknown event '{EventKey}'.", eventKey);
                return;
            }

            var payload = data is null
                ? new Dictionary<string, string>()
                : new Dictionary<string, string>(data);
            payload.TryAdd("type", def.Key);

            var (tokens, email) = await LoadTargetsAsync(userId, ct);

            var pushOk = def.Push && await SendPushAsync(userId, tokens, title, body, payload);

            var sendEmail = def.Email switch
            {
                EmailPolicy.Always => true,
                EmailPolicy.Fallback => !pushOk,
                _ => false,
            };
            if (!sendEmail || string.IsNullOrWhiteSpace(email)) return;

            try
            {
                await _email.SendCriticalNoticeAsync(email!, emailNotice ?? DefaultNotice(title, body));
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Email for event {EventKey} to {Email} failed.", def.Key, email);
            }
        }
        catch (Exception ex)
        {
            // Notifications must never fail the business transition that raised them.
            _logger.LogWarning(ex, "Notification {EventKey} for user {UserId} failed.", eventKey, userId);
        }
    }

    public async Task NotifyManyAsync(
        string eventKey,
        IReadOnlyCollection<string> userIds,
        string title,
        string body,
        Dictionary<string, string>? data = null,
        CriticalNoticeModel? emailNotice = null,
        CancellationToken ct = default)
    {
        if (userIds.Count == 0) return;
        try
        {
            if (!NotificationPolicy.TryGet(eventKey, out var def))
            {
                _logger.LogWarning("Batch notification skipped: unknown event '{EventKey}'.", eventKey);
                return;
            }

            var payload = data is null
                ? new Dictionary<string, string>()
                : new Dictionary<string, string>(data);
            payload.TryAdd("type", def.Key);

            var distinctIds = userIds.Distinct().ToList();
            var (tokensByUser, emailsByUser) = await LoadTargetsBatchAsync(distinctIds, ct);

            var notice = emailNotice ?? DefaultNotice(title, body);

            foreach (var uid in distinctIds)
            {
                ct.ThrowIfCancellationRequested();
                var tokens = tokensByUser.TryGetValue(uid, out var list) ? list : (IReadOnlyList<string>)Array.Empty<string>();
                var pushOk = def.Push && await SendPushAsync(uid, tokens, title, body, payload);

                var sendEmail = def.Email switch
                {
                    EmailPolicy.Always => true,
                    EmailPolicy.Fallback => !pushOk,
                    _ => false,
                };
                if (!sendEmail) continue;

                if (!emailsByUser.TryGetValue(uid, out var email) || string.IsNullOrWhiteSpace(email))
                    continue;

                try
                {
                    await _email.SendCriticalNoticeAsync(email, notice);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Batch email for event {EventKey} to {Email} failed.", def.Key, email);
                }
            }
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            _logger.LogWarning(ex, "Batch notification {EventKey} failed.", eventKey);
        }
    }

    private async Task<(Dictionary<string, List<string>> Tokens, Dictionary<string, string?> Emails)>
        LoadTargetsBatchAsync(IReadOnlyCollection<string> userIds, CancellationToken ct)
    {
        var tokensByUser = new Dictionary<string, List<string>>();
        var emailsByUser = new Dictionary<string, string?>();
        try
        {
            var tokenRows = await _db.DeviceTokens
                .AsNoTracking()
                .Where(dt => userIds.Contains(dt.UserId))
                .Select(dt => new { dt.UserId, dt.Token })
                .ToListAsync(ct);

            foreach (var row in tokenRows)
            {
                if (!tokensByUser.TryGetValue(row.UserId, out var list))
                {
                    list = new List<string>();
                    tokensByUser[row.UserId] = list;
                }
                list.Add(row.Token);
            }

            emailsByUser = await _db.Users
                .AsNoTracking()
                .Where(u => userIds.Contains(u.Id))
                .Select(u => new { u.Id, u.Email })
                .ToDictionaryAsync(u => u.Id, u => u.Email, ct);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not batch-load tokens/emails for {Count} user(s).", userIds.Count);
        }
        return (tokensByUser, emailsByUser);
    }

    public async Task SendToStaffAsync(StaffAlert alert, CancellationToken ct = default)
    {
        try
        {
            if (!NotificationPolicy.TryGet(alert.EventKey, out var def) || !def.IsStaffAlert)
            {
                _logger.LogWarning("Staff alert skipped: '{EventKey}' is not a staff event.", alert.EventKey);
                return;
            }

            if (!_dedup.TryAcquire(alert.DedupKey, alert.DedupWindow ?? StaffAlert.DefaultDedupWindow))
            {
                _logger.LogDebug("Staff alert {DedupKey} suppressed as a duplicate.", alert.DedupKey);
                return;
            }

            var recipients = await _staff.GetRecipientsAsync(ct);
            if (recipients.Count == 0)
            {
                _logger.LogWarning("Staff alert {DedupKey} has no active staff recipients.", alert.DedupKey);
                return;
            }

            try
            {
                var now = DateTime.UtcNow;
                var (entityType, entityId) = SplitEntityKey(alert.EntityKey);
                var title = Truncate(alert.Heading, 200);
                var body = Truncate(alert.Body, 1000);
                var rows = recipients.Select(r => new Models.StaffNotification
                {
                    UserId = r.UserId,
                    Type = Truncate(alert.EventKey, 64),
                    EntityType = Truncate(entityType, 64),
                    EntityId = Truncate(entityId, 128),
                    Title = title,
                    Body = body,
                    AdminPath = alert.AdminPath is null ? null : Truncate(alert.AdminPath, 256),
                    CreatedUtc = now,
                });
                _db.StaffNotifications.AddRange(rows);
                await _db.SaveChangesAsync(ct);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Staff alert {DedupKey} persistence failed.", alert.DedupKey);
            }

            var model = new StaffAlertModel
            {
                Heading = alert.Heading,
                Body = alert.Body,
                Rows = alert.Rows ?? [],
                AdminUrl = WithBaseUrl(alert.AdminPath),
                Brand = _brand,
            };

            foreach (var recipient in recipients)
            {
                try
                {
                    await _email.SendStaffAlertAsync(recipient.Email, model, alert.DedupKey);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Staff alert {DedupKey} email to {Email} failed.", alert.DedupKey, recipient.Email);
                }

                if (def.Push)
                {
                    await SendPushToUserAsync(
                        recipient.UserId, alert.Heading, alert.Body,
                        new Dictionary<string, string> { ["type"] = def.Key }, ct);
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Staff alert {EventKey}/{EntityKey} failed.", alert.EventKey, alert.EntityKey);
        }
    }

    private CriticalNoticeModel DefaultNotice(string title, string body) => new()
    {
        Heading = title,
        Preheader = body.Length <= 110 ? body : null,
        Sections = [new EmailSection("What's happening", body)],
        Brand = _brand,
    };

    private string? WithBaseUrl(string? path)
    {
        if (string.IsNullOrWhiteSpace(_brand.FrontendBaseUrl) || string.IsNullOrWhiteSpace(path)) return null;
        return _brand.FrontendBaseUrl.TrimEnd('/') + path;
    }

    private static (string EntityType, string EntityId) SplitEntityKey(string entityKey)
    {
        var idx = entityKey.IndexOf(':');
        if (idx <= 0 || idx >= entityKey.Length - 1)
            return ("entity", entityKey);
        return (entityKey[..idx], entityKey[(idx + 1)..]);
    }

    private static string Truncate(string value, int maxLength) =>
        value.Length <= maxLength ? value : value[..maxLength];

    /// <summary>
    /// Sends to every token (one failure never aborts the rest) and removes tokens
    /// FCM reports as unregistered. Returns true when at least one push landed.
    /// </summary>
    private async Task<bool> SendPushAsync(
        string userId, IReadOnlyList<string> tokens, string title, string body,
        Dictionary<string, string>? data)
    {
        var pushOk = false;
        var stale = new List<string>();

        foreach (var token in tokens)
        {
            try
            {
                switch (await _push.TrySendAsync(token, title, body, data))
                {
                    case PushSendOutcome.Sent:
                        pushOk = true;
                        break;
                    case PushSendOutcome.StaleToken:
                        stale.Add(token);
                        break;
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "FCM push to token for user {UserId} failed.", userId);
            }
        }

        if (stale.Count > 0) await RemoveStaleTokensAsync(userId, stale);
        return pushOk;
    }

    private async Task RemoveStaleTokensAsync(string userId, List<string> stale)
    {
        try
        {
            var rows = await _db.DeviceTokens
                .Where(dt => dt.UserId == userId && stale.Contains(dt.Token))
                .ToListAsync();
            if (rows.Count == 0) return;

            _db.DeviceTokens.RemoveRange(rows);
            await _db.SaveChangesAsync();
            _logger.LogInformation("Removed {Count} stale device token(s) for user {UserId}.", rows.Count, userId);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not remove stale device tokens for user {UserId}.", userId);
        }
    }
}
