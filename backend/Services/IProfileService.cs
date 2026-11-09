using FixoApi.DTOs;

namespace FixoApi.Services;

public interface IProfileService
{
    Task<ProfileDto?> GetProfileAsync(string userId, bool isPublicView);
    Task<bool> UpdateProfileAsync(string userId, ProfileUpdateDto dto);

    // ── Tradie onboarding (P1-06). All methods return null when the user
    // has no tradie profile (caller maps to 403).
    Task<List<TradieScheduleDto>?> GetScheduleAsync(string userId);
    Task<bool> UpdateScheduleAsync(string userId, UpdateScheduleRequest request);
    Task<List<TradieRateDto>?> GetRatesAsync(string userId);
    /// <returns>Null when the user has no tradie profile; false when a service id is unknown.</returns>
    Task<bool?> UpdateRatesAsync(string userId, UpdateRatesRequest request);
    Task<List<TradieCredentialDto>?> GetCredentialsAsync(string userId);
    Task<CredentialUploadResult> UploadCredentialAsync(string userId, Stream content, string fileName, string contentType, string type);
    Task<List<ServiceCatalogDto>> GetServicesAsync();
}
