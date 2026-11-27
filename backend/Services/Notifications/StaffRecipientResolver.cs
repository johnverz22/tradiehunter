using FixoApi.Data;
using FixoApi.Enums;
using Microsoft.EntityFrameworkCore;

namespace FixoApi.Services;

public class StaffRecipientResolver : IStaffRecipientResolver
{
    private readonly FixoDbContext _db;

    public StaffRecipientResolver(FixoDbContext db)
    {
        _db = db;
    }

    public async Task<IReadOnlyList<StaffRecipient>> GetRecipientsAsync(CancellationToken ct = default)
    {
        var now = DateTimeOffset.UtcNow;

        // IsActive is false for invited-but-not-activated staff (set on set-password)
        // and for suspended accounts, so one flag covers both. LockoutEnd is checked
        // too because deactivation also locks the account.
        var rows = await _db.Users
            .AsNoTracking()
            .Where(u => (u.Role == UserRole.Staff || u.Role == UserRole.Superadmin)
                        && u.IsActive
                        && u.Email != null
                        && u.EmailBouncedAtUtc == null
                        && (u.LockoutEnd == null || u.LockoutEnd <= now))
            .Select(u => new { u.Id, u.Email, u.FirstName, u.LastName })
            .ToListAsync(ct);

        return rows
            .Select(u => new StaffRecipient(
                u.Id,
                u.Email!,
                $"{u.FirstName} {u.LastName}".Trim()))
            .ToList();
    }
}
