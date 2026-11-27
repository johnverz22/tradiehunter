using FixoApi.Data;
using FixoApi.Email;
using FixoApi.Models;
using FixoApi.Options;
using FixoApi.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Xunit;

namespace FixoApi.Tests;

/// <summary>
/// Plan 09 N1.2/N1.4/N1.6: the shared fan-out. Push and email are faked so the tests
/// assert channel decisions (policy), stale-token cleanup and staff alert behaviour.
/// </summary>
public class NotificationServiceTests
{
    private const string UserId = "user-1";

    private static FixoDbContext MakeDb()
    {
        var opts = new DbContextOptionsBuilder<FixoDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new FixoDbContext(opts);
    }

    private sealed class Harness
    {
        public required FixoDbContext Db { get; init; }
        public required FakePushSender Push { get; init; }
        public required RecordingEmailSender Email { get; init; }
        public required FakeStaffResolver Staff { get; init; }
        public required NotificationService Service { get; init; }
    }

    private static async Task<Harness> BuildAsync(
        string[]? tokens = null, bool withEmail = true, string frontend = "https://app.tradiehunter.nz")
    {
        var db = MakeDb();
        db.Users.Add(new ApplicationUser
        {
            Id = UserId,
            UserName = UserId,
            Email = withEmail ? "user@tradiehunter.nz" : null,
        });
        foreach (var token in tokens ?? [])
        {
            db.DeviceTokens.Add(new DeviceTokenEntity { UserId = UserId, Token = token, Platform = "android" });
        }
        await db.SaveChangesAsync();

        var push = new FakePushSender();
        var email = new RecordingEmailSender();
        var staff = new FakeStaffResolver();
        var service = new NotificationService(
            db, push, email, staff,
            new InMemoryNotificationDeduplicator(new ManualTimeProvider()),
            Microsoft.Extensions.Options.Options.Create(new BrandOptions { FrontendBaseUrl = frontend }),
            NullLogger<NotificationService>.Instance);

        return new Harness { Db = db, Push = push, Email = email, Staff = staff, Service = service };
    }

    // ── NotifyAsync (policy-driven) ───────────────────────────────────────────

    [Fact]
    public async Task Critical_event_emails_even_when_push_succeeds()
    {
        var h = await BuildAsync(tokens: ["t1"]);

        await h.Service.NotifyAsync(NotificationEvents.JobCancelled, UserId, "Job cancelled", "Your job was cancelled.");

        Assert.Single(h.Push.Sent);
        Assert.Single(h.Email.Notices); // Always = critical, regardless of push result
    }

    [Fact]
    public async Task Fallback_event_emails_only_when_push_did_not_land()
    {
        var withPush = await BuildAsync(tokens: ["t1"]);
        await withPush.Service.NotifyAsync(NotificationEvents.OfferAccepted, UserId, "Accepted", "A tradie said yes.");
        Assert.Single(withPush.Push.Sent);
        Assert.Empty(withPush.Email.Notices);

        var noTokens = await BuildAsync(tokens: []);
        await noTokens.Service.NotifyAsync(NotificationEvents.OfferAccepted, UserId, "Accepted", "A tradie said yes.");
        Assert.Empty(noTokens.Push.Sent);
        Assert.Single(noTokens.Email.Notices);

        var allFail = await BuildAsync(tokens: ["t1"]);
        allFail.Push.Outcomes["t1"] = PushSendOutcome.Failed;
        await allFail.Service.NotifyAsync(NotificationEvents.OfferAccepted, UserId, "Accepted", "A tradie said yes.");
        Assert.Single(allFail.Email.Notices);
    }

    [Fact]
    public async Task Push_only_event_never_emails()
    {
        var h = await BuildAsync(tokens: []);

        await h.Service.NotifyAsync(NotificationEvents.ReviewReceived, UserId, "New review", "You have a new review.");

        Assert.Empty(h.Email.Notices);
    }

