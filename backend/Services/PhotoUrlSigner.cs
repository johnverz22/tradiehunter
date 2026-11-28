namespace FixoApi.Services;

/// <summary>
/// Issues short-lived, per-viewer, per-blob signed read URLs for job photos
/// (QA plan §4).
///
/// A URL is only ever issued after the caller has verified the viewer is
/// authorised to see that job's photos; the signer itself carries no
/// authorisation logic. TTL is 30 minutes (configurable via
/// "Photos:SasTtlMinutes").
///
/// Contract: callers replace every hard-coded "/api/photos/{blobKey}" string
/// with an await of this method so the resulting DTO always contains an
/// absolute, authenticated URL.
/// </summary>
public interface IPhotoUrlSigner
{
    /// <summary>
    /// Returns an absolute, time-limited signed URL for the given blob key
    /// in the photos container.
    /// </summary>
    Task<string> SignAsync(string blobKey);
}

/// <inheritdoc />
public class PhotoUrlSigner : IPhotoUrlSigner
{
    private readonly IBlobStorageService _blob;
    private readonly TimeSpan _ttl;

    public PhotoUrlSigner(IBlobStorageService blob, IConfiguration config)
    {
        _blob = blob;
        var minutes = config.GetValue<int>("Photos:SasTtlMinutes", 30);
        _ttl = TimeSpan.FromMinutes(minutes);
    }

    /// <inheritdoc />
    public async Task<string> SignAsync(string blobKey)
    {
        // Passes null for container so IBlobStorageService uses its default
        // photos container (th-photos / configured override).
        var uri = await _blob.GetReadSasUriAsync(blobKey, container: null, validFor: _ttl);
        return uri.ToString();
    }
}
