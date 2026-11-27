using FixoApi.Data;
using FixoApi.Enums;
using FixoApi.Models;
using FixoApi.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FixoApi.Tests;

public class StaffRecipientResolverTests
{
    private static FixoDbContext MakeDb()
    {
        var opts = new DbContextOptionsBuilder<FixoDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new FixoDbContext(opts);
    }

    private static ApplicationUser User(
        string id, UserRole role, bool active = true, string? email = "x@tradiehunter.nz") => new()
    {
        Id = id,
        UserName = id,
        Email = email,
        FirstName = "First" + id,
        LastName = "Last",
        Role = role,
        IsActive = active,
    };

    [Fact]
    public async Task Returns_active_staff_and_superadmin_only()
    {
        await using var db = MakeDb();
        db.Users.AddRange(
            User("staff-1", UserRole.Staff),
            User("super-1", UserRole.Superadmin),
            User("home-1", UserRole.Homeowner),
            User("trade-1", UserRole.Tradie));
        await db.SaveChangesAsync();

        var recipients = await new StaffRecipientResolver(db).GetRecipientsAsync();

        Assert.Equal(new[] { "staff-1", "super-1" }, recipients.Select(r => r.UserId).OrderBy(x => x).ToArray());
    }

    [Fact]
    public async Task Excludes_pending_invites_and_suspended_accounts()
    {
        await using var db = MakeDb();
        // Invited staff stay IsActive=false until they set a password; suspension also clears IsActive.
        db.Users.AddRange(
            User("pending-1", UserRole.Staff, active: false),
            User("suspended-1", UserRole.Staff, active: false),
            User("ok-1", UserRole.Staff));
        await db.SaveChangesAsync();

        var recipients = await new StaffRecipientResolver(db).GetRecipientsAsync();

        Assert.Equal(new[] { "ok-1" }, recipients.Select(r => r.UserId).ToArray());
    }

    [Fact]
    public async Task Excludes_locked_out_bounced_and_emailless_accounts()
    {
        await using var db = MakeDb();
        var locked = User("locked-1", UserRole.Staff);
        locked.LockoutEnd = DateTimeOffset.UtcNow.AddDays(30);
        var bounced = User("bounced-1", UserRole.Staff);
        bounced.EmailBouncedAtUtc = DateTime.UtcNow;
        var expiredLock = User("expired-lock-1", UserRole.Staff);
        expiredLock.LockoutEnd = DateTimeOffset.UtcNow.AddDays(-1);
        db.Users.AddRange(locked, bounced, expiredLock, User("noemail-1", UserRole.Staff, email: null));
        await db.SaveChangesAsync();

        var recipients = await new StaffRecipientResolver(db).GetRecipientsAsync();

        Assert.Equal(new[] { "expired-lock-1" }, recipients.Select(r => r.UserId).ToArray());
    }

    [Fact]
    public async Task Returns_empty_when_there_is_no_staff()
    {
        await using var db = MakeDb();
        var recipients = await new StaffRecipientResolver(db).GetRecipientsAsync();
        Assert.Empty(recipients);
    }
}