    [Fact]
    public async Task Event_key_is_added_to_push_data_as_type()
    {
        var h = await BuildAsync(tokens: ["t1"]);

        await h.Service.NotifyAsync(
            NotificationEvents.JobBooked, UserId, "Booked", "Your job is booked.",
            new Dictionary<string, string> { ["jobId"] = "42" });

        var call = Assert.Single(h.Push.Sent);
        Assert.Equal("job_booked", call.Data!["type"]);
        Assert.Equal("42", call.Data["jobId"]);
    }

    [Fact]
    public async Task Default_email_notice_is_built_from_title_and_body()
    {
        var h = await BuildAsync(tokens: []);

        await h.Service.NotifyAsync(NotificationEvents.JobCancelled, UserId, "Job cancelled", "Your tradie cancelled.");

        var notice = Assert.Single(h.Email.Notices);
        Assert.Equal("Job cancelled", notice.Heading);
        Assert.Equal("Your tradie cancelled.", Assert.Single(notice.Sections).Body);
    }

    [Fact]
    public async Task Unknown_event_does_not_throw_or_send()
    {
        var h = await BuildAsync(tokens: ["t1"]);

        await h.Service.NotifyAsync("not_an_event", UserId, "x", "y");

        Assert.Empty(h.Push.Sent);
        Assert.Empty(h.Email.Notices);
    }

    [Fact]
    public async Task Email_failure_is_swallowed()
    {
        var h = await BuildAsync(tokens: []);
        h.Email.ThrowOnSend = true;

        await h.Service.NotifyAsync(NotificationEvents.JobCancelled, UserId, "Cancelled", "Cancelled.");
        // reaching here without an exception is the assertion
    }

    // ── SendPushToUserAsync + stale tokens (N1.4) ─────────────────────────────

    [Fact]
    public async Task Stale_tokens_are_deleted_and_the_rest_still_receive_the_push()
    {
        var h = await BuildAsync(tokens: ["good", "stale", "good2"]);
        h.Push.Outcomes["stale"] = PushSendOutcome.StaleToken;

        var ok = await h.Service.SendPushToUserAsync(UserId, "Hi", "There");

        Assert.True(ok);
        Assert.Equal(new[] { "good", "good2" }, h.Push.Sent.Select(c => c.Token).OrderBy(t => t).ToArray());
        var remaining = await h.Db.DeviceTokens.Select(t => t.Token).OrderBy(t => t).ToListAsync();
        Assert.Equal(new[] { "good", "good2" }, remaining);
    }

    [Fact]
    public async Task One_failing_token_does_not_abort_the_others()
    {
        var h = await BuildAsync(tokens: ["a", "b", "c"]);
        h.Push.Outcomes["a"] = PushSendOutcome.Failed;

        var ok = await h.Service.SendPushToUserAsync(UserId, "Hi", "There");

        Assert.True(ok);
        Assert.Equal(3, h.Push.Attempts.Count);
        Assert.Equal(2, h.Push.Sent.Count);
        Assert.Equal(3, await h.Db.DeviceTokens.CountAsync()); // Failed is not stale: keep the token
    }

    [Fact]
    public async Task Returns_false_when_the_user_has_no_tokens()
    {
        var h = await BuildAsync(tokens: []);
        Assert.False(await h.Service.SendPushToUserAsync(UserId, "Hi", "There"));
    }

    // ── SendToStaffAsync (N1.2 / N1.7) ────────────────────────────────────────

    private static StaffAlert ReceiptAlert(string entity = "payment:42") => new(
        NotificationEvents.ReceiptAwaitingVerification,
        entity,
        "Receipt awaiting verification",
        "A homeowner uploaded a receipt.",
        Rows: [new EmailSummaryRow("Job", "Fence repair (#42)")],
        AdminPath: "/payments");

