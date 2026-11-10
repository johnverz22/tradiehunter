using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Models;
using Microsoft.EntityFrameworkCore;
using NetTopologySuite.Geometries;

namespace FixoApi.Services;

public class ProfileService : IProfileService
{
    private static readonly string[] AllowedCredentialTypes = ["image/jpeg", "image/png", "application/pdf"];
    private const long MaxCredentialBytes = 10 * 1024 * 1024;

    private readonly FixoDbContext _context;
    private readonly IBlobStorageService _blob;
    private readonly string _credentialsContainer;

    public ProfileService(FixoDbContext context, IBlobStorageService blob, IConfiguration config)
    {
        _context = context;
        _blob = blob;
        _credentialsContainer = config["AzureBlob:CredentialsContainer"] ?? "th-credentials";
    }

    public async Task<ProfileDto?> GetProfileAsync(string userId, bool isPublicView)
    {
        var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == userId);
        if (user == null) return null;

        // ── Aggregated rating (M4-03) ──────────────────────────────────────────
        var now = DateTime.UtcNow;
        var reviews = await _context.Reviews
            .Include(r => r.Job)
            .Where(r => r.RevieweeId == userId 
                     && (!r.RevealAfterUtc.HasValue || r.RevealAfterUtc.Value <= now)
                     && (!r.Job.IsFlagged || r.Job.DisputeStatus == "Resolved"))
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
                dto.HasInsurance    = tradie.HasInsurance;
                dto.IsAvailable     = tradie.IsAvailable;
                dto.ServiceRadiusKm = tradie.ServiceRadiusKm;
                
                if (!isPublicView)
                {
                    dto.Address   = tradie.Address;
                    dto.Latitude  = tradie.Location?.Y;
                    dto.Longitude = tradie.Location?.X;

                    // Payout details are owner-only — never on the public view.
                    dto.BankAccountName     = tradie.BankAccountName;
                    dto.BankAccountNumber   = tradie.BankAccountNumber;
                    dto.BankAccountVerified = tradie.BankAccountVerified;
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

            if (dto.BankAccountName != null) tradie.BankAccountName = dto.BankAccountName;
            if (dto.BankAccountNumber != null &&
                dto.BankAccountNumber != tradie.BankAccountNumber)
            {
                tradie.BankAccountNumber   = dto.BankAccountNumber;
                // A changed number needs re-verification before payouts.
                tradie.BankAccountVerified = false;
            }
        }

