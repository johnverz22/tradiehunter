using FixoApi.Data;
using Microsoft.EntityFrameworkCore;

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
    private readonly PushNotificationService _push;
    private readonly IEmailSender _email;
    private readonly ILogger<NotificationService> _logger;

    public NotificationService(
        FixoDbContext db,
        PushNotificationService push,
        IEmailSender email,
        ILogger<NotificationService> logger)
    {
        _db = db;
        _push = push;
        _email = email;
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

        var pushOk = false;
        foreach (var token in tokens)
        {
            try
            {
                await _push.SendAsync(token, title, body, data);
                pushOk = true;
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "FCM push to token for user {UserId} failed.", userId);
            }
        }

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
}
