using FixoApi.Data;
using FixoApi.Enums;
using FixoApi.Models;
using Microsoft.EntityFrameworkCore;
using System.Threading.Tasks;

namespace FixoApi.Services;

public class AccountFlagService : IAccountFlagService
{
    private readonly FixoDbContext _context;

    public AccountFlagService(FixoDbContext context)
    {
        _context = context;
    }

    public async Task LogFlagAsync(string userId, AccountFlagType flagType, string? note, string? createdBy = null)
    {
        var flag = await _context.AccountFlags
            .FirstOrDefaultAsync(f => f.UserId == userId && f.Type == flagType && !f.Resolved);

        if (flag == null)
        {
            flag = new AccountFlag
            {
                UserId = userId,
                Type = flagType,
                Counter = 1,
                CreatedBy = createdBy,
                Note = note
            };
            _context.AccountFlags.Add(flag);
        }
        else
        {
            flag.Counter++;
            flag.Note = string.IsNullOrEmpty(flag.Note) ? note : $"{flag.Note}\n{note}";
        }

        // Apply threshold logic. e.g., 3 strikes
        if (flag.Counter >= 3)
        {
            flag.ThresholdHit = true;
        }

        await _context.SaveChangesAsync();
    }
}