        await _context.SaveChangesAsync();
        return true;
    }

    // ── Tradie onboarding (P1-06) ────────────────────────────────────────────

    private Task<TradieProfile?> GetTradieAsync(string userId) =>
        _context.TradieProfiles.FirstOrDefaultAsync(t => t.UserId == userId);

    public async Task<List<TradieScheduleDto>?> GetScheduleAsync(string userId)
    {
        var tradie = await GetTradieAsync(userId);
        if (tradie is null) return null;

        return await _context.TradieSchedules
            .Where(s => s.TradieProfileId == tradie.Id)
            .OrderBy(s => s.Weekday)
            .Select(s => new TradieScheduleDto
            {
                Weekday = s.Weekday,
                StartTime = s.StartTime,
                EndTime = s.EndTime,
            })
            .ToListAsync();
    }

    public async Task<bool> UpdateScheduleAsync(string userId, UpdateScheduleRequest request)
    {
        var tradie = await GetTradieAsync(userId);
        if (tradie is null) return false;

        var existing = await _context.TradieSchedules
            .Where(s => s.TradieProfileId == tradie.Id)
            .ToListAsync();
        _context.TradieSchedules.RemoveRange(existing);

        foreach (var slot in request.Schedule)
        {
            _context.TradieSchedules.Add(new TradieSchedule
            {
                TradieProfileId = tradie.Id,
                Weekday = slot.Weekday,
                StartTime = slot.StartTime,
                EndTime = slot.EndTime,
            });
        }

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<List<TradieRateDto>?> GetRatesAsync(string userId)
    {
        var tradie = await GetTradieAsync(userId);
        if (tradie is null) return null;

        return await _context.TradieRates
            .Where(r => r.TradieProfileId == tradie.Id)
            .Select(r => new TradieRateDto
            {
                ServiceId = r.ServiceId,
                ServiceName = r.Service.Name,
                HourlyRate = r.HourlyRate,
            })
            .ToListAsync();
    }

    public async Task<bool?> UpdateRatesAsync(string userId, UpdateRatesRequest request)
    {
        var tradie = await GetTradieAsync(userId);
        if (tradie is null) return null;

        var serviceIds = request.Rates.Select(r => r.ServiceId).Distinct().ToList();
        var validCount = await _context.Services.CountAsync(s => serviceIds.Contains(s.Id));
        if (validCount != serviceIds.Count) return false;

        var existing = await _context.TradieRates
            .Where(r => r.TradieProfileId == tradie.Id)
            .ToListAsync();
        _context.TradieRates.RemoveRange(existing);

        foreach (var rate in request.Rates)
        {
            _context.TradieRates.Add(new TradieRate
            {
                TradieProfileId = tradie.Id,
                ServiceId = rate.ServiceId,
                HourlyRate = rate.HourlyRate,
            });
        }

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<List<TradieCredentialDto>?> GetCredentialsAsync(string userId)
    {
        var tradie = await GetTradieAsync(userId);
        if (tradie is null) return null;

        var creds = await _context.TradieCredentials
            .Where(c => c.TradieProfileId == tradie.Id)
            .OrderByDescending(c => c.Id)
            .ToListAsync();

        var dtos = new List<TradieCredentialDto>();
        foreach (var c in creds)
        {
            dtos.Add(new TradieCredentialDto
            {
                Id = c.Id,
                Type = c.Type.ToString(),
                OriginalFileName = c.OriginalFileName,
                Status = c.Status.ToString(),
                RejectReason = c.RejectReason,
                ReviewedAtUtc = c.ReviewedAtUtc,
                DownloadUrl = (await _blob.GetReadSasUriAsync(
                    c.FileKey, _credentialsContainer, TimeSpan.FromMinutes(15))).ToString(),
            });
        }
        return dtos;
    }

    public async Task<CredentialUploadResult> UploadCredentialAsync(
        string userId, Stream content, string fileName, string contentType, string type)
    {
        var tradie = await GetTradieAsync(userId);
        if (tradie is null) return new CredentialUploadResult { Error = "NotTradie" };

        if (!Enum.TryParse<CredentialType>(type, ignoreCase: true, out var credType))
            return new CredentialUploadResult { Error = "InvalidType" };

        if (!AllowedCredentialTypes.Contains(contentType.ToLowerInvariant()))
            return new CredentialUploadResult { Error = "InvalidFile" };

        var ext = Path.GetExtension(fileName).ToLowerInvariant();
        var key = $"credentials/{tradie.Id}/{Guid.NewGuid()}{ext}";
        await _blob.UploadAsync(content, key, contentType, _credentialsContainer);

        var cred = new TradieCredential
        {
            TradieProfileId = tradie.Id,
            Type = credType,
            FileKey = key,
            OriginalFileName = fileName,
            Status = CredentialStatus.Pending,
        };
        _context.TradieCredentials.Add(cred);
        await _context.SaveChangesAsync();

        return new CredentialUploadResult
        {
            Credential = new TradieCredentialDto
            {
                Id = cred.Id,
                Type = cred.Type.ToString(),
                OriginalFileName = cred.OriginalFileName,
                Status = cred.Status.ToString(),
                DownloadUrl = (await _blob.GetReadSasUriAsync(
                    key, _credentialsContainer, TimeSpan.FromMinutes(15))).ToString(),
            },
        };
    }

    public async Task<List<ServiceCatalogDto>> GetServicesAsync()
    {
        await EnsureServiceCatalogAsync();
        return await _context.Services
            .OrderBy(s => s.Name)
            .Select(s => new ServiceCatalogDto
            {
                Id = s.Id,
                Name = s.Name,
                Category = s.Category.ToString(),
            })
            .ToListAsync();
    }

    /// <summary>
    /// Service catalog is owned by the SeedNZServices EF migration.
    /// Kept for interface compatibility.
    /// </summary>
    private Task EnsureServiceCatalogAsync()
    {
        return Task.CompletedTask;
    }
}
