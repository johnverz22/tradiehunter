using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Models;
using FixoApi.Options;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace FixoApi.Services.Payout;

public class PayoutService : IPayoutService
{
    private readonly FixoDbContext _context;
    private readonly PayoutOptions _options;
    private readonly PushNotificationService _push;
    private readonly ILogger<PayoutService> _logger;

    public PayoutService(
        FixoDbContext context,
        IOptions<PayoutOptions> options,
        PushNotificationService push,
        ILogger<PayoutService> logger)
    {
        _context = context;
        _options = options.Value;
        _push = push;
        _logger = logger;
    }

    public async Task CreatePayoutAsync(Job job)
    {
        if (job.MatchedTradieId == null)
            throw new InvalidOperationException("Job has no matched tradie.");

        var profile = await _context.TradieProfiles
            .FirstOrDefaultAsync(p => p.UserId == job.MatchedTradieId);

        if (profile == null)
            throw new InvalidOperationException("Tradie profile not found.");

        var commissionPercent = _options.CommissionPercent;
        var commissionAmount = Math.Round(job.TotalAmount * (commissionPercent / 100m), 2);
        var netAmount = job.TotalAmount - commissionAmount;

        var payout = new TradiePayout
        {
            TradieId = job.MatchedTradieId,
            JobId = job.Id,
            GrossAmount = job.TotalAmount,
            CommissionPercent = commissionPercent,
            CommissionAmount = commissionAmount,
            NetAmount = netAmount,
            Status = PayoutStatus.Pending,
            BankAccountName = profile.BankAccountName,
            BankAccountNumber = profile.BankAccountNumber
        };

        if (string.IsNullOrWhiteSpace(profile.BankAccountNumber))
        {
            _logger.LogWarning("Tradie {TradieId} has no bank details. Payout for job {JobId} remains Pending.", profile.UserId, job.Id);
        }

        _context.TradiePayouts.Add(payout);
        await _context.SaveChangesAsync();
        
        // Include commission amounts in push per P10-04
        await SendPushToUserAsync(job.MatchedTradieId, "Job completed!", 
            $"You'll receive ${netAmount:F2} (after ${commissionAmount:F2} platform fee) in the next payout cycle.", 
            job.Id);
    }

    public async Task<PayoutBatch?> CreateBatchAsync()
    {
        var pendingPayouts = await _context.TradiePayouts
            .Where(p => p.Status == PayoutStatus.Pending && !string.IsNullOrWhiteSpace(p.BankAccountNumber))
            .ToListAsync();

        if (!pendingPayouts.Any())
        {
            _logger.LogInformation("No pending payouts with bank details. Skipping batch creation.");
            return null;
        }

        var batch = new PayoutBatch
        {
            PeriodStartUtc = DateTime.UtcNow.AddDays(-7), // Approximation
            PeriodEndUtc = DateTime.UtcNow,
            TotalAmount = pendingPayouts.Sum(p => p.NetAmount),
            PayoutCount = pendingPayouts.Count,
            Status = PayoutBatchStatus.Open
        };

        _context.PayoutBatches.Add(batch);

        foreach (var payout in pendingPayouts)
        {
            payout.PayoutBatchId = batch.Id;
            payout.Status = PayoutStatus.Scheduled;
        }

        await _context.SaveChangesAsync();
        
        // Notify staff (would normally broadcast to staff users)
        // Leaving out generic broadcast, assuming an admin topic or we can log it.
        _logger.LogInformation("Created PayoutBatch {BatchId} with {Count} payouts.", batch.Id, batch.PayoutCount);
        
        return batch;
    }

