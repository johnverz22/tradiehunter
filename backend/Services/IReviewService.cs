using FixoApi.DTOs;

namespace FixoApi.Services;

/// <summary>
/// Review submission and retrieval (M4-02).
/// Validation rules:
///   • Only participants (homeowner or matched tradie) may review.
///   • Only completed jobs may be reviewed.
///   • One review per reviewer per job.
///   • Cannot review yourself.
/// </summary>
public interface IReviewService
{
    /// <summary>
    /// Submit a review for <paramref name="jobId"/>. Returns the created review
    /// or throws on validation failure.
    /// </summary>
    Task<ReviewDto> SubmitReviewAsync(int jobId, string reviewerId, SubmitReviewRequest request);

    /// <summary>List all reviews for a specific job (both directions).</summary>
    Task<ReviewListResponse> GetReviewsForJobAsync(int jobId);

    /// <summary>List reviews received by a user, paginated.</summary>
    Task<ReviewListResponse> GetReviewsForUserAsync(string userId, int page, int pageSize);
}
