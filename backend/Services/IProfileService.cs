using FixoApi.DTOs;

namespace FixoApi.Services;

public interface IProfileService
{
    Task<ProfileDto?> GetProfileAsync(string userId, bool isPublicView);
    Task<bool> UpdateProfileAsync(string userId, ProfileUpdateDto dto);
}
