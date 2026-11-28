using FirebaseAdmin.Messaging;

namespace FixoApi.Services;

/// <summary>Result of one device-token send, so callers can react without catching FCM exceptions.</summary>
public enum PushSendOutcome
{
    Sent,
    /// <summary>FCM says the token is unregistered or invalid — delete it.</summary>
    StaleToken,
    Failed,
}

/// <summary>
/// Single-token push seam used by <see cref="NotificationService"/>. Exists so the
/// fan-out (stale-token cleanup, email fallback) can be unit-tested without FCM.
/// </summary>
public interface IPushSender
{
    Task<PushSendOutcome> TrySendAsync(
        string deviceToken, string title, string body, Dictionary<string, string>? data = null);
}

/// <summary>
/// Wraps Firebase Cloud Messaging for sending push notifications.
/// FirebaseApp must already be initialised (Program.cs) before this is called.
/// </summary>
public class PushNotificationService : IPushSender
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
            Apns = BuildApns(data),
            Android = BuildAndroid(data)
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

    /// <inheritdoc />
    public async Task<PushSendOutcome> TrySendAsync(
        string deviceToken, string title, string body, Dictionary<string, string>? data = null)
    {
        try
        {
            await SendAsync(deviceToken, title, body, data);
            return PushSendOutcome.Sent;
        }
        catch (FirebaseMessagingException ex) when (
            ex.MessagingErrorCode is MessagingErrorCode.Unregistered
                                   or MessagingErrorCode.InvalidArgument)
        {
            return PushSendOutcome.StaleToken; // SendAsync already logged it
        }
        catch
        {
            return PushSendOutcome.Failed; // SendAsync already logged it
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
            Apns = BuildApns(data),
            Android = BuildAndroid(data)
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

    /// <summary>Data key carrying the Android notification channel id (QA plan §3).</summary>
    public const string ChannelKey = "channel";

    /// <summary>Channel for incoming job requests: heads-up, sound, full-screen intent.</summary>
    public const string IncomingRequestsChannel = "incoming_requests";

    /// <summary>
    /// Android config: always high priority; routes to the named channel when the
    /// payload carries <see cref="ChannelKey"/> so the device plays the channel's
    /// sound and can raise a full-screen intent.
    /// </summary>
    public static AndroidConfig BuildAndroid(Dictionary<string, string>? data)
    {
        var android = new AndroidConfig { Priority = Priority.High };
        if (data is not null
            && data.TryGetValue(ChannelKey, out var channel)
            && !string.IsNullOrWhiteSpace(channel))
        {
            android.Notification = new AndroidNotification { ChannelId = channel };
        }
        return android;
    }

    /// <summary>
    /// APNs config: default sound; incoming-request pushes are marked
    /// <c>time-sensitive</c> so iOS can break through Focus modes.
    /// </summary>
    public static ApnsConfig BuildApns(Dictionary<string, string>? data)
    {
        var aps = new Aps { Sound = "default" };
        if (data is not null
            && data.TryGetValue(ChannelKey, out var channel)
            && channel == IncomingRequestsChannel)
        {
            aps.CustomData = new Dictionary<string, object>
            {
                ["interruption-level"] = "time-sensitive",
            };
        }
        return new ApnsConfig { Aps = aps };
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
