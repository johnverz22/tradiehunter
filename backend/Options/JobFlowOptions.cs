namespace FixoApi.Options;

/// <summary>
/// v1.7 (P12-27): job-flow rollout controls. <c>Version</c> is the global
/// feature flag — 1 = legacy pay-upfront flow, 2 = pay-at-completion flow.
/// Every new job stamps the flag value onto <c>Job.FlowVersion</c> at creation,
/// and all runtime behaviour branches on the *job's* stored version, so
/// in-flight legacy jobs finish under the rules they were posted with even
/// after the global flag flips.
/// </summary>
public class JobFlowOptions
{
    /// <summary>1 = legacy (upfront payment), 2 = pay-at-completion. Default 1 until QA passes (P12-27).</summary>
    public int Version { get; set; } = 1;

    // ── Direct-request offer expiry (P12-08 / D7: urgency-aware) ─────────────

    /// <summary>
    /// Minutes a direct request stays open for ASAP/Emergency jobs (D7: ~15–30 min).
    /// </summary>
    public int AsapOfferWindowMinutes { get; set; } = 20;

    /// <summary>
    /// Minutes a direct request stays open for flexible/scheduled jobs (D7: ~2–4 h).
    /// </summary>
    public int FlexibleOfferWindowMinutes { get; set; } = 180;

    // ── Completion approval tolerance (P12-11) ───────────────────────────────

    /// <summary>
    /// How far above the estimate the final amount may land (as a percentage,
    /// e.g. 15 = +15%) before the homeowner sees a "higher than estimate"
    /// banner and auto-approve is refused. Per Consumer NZ estimate guidance.
    /// </summary>
    public decimal EstimateTolerancePercent { get; set; } = 15m;

    /// <summary>
    /// When no estimate was given, auto-approve only applies while the final
    /// amount is at or below this cap (NZD). Higher amounts escalate to staff.
    /// </summary>
    public decimal AutoApproveNoEstimateCap { get; set; } = 800m;

    // ── Price adjustments (P12-17 / P12-18) ──────────────────────────────────

    /// <summary>Hours a pending adjustment stays open before expiring (default 48h).</summary>
    public int AdjustmentExpiryHours { get; set; } = 48;

    /// <summary>Pending adjustments above this amount are flagged for staff review (P12-18).</summary>
    public decimal AdjustmentStaffReviewThreshold { get; set; } = 2000m;

    /// <summary>Maximum simultaneously pending adjustments per job (P12-18 config guard).</summary>
    public int MaxPendingAdjustmentsPerJob { get; set; } = 5;

    /// <summary>Private blob container for adjustment evidence (receipts/photos).</summary>
    public string AdjustmentsContainer { get; set; } = "th-payments";

    // ── Quotes & projects (P12-23 / P12-25) ──────────────────────────────────

    /// <summary>Concurrent quote requests allowed per project job (Builderscrack-style cap).</summary>
    public int MaxConcurrentQuoteRequests { get; set; } = 3;

    /// <summary>
    /// Plan 10 (Q7): fallback for <c>Quotes.BoardWindowHours</c> — hours an open
    /// project accepts new quotes. The admin setting (platform_settings) wins when set.
    /// </summary>
    public int QuoteBoardWindowHours { get; set; } = 72;

    /// <summary>Hours a quote request / submitted quote stays valid (default 72h).</summary>
    public int QuoteWindowHours { get; set; } = 72;

    /// <summary>
    /// Accepted quotes/estimates at or above this amount (incl. GST) require the
    /// homeowner to confirm a written contract exists before booking (Building
    /// Act s362F for residential building work — P12-25). Configuration, not code.
    /// </summary>
    public decimal WrittenContractThresholdNzd { get; set; } = 30000m;

    /// <summary>Max attachments for project jobs incl. PDFs (P12-21; hourly keeps 5 photos).</summary>
    public int ProjectMaxAttachments { get; set; } = 10;
}