    [Fact]
    public async Task Staff_alert_emails_every_staff_recipient_with_an_admin_link()
    {
        var h = await BuildAsync();
        h.Staff.Recipients =
        [
            new StaffRecipient("s1", "s1@tradiehunter.nz", "One"),
            new StaffRecipient("s2", "s2@tradiehunter.nz", "Two"),
        ];

        await h.Service.SendToStaffAsync(ReceiptAlert());

        Assert.Equal(2, h.Email.StaffAlerts.Count);
        Assert.Equal(new[] { "s1@tradiehunter.nz", "s2@tradiehunter.nz" }, h.Email.StaffAlerts.Select(a => a.To).ToArray());
        var first = h.Email.StaffAlerts[0];
        Assert.Equal("https://app.tradiehunter.nz/payments", first.Model.AdminUrl);
        Assert.Equal("receipt_awaiting_verification:payment:42", first.EntityRef);
        Assert.Empty(h.Push.Sent); // staff events never push
    }

    [Fact]
    public async Task Staff_alert_omits_the_link_when_no_frontend_is_configured()
    {
        var h = await BuildAsync(frontend: "");
        h.Staff.Recipients = [new StaffRecipient("s1", "s1@tradiehunter.nz", "One")];

        await h.Service.SendToStaffAsync(ReceiptAlert());

        Assert.Null(Assert.Single(h.Email.StaffAlerts).Model.AdminUrl);
    }

    [Fact]
    public async Task Repeated_staff_alert_for_the_same_entity_is_suppressed()
    {
        var h = await BuildAsync();
        h.Staff.Recipients = [new StaffRecipient("s1", "s1@tradiehunter.nz", "One")];

        await h.Service.SendToStaffAsync(ReceiptAlert("payment:42"));
        await h.Service.SendToStaffAsync(ReceiptAlert("payment:42")); // Hangfire retry
        await h.Service.SendToStaffAsync(ReceiptAlert("payment:43")); // different entity

        Assert.Equal(2, h.Email.StaffAlerts.Count);
    }

    [Fact]
    public async Task Non_staff_event_is_rejected_without_sending()
    {
        var h = await BuildAsync();
        h.Staff.Recipients = [new StaffRecipient("s1", "s1@tradiehunter.nz", "One")];

        await h.Service.SendToStaffAsync(new StaffAlert(
            NotificationEvents.JobCancelled, "job:1", "x", "y"));

        Assert.Empty(h.Email.StaffAlerts);
    }

    [Fact]
    public async Task No_staff_recipients_is_a_quiet_no_op()
    {
        var h = await BuildAsync();
        h.Staff.Recipients = [];

        await h.Service.SendToStaffAsync(ReceiptAlert());

        Assert.Empty(h.Email.StaffAlerts);
    }

    [Fact]
    public async Task One_failing_staff_email_does_not_block_the_others()
    {
        var h = await BuildAsync();
        h.Staff.Recipients =
        [
            new StaffRecipient("s1", "bad@tradiehunter.nz", "Bad"),
            new StaffRecipient("s2", "good@tradiehunter.nz", "Good"),
        ];
        h.Email.FailFor = "bad@tradiehunter.nz";

        await h.Service.SendToStaffAsync(ReceiptAlert());

        Assert.Equal("good@tradiehunter.nz", Assert.Single(h.Email.StaffAlerts).To);
    }

    [Fact]
    public async Task Staff_alert_persists_one_notification_row_per_recipient()
    {
        var h = await BuildAsync();
        h.Staff.Recipients =
        [
            new StaffRecipient("s1", "s1@tradiehunter.nz", "One"),
            new StaffRecipient("s2", "s2@tradiehunter.nz", "Two"),
        ];

        await h.Service.SendToStaffAsync(new StaffAlert(
            NotificationEvents.ReceiptAwaitingVerification,
            "payment:42",
            "Receipt awaiting verification",
            "Payment #42 needs review.",
            AdminPath: "/payments"));

        var rows = await h.Db.StaffNotifications.OrderBy(n => n.UserId).ToListAsync();
        Assert.Equal(2, rows.Count);
        Assert.Equal("s1", rows[0].UserId);
        Assert.Equal("s2", rows[1].UserId);
        Assert.All(rows, r =>
        {
            Assert.Equal(NotificationEvents.ReceiptAwaitingVerification, r.Type);
            Assert.Equal("payment", r.EntityType);
            Assert.Equal("42", r.EntityId);
            Assert.Equal("Receipt awaiting verification", r.Title);
            Assert.Equal("/payments", r.AdminPath);
            Assert.Null(r.ReadUtc);
        });
    }

