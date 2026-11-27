using System;
using System.Linq;
using System.Threading.Tasks;
using FixoApi.Data;
using FixoApi.Email;
using FixoApi.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace FixoApi.Jobs;

public class PaymentSlaJob
{
    private readonly FixoDbContext _context;
    private readonly INotificationService _notifications;
    private readonly ILogger<PaymentSlaJob> _logger;

    public PaymentSlaJob(
        FixoDbContext context,
        INotificationService notifications,
        ILogger<PaymentSlaJob> logger)
    {
        _context = context;
        _notifications = notifications;
        _logger = logger;
    }

    public async Task ExecuteAsync()
    {
        var slaThreshold = DateTime.UtcNow.AddMinutes(-30);

        var breachedPayments = await _context.Payments
            .Include(p => p.Job)
            .Where(p => p.Status == Enums.PaymentStatus.Submitted
                     && p.SubmittedAtUtc.HasValue
                     && p.SubmittedAtUtc.Value < slaThreshold)
            .ToListAsync();

        if (breachedPayments.Count == 0) return;

        _logger.LogWarning("{Count} payments in the queue have breached the 30-minute SLA.", breachedPayments.Count);

        var now = DateTime.UtcNow;
        foreach (var payment in breachedPayments)
        {
            var waitingMinutes = (int)Math.Max(30, Math.Round((now - payment.SubmittedAtUtc!.Value).TotalMinutes));
            var jobTitle = payment.Job?.Title ?? $"Job #{payment.JobId}";

            await _notifications.SendToStaffAsync(new StaffAlert(
                EventKey: NotificationEvents.PaymentSlaBreach,
                EntityKey: $"payment:{payment.Id}",
                Heading: $"Payment verification SLA breached — job #{payment.JobId}",
                Body: $"Receipt for \"{jobTitle}\" (#{payment.JobId}) has been waiting {waitingMinutes} minutes for staff verification.",
                Rows:
                [
                    new EmailSummaryRow("Job", $"{jobTitle} (#{payment.JobId})"),
                    new EmailSummaryRow("Amount", Money.Format(payment.Amount, payment.Currency), Emphasize: true),
                    new EmailSummaryRow("Waiting", $"{waitingMinutes} minutes"),
                ],
                AdminPath: "/payments"));
        }
    }
}
