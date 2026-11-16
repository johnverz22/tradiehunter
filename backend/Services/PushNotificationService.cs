using FirebaseAdmin.Messaging;

namespace FixoApi.Services;

/// <summary>
/// Wraps Firebase Cloud Messaging for sending push notifications.
/// FirebaseApp must already be initialised (Program.cs) before this is called.
/// </summary>
public class PushNotificationService
{
    private readonly ILogger<PushNotificationService> _logger;
    private readonly FixoApi.Options.BrandOptions _brand;

    public PushNotificationService(ILogger<PushNotificationService> logger, Microsoft.Extensions.Options.IOptions<FixoApi.Options.BrandOptions> brandOptions)
    {
        _logger = logger;
        _brand = brandOptions.Value;
    }

    /// <summary>Send a push notification to a single device token.</summary>
    public async Task SendAsync(string deviceToken, string title, string body,
        Dictionary<string, string>? data = null)
    {
        var finalTitle = BrandTitle(title);

        var message = new Message
        {
            Fid = deviceToken,
            Notification = new Notification { Title = finalTitle, Body = body },
            Data = data ?? new Dictionary<string, string>(),
            Apns = new ApnsConfig
            {
                Aps = new Aps { Sound = "default" }
            },
            Android = new AndroidConfig
            {
                Priority = Priority.High
            }
        };

        try
        {
            var messageId = await FirebaseMessaging.DefaultInstance.SendAsync(message);
            _logger.LogInformation("FCM message sent: {MessageId}", messageId);
        }
        catch (FirebaseMessagingException ex) when (
            ex.MessagingErrorCode is MessagingErrorCode.Unregistered
                                   or MessagingErrorCode.InvalidArgument)
        {
            // Stale or invalid token — callers should remove it from DeviceTokens
            _logger.LogWarning("FCM send failed (stale token {Token}): {Error}", deviceToken, ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "FCM send failed for token {Token}", deviceToken);
            throw;
        }
    }

    /// <summary>
    /// Send the same notification to multiple device tokens (fan-out, up to 500 per batch).
    /// Returns the list of tokens that were rejected as stale/invalid so callers can clean them up.
    /// </summary>
    public async Task<IReadOnlyList<string>> SendMulticastAsync(
        IEnumerable<string> deviceTokens,
        string title,
        string body,
        Dictionary<string, string>? data = null)
    {
        var tokens = deviceTokens.ToList();
        if (tokens.Count == 0) return Array.Empty<string>();

        var finalTitle = BrandTitle(title);

        var message = new MulticastMessage
        {
            Fids = tokens,
            Notification = new Notification { Title = finalTitle, Body = body },
            Data = data ?? new Dictionary<string, string>(),
            Apns = new ApnsConfig { Aps = new Aps { Sound = "default" } },
            Android = new AndroidConfig { Priority = Priority.High }
        };

        var response = await FirebaseMessaging.DefaultInstance.SendEachForMulticastAsync(message);

        var staleTokens = new List<string>();
        for (int i = 0; i < response.Responses.Count; i++)
        {
            var r = response.Responses[i];
            if (!r.IsSuccess &&
                r.Exception?.MessagingErrorCode is MessagingErrorCode.Unregistered
                                                  or MessagingErrorCode.InvalidArgument)
            {
                staleTokens.Add(tokens[i]);
            }
        }

        _logger.LogInformation(
            "FCM multicast: {Success}/{Total} sent, {Stale} stale tokens",
            response.SuccessCount, tokens.Count, staleTokens.Count);

        return staleTokens;
    }

    /// <summary>
    /// Double-brand guard (EMAIL-TEMPLATE-REVISION-PLAN §4.3): the OS already
    /// labels the app in the tray, so — brand a title only when it does not
    /// start with the brand name (StartsWith, not Contains — a title like
    /// "New TradieHunter job" must not be double-branded) and skip the prefix
    /// on short titles entirely ("Job cancelled" + brand would exceed the
    /// 30-char title rule and duplicate the tray label).
    /// </summary>
    private string BrandTitle(string? title)
    {
        if (string.IsNullOrWhiteSpace(title)) return _brand.AppName;
        if (title.StartsWith(_brand.AppName, StringComparison.OrdinalIgnoreCase)) return title;
        if (title.Length <= 16) return title; // tray already shows the app name
        return $"{_brand.AppName}: {title}";
    }
}