    public async Task<bool> ProcessPayoutAsync(Guid payoutId, string transferReference, string adminId)
    {
        var payout = await _context.TradiePayouts
            .Include(p => p.PayoutBatch)
            .FirstOrDefaultAsync(p => p.Id == payoutId);

        if (payout == null || payout.Status == PayoutStatus.Processed)
            return false;

        payout.Status = PayoutStatus.Processed;
        payout.TransferReference = transferReference;
        payout.ProcessedById = adminId;
        payout.ProcessedAtUtc = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        await SendPushToUserAsync(payout.TradieId, "Payout Processed", 
            $"Your payout of ${payout.NetAmount:F2} has been processed. Ref: {transferReference}", payout.JobId);

        // Check if batch is complete
        if (payout.PayoutBatchId.HasValue)
        {
            var batch = await _context.PayoutBatches
                .Include(b => b.Payouts)
                .FirstOrDefaultAsync(b => b.Id == payout.PayoutBatchId.Value);

            if (batch != null && batch.Payouts.All(p => p.Status == PayoutStatus.Processed))
            {
                batch.Status = PayoutBatchStatus.Completed;
                batch.CompletedAtUtc = DateTime.UtcNow;
                await _context.SaveChangesAsync();
            }
        }

        return true;
    }

    public async Task<PagedResult<PayoutQueueItemDto>> GetPendingPayoutsAsync(int page, int pageSize)
    {
        var query = PayoutQueueProjection()
            .Where(p => p.Status == PayoutStatus.Pending || p.Status == PayoutStatus.Scheduled)
            .OrderBy(p => p.CreatedAtUtc);

        var total = await query.CountAsync();
        var rows = await query.Skip((page - 1) * pageSize).Take(pageSize).ToListAsync();

        return new PagedResult<PayoutQueueItemDto>
        {
            Items = await ToQueueItemsAsync(rows),
            TotalCount = total,
            Page = page,
            PageSize = pageSize
        };
    }

    public async Task<PagedResult<PayoutBatchSummaryDto>> GetBatchesAsync(int page, int pageSize)
    {
        var query = _context.PayoutBatches
            .AsNoTracking()
            .OrderByDescending(b => b.CreatedAtUtc);

        var total = await query.CountAsync();
        var batches = await query.Skip((page - 1) * pageSize).Take(pageSize).ToListAsync();

        var items = batches.Select(b => new PayoutBatchSummaryDto
        {
            Id = b.Id,
            PeriodStartUtc = b.PeriodStartUtc,
            PeriodEndUtc = b.PeriodEndUtc,
            TotalAmount = b.TotalAmount,
            PayoutCount = b.PayoutCount,
            ProcessedCount = b.Payouts.Count(p => p.Status == PayoutStatus.Processed),
            Status = b.Status.ToString(),
            CreatedAtUtc = b.CreatedAtUtc,
            CompletedAtUtc = b.CompletedAtUtc
        }).ToList();

        return new PagedResult<PayoutBatchSummaryDto>
        {
            Items = items,
            TotalCount = total,
            Page = page,
            PageSize = pageSize
        };
    }

    public async Task<PayoutBatchDetailDto?> GetBatchAsync(Guid batchId)
    {
        var batch = await _context.PayoutBatches
            .AsNoTracking()
            .Include(b => b.Payouts)
            .ThenInclude(p => p.Tradie)
            .FirstOrDefaultAsync(b => b.Id == batchId);

        if (batch == null) return null;

        return new PayoutBatchDetailDto
        {
            Id = batch.Id,
            PeriodStartUtc = batch.PeriodStartUtc,
            PeriodEndUtc = batch.PeriodEndUtc,
            TotalAmount = batch.TotalAmount,
            PayoutCount = batch.PayoutCount,
            ProcessedCount = batch.Payouts.Count(p => p.Status == PayoutStatus.Processed),
            Status = batch.Status.ToString(),
            CreatedAtUtc = batch.CreatedAtUtc,
            CompletedAtUtc = batch.CompletedAtUtc,
            Payouts = await ToQueueItemsAsync(batch.Payouts)
        };
    }
    public async Task<bool> CompleteBatchAsync(Guid batchId)
    {
        var batch = await _context.PayoutBatches
            .Include(b => b.Payouts)
            .FirstOrDefaultAsync(b => b.Id == batchId);

        if (batch == null) return false;

        // A batch closes only once every payout in it has actually gone out the door.
        if (batch.Payouts.Any(p => p.Status != PayoutStatus.Processed))
        {
            return false;
        }

        if (batch.Status != PayoutBatchStatus.Completed)
        {
            batch.Status = PayoutBatchStatus.Completed;
            batch.CompletedAtUtc = DateTime.UtcNow;
            await _context.SaveChangesAsync();
        }

        return true;
    }

