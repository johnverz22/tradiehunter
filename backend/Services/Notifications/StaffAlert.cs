using FixoApi.Email;

namespace FixoApi.Services;

/// <summary>
/// One alert raised for the admin team. <see cref="EventKey"/> must be a
/// staff event in <see cref="NotificationPolicy"/>; <see cref="EntityKey"/>
/// (e.g. <c>payment:42</c>) plus the event key form the dedup key.
/// </summary>
public sealed record StaffAlert(
    string EventKey,
    string EntityKey,
    string Heading,
    string Body,
    IReadOnlyList<EmailSummaryRow>? Rows = null,
    string? AdminPath = null,
    TimeSpan? DedupWindow = null)
{
    /// <summary>Default dedup window: absorbs retries without hiding a genuinely new event.</summary>
    public static readonly TimeSpan DefaultDedupWindow = TimeSpan.FromHours(1);

    public string DedupKey => $"{EventKey}:{EntityKey}";
}

/// <summary>An active staff/superadmin account that can receive alerts.</summary>
public sealed record StaffRecipient(string UserId, string Email, string Name);

/// <summary>Resolves who "staff" is, so callers never query roles themselves.</summary>
public interface IStaffRecipientResolver
{
    /// <summary>
    /// Active, unlocked Staff and Superadmin users with a usable email. Pending
    /// invites (not yet activated) and suspended accounts are excluded.
    /// </summary>
    Task<IReadOnlyList<StaffRecipient>> GetRecipientsAsync(CancellationToken ct = default);
}
