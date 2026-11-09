using System;
using System.Linq;
using System.Threading.Tasks;
using FixoApi.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace FixoApi.Jobs;

public class PaymentSlaJob
{
    private readonly FixoDbContext _context;
    private readonly ILogger<PaymentSlaJob> _logger;

    public PaymentSlaJob(FixoDbContext context, ILogger<PaymentSlaJob> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task ExecuteAsync()
    {
        var slaThreshold = DateTime.UtcNow.AddMinutes(-30);
        
        var breachedPayments = await _context.Payments
            .Where(p => p.Status == Enums.PaymentStatus.Submitted && p.SubmittedAtUtc.HasValue && p.SubmittedAtUtc.Value < slaThreshold)
            .ToListAsync();
            
        if (breachedPayments.Count > 0)
        {
            _logger.LogWarning("{Count} payments in the queue have breached the 30-minute SLA.", breachedPayments.Count);
            // Future: Alert admins via Slack, email, or admin push notification.
        }
    }
}
