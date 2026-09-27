using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Models;
using Microsoft.EntityFrameworkCore;
using NetTopologySuite.Geometries;

namespace FixoApi.Services;

public class ProfileService : IProfileService
{
    private readonly FixoDbContext _context;

    public ProfileService(FixoDbContext context)
    {
        _context = context;
    }

    public async Task<ProfileDto?> GetProfileAsync(string userId, bool isPublicView)
    {
        var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == userId);
        if (user == null) return null;

        // ── Aggregated rating (M4-03) ──────────────────────────────────────────
        var reviews = await _context.Reviews
            .Where(r => r.RevieweeId == userId)
            .ToListAsync();

        var avgRating = reviews.Count > 0
            ? Math.Round((decimal)reviews.Average(r => r.Rating), 1)
            : 0m;

        var dto = new ProfileDto
        {
            Id            = user.Id,
            FirstName     = user.FirstName,
            LastName      = user.LastName,
            Role          = user.Role,
            AverageRating = avgRating,
            ReviewCount   = reviews.Count,
        };

        if (!isPublicView)
        {
            dto.Email       = user.Email;
            dto.PhoneNumber = user.PhoneNumber;
        }

        if (user.Role == Enums.UserRole.Tradie)
        {
            var tradie = await _context.TradieProfiles.FirstOrDefaultAsync(t => t.UserId == userId);
            if (tradie != null)
            {
                dto.TradeType       = tradie.TradeType;
                dto.BusinessName    = tradie.BusinessName;
                dto.IsVerified      = tradie.IsVerified;
                dto.IsAvailable     = tradie.IsAvailable;
                dto.ServiceRadiusKm = tradie.ServiceRadiusKm;
                
                if (!isPublicView)
                {
                    dto.Address   = tradie.Address;
                    dto.Latitude  = tradie.Location?.Y;
                    dto.Longitude = tradie.Location?.X;
                }
            }
        }

        return dto;
    }

    public async Task<bool> UpdateProfileAsync(string userId, ProfileUpdateDto dto)
    {
        var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == userId);
        if (user == null) return false;

        user.FirstName   = dto.FirstName;
        user.LastName    = dto.LastName;
        user.PhoneNumber = dto.PhoneNumber;

        if (user.Role == Enums.UserRole.Tradie)
        {
            var tradie = await _context.TradieProfiles.FirstOrDefaultAsync(t => t.UserId == userId);
            if (tradie == null)
            {
                tradie = new TradieProfile { UserId = userId };
                _context.TradieProfiles.Add(tradie);
            }

            if (dto.TradeType       != null) tradie.TradeType       = dto.TradeType;
            if (dto.BusinessName    != null) tradie.BusinessName    = dto.BusinessName;
            if (dto.IsAvailable.HasValue)    tradie.IsAvailable     = dto.IsAvailable.Value;
            if (dto.ServiceRadiusKm.HasValue) tradie.ServiceRadiusKm = dto.ServiceRadiusKm.Value;
            if (dto.Address         != null) tradie.Address         = dto.Address;
            
            if (dto.Latitude.HasValue && dto.Longitude.HasValue)
            {
                tradie.Location = new Point(dto.Longitude.Value, dto.Latitude.Value) { SRID = 4326 };
            }
        }

        await _context.SaveChangesAsync();
        return true;
    }
}
