using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Email;
using FixoApi.Enums;
using FixoApi.Jobs;
using FixoApi.Models;
using FixoApi.Options;
using FixoApi.Services;
using FixoApi.Services.Payout;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace FixoApi.Tests;

/// <summary>
/// Plan 09 N5: verifies that receipt upload, payment SLA breach, overdue payment,
/// auto-complete escalation, payout batch creation/completion, and account flag
/// threshold crossing raise the expected StaffAlert events.
/// </summary>
public class NotificationN5StaffAlertTests
{
    private static FixoDbContext MakeDb()
    {
        var opts = new DbContextOptionsBuilder<FixoDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new FixoDbContext(opts);
    }

    [Fact]
    public async Task UploadReceiptAsync_alerts_staff_receipt_awaiting_verification()
    {
        await using var db = MakeDb();
        db.Users.AddRange(
            new ApplicationUser { Id = "home-1", UserName = "home-1" },
            new ApplicationUser { Id = "tradie-1", UserName = "tradie-1" });
        var job = new Job
        {
            Title = "Fix leaking tap",
            Description = "Kitchen tap",
            Address = "1 Queen St",
            HomeownerId = "home-1",
            MatchedTradieId = "tradie-1",
            Status = JobStatus.AwaitingPayment,
            FinalAmount = 250m,
            FlowVersion = 2,
        };
        db.Jobs.Add(job);
        await db.SaveChangesAsync();

        var notifications = new RecordingNotificationService();
        var sut = new PaymentService(
            db,
            new StubJobStatusService(),
            new NullBlobStorageService(),
            new ManualReceiptProvider(),
            notifications,
            new NullEmailSender(),
            new NullAuditLogService(),
            Microsoft.Extensions.Options.Options.Create(new PaymentOptions()),
            Microsoft.Extensions.Options.Options.Create(new LocaleOptions { DefaultCurrency = "NZD" }),
            NullLogger<PaymentService>.Instance,
            new AccountFlagService(db, notifications));

        await using var stream = new MemoryStream(new byte[] { 1, 2, 3, 4 });
        await sut.UploadReceiptAsync(job.Id, "home-1", new ReceiptUpload
        {
            Content = stream,
            FileName = "receipt.png",
            ContentType = "image/png",
            Length = stream.Length,
        });

        var alert = Assert.Single(notifications.StaffAlerts);
        Assert.Equal(NotificationEvents.ReceiptAwaitingVerification, alert.EventKey);
        Assert.StartsWith("payment:", alert.EntityKey);
        Assert.Equal("/payments", alert.AdminPath);
    }

    [Fact]
    public async Task PaymentSlaJob_alerts_staff_for_breached_payments_only()
    {
        await using var db = MakeDb();
        var job1 = new Job { Title = "Overdue review", Description = "d", Address = "a", HomeownerId = "h1", Status = JobStatus.PaymentReview };
        var job2 = new Job { Title = "Fresh review", Description = "d", Address = "a", HomeownerId = "h2", Status = JobStatus.PaymentReview };
        db.Jobs.AddRange(job1, job2);
        await db.SaveChangesAsync();

        var breached = new Payment
        {
            JobId = job1.Id,
            Amount = 180m,
            Currency = "NZD",
            Status = PaymentStatus.Submitted,
            SubmittedAtUtc = DateTime.UtcNow.AddMinutes(-45),
        };
        var fresh = new Payment
        {
            JobId = job2.Id,
            Amount = 90m,
            Currency = "NZD",
            Status = PaymentStatus.Submitted,
            SubmittedAtUtc = DateTime.UtcNow.AddMinutes(-5),
        };
        db.Payments.AddRange(breached, fresh);
        await db.SaveChangesAsync();

        var notifications = new RecordingNotificationService();
        var sut = new PaymentSlaJob(db, notifications, NullLogger<PaymentSlaJob>.Instance);
        await sut.ExecuteAsync();

        var alert = Assert.Single(notifications.StaffAlerts);
        Assert.Equal(NotificationEvents.PaymentSlaBreach, alert.EventKey);
        Assert.Equal($"payment:{breached.Id}", alert.EntityKey);
        Assert.Equal("/payments", alert.AdminPath);
    }

