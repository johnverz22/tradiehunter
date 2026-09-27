using Amazon.S3;
using Amazon.S3.Model;
using FixoApi.Models;

namespace FixoApi.Services;

/// <summary>
/// Blob storage via the AWS S3 SDK targeting S3-compatible APIs
/// (MinIO in dev, AWS S3 / Azure Blob in production — AGENTS.md).
/// </summary>
public interface IBlobStorageService
{
    /// <summary>Upload a stream and return the S3 key.</summary>
    Task<string> UploadAsync(Stream content, string key, string contentType);

    /// <summary>Delete an object by key (used on job cancellation / photo removal).</summary>
    Task DeleteAsync(string key);
}

public class S3BlobStorageService : IBlobStorageService
{
    private readonly IAmazonS3 _s3;
    private readonly string _bucket;
    private readonly ILogger<S3BlobStorageService> _logger;

    public S3BlobStorageService(IAmazonS3 s3, IConfiguration config, ILogger<S3BlobStorageService> logger)
    {
        _s3     = s3;
        _bucket = config["S3:BucketName"] ?? "fixo-photos";
        _logger = logger;
    }

    public async Task<string> UploadAsync(Stream content, string key, string contentType)
    {
        var request = new PutObjectRequest
        {
            BucketName  = _bucket,
            Key         = key,
            InputStream = content,
            ContentType = contentType,
        };

        await _s3.PutObjectAsync(request);
        _logger.LogInformation("Uploaded {Key} to bucket {Bucket}", key, _bucket);
        return key;
    }

    public async Task DeleteAsync(string key)
    {
        var request = new DeleteObjectRequest { BucketName = _bucket, Key = key };
        await _s3.DeleteObjectAsync(request);
        _logger.LogInformation("Deleted {Key} from bucket {Bucket}", key, _bucket);
    }
}