    /// <summary>
    /// Shared projection for every read that leaves the admin API, so the full
    /// <c>ApplicationUser</c> navigation and the untruncated account number are
    /// never serialised to a client.
    /// </summary>
    private IQueryable<TradiePayout> PayoutQueueProjection() =>
        _context.TradiePayouts
            .AsNoTracking()
            .Include(p => p.Tradie);

    /// <summary>
    /// Maps payout rows onto the admin DTO. Job titles are fetched in one lookup
    /// rather than through the navigation so both call sites can pass an
    /// un-tracked list.
    /// </summary>
    private async Task<List<PayoutQueueItemDto>> ToQueueItemsAsync(IEnumerable<TradiePayout> payouts)
    {
        var rows = payouts.ToList();
        var jobIds = rows.Select(p => p.JobId).Distinct().ToList();
        var jobs = await _context.Jobs
            .AsNoTracking()
            .Where(j => jobIds.Contains(j.Id))
            .Select(j => new { j.Id, j.Title, j.ReferenceCode })
            .ToDictionaryAsync(j => j.Id);

        return rows.Select(p =>
        {
            var job = jobs.GetValueOrDefault(p.JobId);
            return new PayoutQueueItemDto
            {
                Id = p.Id,
                TradieId = p.TradieId,
                TradieName = p.Tradie?.FullName ?? p.TradieId,
                JobId = p.JobId,
                JobReferenceCode = job?.ReferenceCode ?? string.Empty,
                JobTitle = job?.Title ?? $"Job {p.JobId}",
                GrossAmount = p.GrossAmount,
                CommissionPercent = p.CommissionPercent,
                CommissionAmount = p.CommissionAmount,
                NetAmount = p.NetAmount,
                Status = p.Status.ToString(),
                PayoutBatchId = p.PayoutBatchId,
                BankAccountName = p.BankAccountName,
                BankAccountLast4 = Last4Digits(p.BankAccountNumber),
                HasBankDetails = !string.IsNullOrWhiteSpace(p.BankAccountNumber),
                CreatedAtUtc = p.CreatedAtUtc,
                ProcessedAtUtc = p.ProcessedAtUtc,
                TransferReference = p.TransferReference
};
        }).ToList();
    }
    /// <summary>
    /// NZ account numbers are stored formatted (XX-XXXX-XXXXXXX-XX); staff match
    /// them against a statement by the trailing digits only.
    /// </summary>
    private static string? Last4Digits(string? accountNumber)
    {
        if (string.IsNullOrWhiteSpace(accountNumber)) return null;

        var digits = new string(accountNumber.Where(char.IsDigit).ToArray());
        if (digits.Length == 0) return null;

        return digits.Length <= 4 ? digits : digits[^4..];
    }
    
    private async Task SendPushToUserAsync(string userId, string title, string body, int jobId)
    {
        try
        {
            var tokens = await _context.DeviceTokens
                .Where(dt => dt.UserId == userId)
                .Select(dt => dt.Token)
                .ToListAsync();

            foreach (var token in tokens)
            {
                await _push.SendAsync(token, title, body, new Dictionary<string, string> { { "jobId", jobId.ToString() } });
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "FCM push to token for user {UserId} failed.", userId);
        }
    }
}