    [Fact]
    public async Task Staff_alert_still_persists_when_email_sending_fails()
    {
        var h = await BuildAsync();
        h.Staff.Recipients = [new StaffRecipient("s1", "s1@tradiehunter.nz", "One")];
        h.Email.ThrowOnSend = true;

        await h.Service.SendToStaffAsync(ReceiptAlert("payment:99"));

        var row = Assert.Single(h.Db.StaffNotifications);
        Assert.Equal("payment", row.EntityType);
        Assert.Equal("99", row.EntityId);
    }

    // ── Fakes ─────────────────────────────────────────────────────────────────

    private sealed record PushCall(string Token, string Title, string Body, Dictionary<string, string>? Data);

    private sealed class FakePushSender : IPushSender
    {
        public Dictionary<string, PushSendOutcome> Outcomes { get; } = new();
        public List<PushCall> Attempts { get; } = [];
        public List<PushCall> Sent => Attempts.Where(a => Outcome(a.Token) == PushSendOutcome.Sent).ToList();

        private PushSendOutcome Outcome(string token) =>
            Outcomes.TryGetValue(token, out var o) ? o : PushSendOutcome.Sent;

        public Task<PushSendOutcome> TrySendAsync(
            string deviceToken, string title, string body, Dictionary<string, string>? data = null)
        {
            Attempts.Add(new PushCall(deviceToken, title, body, data));
            return Task.FromResult(Outcome(deviceToken));
        }
    }

    private sealed class FakeStaffResolver : IStaffRecipientResolver
    {
        public IReadOnlyList<StaffRecipient> Recipients { get; set; } = [];
        public Task<IReadOnlyList<StaffRecipient>> GetRecipientsAsync(CancellationToken ct = default) =>
            Task.FromResult(Recipients);
    }

    private sealed record StaffAlertMail(string To, StaffAlertModel Model, string? EntityRef);

    private sealed class RecordingEmailSender : IEmailSender
    {
        public List<CriticalNoticeModel> Notices { get; } = [];
        public List<StaffAlertMail> StaffAlerts { get; } = [];
        public bool ThrowOnSend { get; set; }
        public string? FailFor { get; set; }

        public Task SendCriticalNoticeAsync(string toEmail, CriticalNoticeModel notice)
        {
            if (ThrowOnSend) throw new InvalidOperationException("smtp down");
            Notices.Add(notice);
            return Task.CompletedTask;
        }

        public Task SendStaffAlertAsync(string toEmail, StaffAlertModel alert, string? entityRef = null)
        {
            if (ThrowOnSend || toEmail == FailFor) throw new InvalidOperationException("smtp down");
            StaffAlerts.Add(new StaffAlertMail(toEmail, alert, entityRef));
            return Task.CompletedTask;
        }

        public Task SendOtpAsync(string toEmail, string otpCode) => Task.CompletedTask;
        public Task SendStaffInviteAsync(string toEmail, string inviteToken) => Task.CompletedTask;
        public Task SendPaymentVerifiedAsync(string toEmail, string jobTitle, decimal amount, string currency,
            string? tradieName = null, string? reference = null, int? jobId = null) => Task.CompletedTask;
        public Task SendPaymentRejectedAsync(string toEmail, string jobTitle, string reason, DateTime dueAtUtc,
            int? jobId = null) => Task.CompletedTask;
        public Task SendCriticalAsync(string toEmail, string subject, string body) => Task.CompletedTask;
        public Task SendRefundProcessedAsync(string toEmail, string jobTitle, decimal amount, string currency,
            string reference, int? jobId = null) => Task.CompletedTask;
        public Task SendAccountSuspendedAsync(string toEmail, string name) => Task.CompletedTask;
        public Task SendJobCancelledAsync(string toEmail, string jobTitle, string reason) => Task.CompletedTask;
    }
}
