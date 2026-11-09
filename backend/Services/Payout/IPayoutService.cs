using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using FixoApi.DTOs;
using FixoApi.Models;

namespace FixoApi.Services.Payout;

public interface IPayoutService
{
    Task CreatePayoutAsync(Job job);

    /// <summary>Returns the new batch, or null when there was nothing to pay out.</summary>
    Task<PayoutBatch?> CreateBatchAsync();

    Task<bool> ProcessPayoutAsync(Guid payoutId, string transferReference, string adminId);

    /// <summary>Closes a batch once every payout in it is Processed. False if not yet ready.</summary>
    Task<bool> CompleteBatchAsync(Guid batchId);

    Task<PagedResult<PayoutQueueItemDto>> GetPendingPayoutsAsync(int page, int pageSize);
    Task<PagedResult<PayoutBatchSummaryDto>> GetBatchesAsync(int page, int pageSize);
    Task<PayoutBatchDetailDto?> GetBatchAsync(Guid batchId);
}
