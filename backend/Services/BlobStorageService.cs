using Azure;
using Azure.Storage;
using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using Azure.Storage.Sas;

namespace FixoApi.Services;

/// <summary>
/// Blob storage via the Azure SDK, targeting Azurite locally and
/// Azure Blob Storage in production (see docs/ARCHITECTURE.md).
/// Two containers: a photos container (job photos, served via the API)
/// and a private credentials container (tradie verification docs, SAS-gated).
/// </summary>
public interface IBlobStorageService
{
    /// <summary>Upload a stream and return the blob name.</summary>
    Task<string> UploadAsync(Stream content, string key, string contentType, string? container = null);

    /// <summary>Delete a blob by name (used on job cancellation / photo removal).</summary>
    Task DeleteAsync(string key, string? container = null);

    /// <summary>
    /// Time-limited read URL for private blobs (e.g. tradie credentials
    /// for the admin review queue). Implemented with a service SAS, which
    /// Azurite supports.
    /// </summary>
    Task<Uri> GetReadSasUriAsync(string key, string? container, TimeSpan validFor);

    /// <summary>
    /// P8-03 alias: temporary signed read URL for a private blob.
    /// Sensitive docs (credentials, receipts, dispute evidence, refund proofs)
    /// are never publicly readable — callers return this URL instead.
    /// </summary>
    Task<Uri> GenerateSignedUrl(string fileKey, TimeSpan expiration, string? container = null);
}

public class AzureBlobStorageService : IBlobStorageService
{
    private readonly BlobServiceClient _service;
    private readonly string _photosContainer;
    private readonly string _credentialsContainer;
    private readonly string _paymentsContainer;
    private readonly string _disputesContainer;
    private readonly string? _externalServiceUrl;
    private readonly ILogger<AzureBlobStorageService> _logger;

    public AzureBlobStorageService(IConfiguration config, ILogger<AzureBlobStorageService> logger)
    {
        var serviceUrl = config["AzureBlob:ServiceUrl"] ?? "http://azurite:10000";
        var accountName = config["AzureBlob:AccountName"] ?? "devstoreaccount1";
        var accountKey = config["AzureBlob:AccountKey"]
            ?? throw new InvalidOperationException("AzureBlob:AccountKey is not configured.");

        _service = new BlobServiceClient(
            new Uri($"{serviceUrl.TrimEnd('/')}/{accountName}"),
            new StorageSharedKeyCredential(accountName, accountKey));

        _photosContainer = config["AzureBlob:PhotosContainer"] ?? "fixo-photos";
        _credentialsContainer = config["AzureBlob:CredentialsContainer"] ?? "fixo-credentials";
        // P8-03: private buckets for sensitive docs. PaymentsContainer also lives
        // under PaymentInstructions (PaymentOptions) — either key wins.
        _paymentsContainer = config["AzureBlob:PaymentsContainer"]
            ?? config["PaymentInstructions:PaymentsContainer"]
            ?? "fixo-payments";
        _disputesContainer = config["AzureBlob:DisputesContainer"] ?? "fixo-disputes";
        // Host clients use to reach blobs (e.g. http://localhost:10000 for
        // local dev). The signature covers resource + permissions, not the
        // host, so rewriting it keeps the SAS valid.
        _externalServiceUrl = config["AzureBlob:ExternalServiceUrl"];
        _logger = logger;
    }

    public string PhotosContainer => _photosContainer;
    public string CredentialsContainer => _credentialsContainer;
    public string PaymentsContainer => _paymentsContainer;
    public string DisputesContainer => _disputesContainer;

    public async Task<string> UploadAsync(Stream content, string key, string contentType, string? container = null)
    {
        var client = await GetContainerClientAsync(container ?? _photosContainer);
        await client.GetBlobClient(key).UploadAsync(
            content,
            new BlobHttpHeaders { ContentType = contentType });
        _logger.LogInformation("Uploaded {Key} to container {Container}", key, client.Name);
        return key;
    }

    public async Task DeleteAsync(string key, string? container = null)
    {
        var client = _service.GetBlobContainerClient(container ?? _photosContainer);
        await client.DeleteBlobIfExistsAsync(key);
        _logger.LogInformation("Deleted {Key} from container {Container}", key, client.Name);
    }

    public async Task<Uri> GenerateSignedUrl(string fileKey, TimeSpan expiration, string? container = null) =>
        await GetReadSasUriAsync(fileKey, container ?? _credentialsContainer, expiration);

    public async Task<Uri> GetReadSasUriAsync(string key, string? container, TimeSpan validFor)
    {
        var client = await GetContainerClientAsync(container ?? _credentialsContainer);
        var blob = client.GetBlobClient(key);

        if (!blob.CanGenerateSasUri)
            throw new InvalidOperationException("Blob client is not authorized with a shared key — cannot issue SAS URIs.");

        var sas = new BlobSasBuilder(BlobSasPermissions.Read, DateTimeOffset.UtcNow.Add(validFor))
        {
            BlobContainerName = client.Name,
            BlobName = key,
        };
        var uri = blob.GenerateSasUri(sas);

        if (!string.IsNullOrWhiteSpace(_externalServiceUrl))
        {
            var external = new Uri(_externalServiceUrl.TrimEnd('/'));
            var builder = new UriBuilder(uri) { Scheme = external.Scheme, Host = external.Host, Port = external.Port };
            uri = builder.Uri;
        }
        return uri;
    }

    private async Task<BlobContainerClient> GetContainerClientAsync(string container)
    {
        var client = _service.GetBlobContainerClient(container);
        await client.CreateIfNotExistsAsync(PublicAccessType.None);
        return client;
    }
}
