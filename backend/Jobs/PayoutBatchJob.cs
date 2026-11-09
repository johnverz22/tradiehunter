using System;
using System.Threading.Tasks;
using FixoApi.Services.Payout;
using Microsoft.Extensions.Logging;

namespace FixoApi.Jobs;

public class PayoutBatchJob
{
    private readonly IPayoutService _payoutService;
    private readonly ILogger<PayoutBatchJob> _logger;

    public PayoutBatchJob(IPayoutService payoutService, ILogger<PayoutBatchJob> logger)
    {
        _payoutService = payoutService;
        _logger = logger;
    }

    public async Task ExecuteAsync()
    {
        _logger.LogInformation("Starting weekly payout batch generation.");
        try
        {
            var batch = await _payoutService.CreateBatchAsync();
            if (batch != null)
            {
                _logger.LogInformation("Successfully created payout batch {BatchId} with {Count} payouts.", batch.Id, batch.PayoutCount);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to create payout batch.");
            throw;
        }
    }
}