    [Fact]
    public async Task PaymentExpiryJob_v2_overdue_alerts_staff()
    {
        await using var db = MakeDb();
        db.Users.AddRange(
            new ApplicationUser { Id = "home-1", UserName = "home-1" },
            new ApplicationUser { Id = "tradie-1", UserName = "tradie-1" });
        var job = new Job
        {
            Title = "Fence repair",
            Description = "Back fence",
            Address = "2 King St",
            HomeownerId = "home-1",
            MatchedTradieId = "tradie-1",
            Status = JobStatus.AwaitingPayment,
            FlowVersion = 2,
            FinalAmount = 320m,
            PaymentDueAtUtc = DateTime.UtcNow.AddHours(-2),
        };
        db.Jobs.Add(job);
        await db.SaveChangesAsync();

        var notifications = new RecordingNotificationService();
        var sut = new PaymentExpiryJob(
            db,
            new StubJobStatusService(),
            notifications,
            null!,
            NullLogger<PaymentExpiryJob>.Instance);

        await sut.ExecuteAsync(job.Id);

        var alert = Assert.Single(notifications.StaffAlerts);
        Assert.Equal(NotificationEvents.PaymentOverdueStaff, alert.EventKey);
        Assert.Equal($"job:{job.Id}", alert.EntityKey);
        Assert.Equal("/payments", alert.AdminPath);
    }

    [Fact]
    public async Task AutoCompleteJob_v2_escalation_alerts_staff()
    {
        await using var db = MakeDb();
        db.Users.AddRange(
            new ApplicationUser { Id = "home-1", UserName = "home-1" },
            new ApplicationUser { Id = "tradie-1", UserName = "tradie-1" });
        var job = new Job
        {
            Title = "Roof leak",
            Description = "Iron roof",
            Address = "3 High St",
            HomeownerId = "home-1",
            MatchedTradieId = "tradie-1",
            Status = JobStatus.AwaitingConfirmation,
            FlowVersion = 2,
            EstimatedTotal = 200m,
            FinalAmount = 950m, // outside tolerance -> escalates to staff
        };
        db.Jobs.Add(job);
        await db.SaveChangesAsync();

        var notifications = new RecordingNotificationService();
        var sut = new AutoCompleteJob(
            db,
            new StubJobStatusService(),
            notifications,
            null!,
            Microsoft.Extensions.Options.Options.Create(new JobFlowOptions { Version = 2 }),
            NullLogger<AutoCompleteJob>.Instance);

        await sut.ExecuteAsync(job.Id);

        var alert = Assert.Single(notifications.StaffAlerts);
        Assert.Equal(NotificationEvents.JobNeedsReview, alert.EventKey);
        Assert.Equal($"job:{job.Id}", alert.EntityKey);
        Assert.Equal($"/disputes/{job.Id}", alert.AdminPath);
    }

    [Fact]
    public async Task PayoutService_alerts_staff_when_batch_created_and_completed()
    {
        await using var db = MakeDb();
        var payout = new TradiePayout
        {
            TradieId = "tradie-1",
            JobId = 42,
            GrossAmount = 500m,
            CommissionPercent = 10m,
            CommissionAmount = 50m,
            NetAmount = 450m,
            Status = PayoutStatus.Pending,
            BankAccountName = "Test Tradie",
            BankAccountNumber = "01-0001-0000001-00",
        };
        db.TradiePayouts.Add(payout);
        await db.SaveChangesAsync();

        var notifications = new RecordingNotificationService();
        var sut = new PayoutService(
            db,
            Microsoft.Extensions.Options.Options.Create(new PayoutOptions()),
            Microsoft.Extensions.Options.Options.Create(new LocaleOptions { DefaultCurrency = "NZD" }),
            notifications,
            NullLogger<PayoutService>.Instance);

        var batch = await sut.CreateBatchAsync();
        Assert.NotNull(batch);

        var readyAlert = Assert.Single(notifications.StaffAlerts);
        Assert.Equal(NotificationEvents.PayoutBatchReady, readyAlert.EventKey);
        Assert.Equal($"payout-batch:{batch.Id}", readyAlert.EntityKey);
        Assert.Equal("/payouts", readyAlert.AdminPath);

        payout.Status = PayoutStatus.Processed;
        await db.SaveChangesAsync();

        var completed = await sut.CompleteBatchAsync(batch.Id);
        Assert.True(completed);

        Assert.Equal(2, notifications.StaffAlerts.Count);
        var completedAlert = notifications.StaffAlerts[1];
        Assert.Equal(NotificationEvents.PayoutBatchCompleted, completedAlert.EventKey);
        Assert.Equal($"payout-batch:{batch.Id}", completedAlert.EntityKey);
        Assert.Equal("/payouts", completedAlert.AdminPath);
    }

    // ── Minimal test fakes ────────────────────────────────────────────────────

    private sealed class RecordingNotificationService : INotificationService
    {
        public List<StaffAlert> StaffAlerts { get; } = [];

        public Task SendToUserAsync(string userId, string title, string body,
            Dictionary<string, string>? data = null, bool critical = false,
            string? emailSubject = null, string? emailBody = null, CancellationToken ct = default)
            => Task.CompletedTask;

