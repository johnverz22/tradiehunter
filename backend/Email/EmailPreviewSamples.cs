using FixoApi.Options;

namespace FixoApi.Email;

/// <summary>
/// Sample models for every template — powers the admin preview service
/// (§5.7, /api/admin/email-preview/{template}) and the renderer test suite
/// (§6). Designers review real-looking renders without touching SMTP.
/// Factories take a brand config: the default brand has no FrontendBaseUrl
/// (CTAs omitted — §9 Q1); the preview/test "with frontend" brand shows the
/// CTA variant.
/// </summary>
public static class EmailPreviewSamples
{
    public static BrandOptions SampleBrand { get; } = new()
    {
        AppName = "TradieHunter",
        SupportEmail = "support@tradiehunter.nz",
        SupportHoursDisplay = "8am - 6pm NZT, Mon-Fri",
        FrontendBaseUrl = "", // CTAs omitted while no web app exists (Q1)
    };

    /// <summary>Brand with a frontend base URL — renders the CTA variant.</summary>
    public static BrandOptions WithFrontend { get; } = new()
    {
        AppName = "TradieHunter",
        SupportEmail = "support@tradiehunter.nz",
        SupportHoursDisplay = "8am - 6pm NZT, Mon-Fri",
        FrontendBaseUrl = "https://app.tradiehunter.nz",
    };

    private static string? Link(BrandOptions brand, string path) =>
        string.IsNullOrWhiteSpace(brand.FrontendBaseUrl)
            ? null
            : brand.FrontendBaseUrl.TrimEnd('/') + path;

    /// <summary>Every template with sample data — single source for tests + preview.</summary>
    public static readonly IReadOnlyDictionary<string, Func<BrandOptions, IEmailTextModel>> All =
        new Dictionary<string, Func<BrandOptions, IEmailTextModel>>(StringComparer.Ordinal)
        {
            ["Otp"] = brand => new OtpModel
            {
                Otp = "482913",
                Brand = brand,
            },
            ["StaffInvite"] = brand => new StaffInviteModel
            {
                Token = "CfDJ8NGx8k-EXAMPLE-TOKEN-_9YzQ",
                ActivationUrl = Link(brand, "/staff/activate?token=CfDJ8NGx8k-EXAMPLE"),
                ExpiresInHours = 24,
                Brand = brand,
            },
            ["PaymentVerified"] = brand => new PaymentVerifiedModel
            {
                JobTitle = "Fence repair",
                AmountDisplay = Money.Format(456.00m, "NZD"),
                TradieName = "Wiremu Kereopa",
                Reference = "TH-1042",
                JobUrl = Link(brand, "/jobs/1042"),
                Brand = brand,
            },
            ["PaymentRejected"] = brand => new PaymentRejectedModel
            {
                JobTitle = "Leaking tap",
                Reason = "The transfer reference doesn't match your job's code.",
                DeadlineDisplay = NzTime.Format(new DateTime(2026, 11, 25, 4, 0, 0, DateTimeKind.Utc)),
                PaymentUrl = Link(brand, "/jobs/1043/payment"),
                Brand = brand,
            },
            ["CriticalNotice"] = brand => new CriticalNoticeModel
            {
                Heading = "Update on your job \"Gib stopping\"",
                Preheader = "Your tradie cancelled — we're finding you a new one.",
                Sections =
                [
                    new EmailSection(
                        "What's happening",
                        "Your tradie cancelled \"Gib stopping\". We're finding you a new tradie now — you'll get a notification when someone accepts."),
                    new EmailSection(
                        "Your payment",
                        "No money has been confirmed for this job yet. Nothing to do until we match a new tradie.",
                        Callout: "If you want to cancel instead, reply to this email within 24 hours."),
                ],
                Brand = brand,
            },
            ["RefundProcessed"] = brand => new RefundProcessedModel
            {
                JobTitle = "Gib stopping",
                AmountDisplay = Money.Format(456.00m, "NZD"),
                Reference = "TH-RF-207",
                PaymentUrl = Link(brand, "/jobs/1044/payment"),
                Brand = brand,
            },
            ["AccountSuspended"] = brand => new AccountSuspendedModel
            {
                Name = "Aroha Ngata",
                Brand = brand,
            },
            ["StaffAlert"] = brand => new StaffAlertModel
            {
                Heading = "Receipt awaiting verification",
                Body = "A homeowner uploaded a payment receipt and the job is waiting for staff to verify it.",
                Rows =
                [
                    new EmailSummaryRow("Job", "Fence repair (#1042)"),
                    new EmailSummaryRow("Amount", Money.Format(456.00m, "NZD"), Emphasize: true),
                    new EmailSummaryRow("Waiting", "32 minutes"),
                ],
                AdminUrl = Link(brand, "/payments"),
                Brand = brand,
            },
            ["JobCancelled"] = brand => new JobClosedModel
            {
                JobTitle = "Deck staining",
                Reason = "No tradie response within 24h — auto-expired.",
                PostAgainUrl = Link(brand, "/jobs/new"),
                Brand = brand,
            },
        };
}
