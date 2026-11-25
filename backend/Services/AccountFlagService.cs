using FixoApi.Data;
using FixoApi.Enums;
using FixoApi.Models;
using Microsoft.EntityFrameworkCore;
using System;
using System.Linq;
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

    public async Task ResolveOverdueFlagAsync(string userId, string resolvedBy, string? note = null)
    {
        var now = DateTime.UtcNow;

        // If the homeowner still has another v2 job in AwaitingPayment whose payment window has passed,
        // do not resolve the flag yet — they still have an overdue payment.
        var hasOtherOverdue = await _context.Jobs.AnyAsync(j =>
            j.HomeownerId == userId
            && j.FlowVersion >= 2
            && j.Status == JobStatus.AwaitingPayment
            && j.PaymentDueAtUtc != null
            && j.PaymentDueAtUtc < now);

        if (hasOtherOverdue)
        {
            return;
        }

        var flags = await _context.AccountFlags
            .Where(f => f.UserId == userId
                     && f.Type == AccountFlagType.OverduePayment
                     && !f.Resolved)
            .ToListAsync();

        if (flags.Count == 0) return;

        foreach (var flag in flags)
        {
            flag.Resolved = true;
            flag.ResolvedAtUtc = now;
            flag.Note = string.IsNullOrEmpty(flag.Note)
                ? (string.IsNullOrEmpty(note) ? $"Resolved by {resolvedBy}." : $"[Resolved by {resolvedBy}] {note}")
                : (string.IsNullOrEmpty(note) ? $"{flag.Note}\nResolved by {resolvedBy}." : $"{flag.Note}\n[Resolved by {resolvedBy}] {note}");
        }

        await _context.SaveChangesAsync();
    }
}