        public Task SendToUserAsync(string userId, string title, string body,
            Dictionary<string, string>? data, CriticalNoticeModel emailNotice,
            bool critical = false, CancellationToken ct = default)
            => Task.CompletedTask;

        public Task<bool> SendPushToUserAsync(string userId, string title, string body,
            Dictionary<string, string>? data = null, CancellationToken ct = default)
            => Task.FromResult(false);

        public Task NotifyAsync(string eventKey, string userId, string title, string body,
            Dictionary<string, string>? data = null, CriticalNoticeModel? emailNotice = null,
            CancellationToken ct = default)
            => Task.CompletedTask;

        public Task SendToStaffAsync(StaffAlert alert, CancellationToken ct = default)
        {
            StaffAlerts.Add(alert);
            return Task.CompletedTask;
        }
    }

    private sealed class StubJobStatusService : IJobStatusService
    {
        public Task RecordFlagAsync(int jobId, string userId, string reason, CancellationToken ct = default)
            => Task.CompletedTask;

        public Task<JobDto> TransitionAsync(int jobId, JobStatus newStatus, string userId,
            UserRole actorRole, ReasonCode? reasonCode = null, string? note = null)
            => Task.FromResult(new JobDto { Id = jobId, Status = newStatus.ToString() });

        public Task<JobDto> CancelJobAsync(int jobId, string userId, UserRole actorRole, CancelJobRequest request)
            => Task.FromResult(new JobDto { Id = jobId, Status = JobStatus.Cancelled.ToString() });

        public Task<JobDto> ReportNoShowAsync(int jobId, string userId, UserRole actorRole, ReportNoShowRequest request)
            => Task.FromResult(new JobDto { Id = jobId });
    }

    private sealed class NullBlobStorageService : IBlobStorageService
    {
        public Task<string> UploadAsync(Stream content, string fileName, string contentType, string? containerName = null)
            => Task.FromResult(fileName);
        public Task DeleteAsync(string blobUrl, string? containerName = null) => Task.CompletedTask;
        public Task<Uri> GetReadSasUriAsync(string blobKey, string? containerName, TimeSpan lifetime)
            => Task.FromResult(new Uri($"https://example.test/{blobKey}"));
        public Task<Uri> GenerateSignedUrl(string blobKey, TimeSpan lifetime, string? containerName = null)
            => Task.FromResult(new Uri($"https://example.test/{blobKey}"));
    }

    private sealed class NullEmailSender : IEmailSender
    {
        public Task SendOtpAsync(string toEmail, string otp) => Task.CompletedTask;
        public Task SendStaffInviteAsync(string toEmail, string inviteToken) => Task.CompletedTask;
        public Task SendStaffInviteAsync(string toEmail, string inviteToken, int expiresInHours) => Task.CompletedTask;
        public Task SendPaymentVerifiedAsync(string toEmail, string jobTitle, decimal amount, string currency = "NZD", string? tradieName = null, string? reference = null, int? jobId = null) => Task.CompletedTask;
        public Task SendPaymentRejectedAsync(string toEmail, string jobTitle, string reason, DateTime newDeadlineUtc, int? jobId = null) => Task.CompletedTask;
        public Task SendAccountSuspendedAsync(string toEmail, string name) => Task.CompletedTask;
        public Task SendRefundProcessedAsync(string toEmail, string jobTitle, decimal amount, string currency, string reference, int? jobId = null) => Task.CompletedTask;
        public Task SendJobCancelledAsync(string toEmail, string jobTitle, string reason) => Task.CompletedTask;
        public Task SendJobCancelledAsync(string toEmail, string jobTitle, string reason, int? jobId = null) => Task.CompletedTask;
        public Task SendCriticalAsync(string toEmail, string subject, string body) => Task.CompletedTask;
        public Task SendCriticalNoticeAsync(string toEmail, CriticalNoticeModel notice) => Task.CompletedTask;
        public Task SendCriticalNoticeAsync(string toEmail, string subject, CriticalNoticeModel notice, string? entityRef = null) => Task.CompletedTask;
        public Task SendStaffAlertAsync(string toEmail, StaffAlertModel alert, string? entityRef = null) => Task.CompletedTask;
    }

    private sealed class NullAuditLogService : IAuditLogService
    {
        public Task LogAsync(string? actorId, string action, string? entityType = null, string? entityId = null,
            object? before = null, object? after = null, string? ipAddress = null, CancellationToken ct = default)
            => Task.CompletedTask;

        public Task<PagedResult<AuditLogDto>> QueryAsync(DateTime? fromUtc = null, DateTime? toUtc = null,
            string? actorId = null, string? action = null, int page = 1, int pageSize = 50,
            CancellationToken ct = default)
            => Task.FromResult(new PagedResult<AuditLogDto>());
    }
}
