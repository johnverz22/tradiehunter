# Email & Message Template Revision Plan — TradieHunter

> **Version:** 1.0 (Nov 2026) · **Status:** Proposed
> **Scope:** All transactional email sent by the Fixo API (`SmtpEmailSender`) and the copy of the push-notification messages that share its tone, plus the production hardening needed to send them for real (SMTP relay, sender identity, bounce handling).
> **Source of truth for visuals:** `docs/design/v1.6.1/` — `tokens/tokens.json`, `html/kit.css`, `assets/brand/`, `fonts/`.
> **Users:** Homeowners and tradies (NZ, English) — plus staff invites. Nothing is shipped that we would not be proud to receive.

---

## 1. Executive Summary

Today every email leaves the API as **plain text, unstyled, and unbranded** — `SmtpEmailSender` concatenates C# interpolated strings, sends them `IsBodyHtml = false` via a localhost test relay (port 1025), and signs off with nothing. The push messages are short and functional but inconsistent in voice (some end with periods, some don't; some say "we're here to help", some say nothing). For a marketplace whose entire value proposition is trust between two strangers about to exchange money, the transactional email channel is currently the weakest artifact a user touches.

This plan revises all **8 email types + 15 message surfaces** to a single production-grade system:

1. **A design-system-derived email theme** — navy/cream/amber palette, Space Grotesk + IBM Plex Sans type ramp, wordmark header, tokenized layout that degrades gracefully in every client from Gmail desktop to Outlook 2016.
2. **A Razor-based template architecture** in the API (`.cshtml` partials + one layout), replacing 8 hand-built string literals — compiled, testable, preview-able.
3. **Professional business copy** for every message: sentence case, active voice, NZ English, no marketing filler, every claim (deadlines, amounts, timelines) sourced from the same server values the app already trusts.
4. **Production send hardening** — authenticated relay, SPF/DKIM/DMARC-aligned sender, dedicated From identities (`no-reply@`, `security@`, `billing@`), bounce loop, per-event logging — so "production grade" is operational, not just visual.

Estimated effort: **~5–6 working days** for one developer (see §8 for the phased breakdown). No database changes are required.

---

## 2. Current-State Inventory (what exists today)

### 2.1 Email — `backend/Services/SmtpEmailSender.cs` (all plain text, `IsBodyHtml = false`)

| # | Method | Trigger / call site | Current subject | Current body (verbatim) |
|---|--------|--------------------|-----------------|--------------------------|
| E1 | `SendOtpAsync` | `AuthController` signup (L106) + login OTP (L221) | "Your TradieHunter Registration OTP" | `Your 6-digit OTP code is: {otp}\n\nIt expires in 10 minutes.` |
| E2 | `SendStaffInviteAsync` | `AdminService.CreateStaffAsync` (L381) | "You've been invited to TradieHunter Admin" | `You've been invited to join the TradieHunter Admin panel.\n\nPlease use the following token to set your password and activate your account:\n{token}` |
| E3 | `SendPaymentVerifiedAsync` | `PaymentService.VerifyReceipt` (L465) | "Your TradieHunter payment is confirmed" | `We verified your transfer for "{title}".\n\nAmount: {amt} {cur}\n\nYour tradie has been booked…` |
| E4 | `SendPaymentRejectedAsync` | `PaymentService.RejectReceipt` (L468) | "We need a different payment receipt" | `We couldn't accept the receipt…\n\nReason: {reason}\n\nPlease upload a corrected receipt by {deadline}…` |
| E5 | `SendCriticalAsync` | `NotificationService.SendToUserAsync` email fallback (L102) — carries arbitrary subject/body from the event | (caller-supplied) | (caller-supplied plain text) |
| E6 | `SendRefundProcessedAsync` | `AdminService.ProcessRefund` (L1091) | "Your TradieHunter refund has been processed" | `Your refund for "{title}" has been processed.\n\nAmount…\nReference…\n\nThe money is on its way — allow 1–2 business days…` |
| E7 | `SendAccountSuspendedAsync` | `AdminService.SuspendUser` (L282) | "Your TradieHunter account has been suspended" | `Hi {name},\n\nYour account has been suspended by our team. If you think this is a mistake, reply to this email…` |
| E8 | `SendJobCancelledAsync` | defined, **never called** (dead) — expiry path uses E5 instead via `SendToUserAsync` | "Update on your TradieHunter job" | `Your job "{title}" was closed.\n\nReason: {reason}…` |

### 2.2 Push message copy (same tone family — revise in lockstep)

| # | Site | Title | Body |
|---|------|-------|------|
| P1 | `MatchingService` (L417) | "New Job Request" | `{Title} — respond within {N} minutes.` |
| P2 | `JobService` (L301) | "New Job Match" | `{Category}: {Title}` |
| P3 | `JobStatusService` (L426/496) | "Job cancelled" / "Your tradie cancelled" | cancel bodies |
| P4 | `JobStatusService` (L633) | "Job completed!" | `How did it go with "{Title}"? Leave a review.` |
| P5 | `JobStatusService` (L679/716) | "No-Show Reported" | both-sides no-show bodies |
| P6 | `PaymentService` (L216/265) | "Payment confirmed" / "Payment receipt needs fixing" | verified/rejected bodies |
| P7 | `ScheduleReminderService` (L71) | "Job reminder — 1 hour" / "— tomorrow" | reminder body |
| P8 | `ExpirationWorker` (L101) | "Your job request expired" (→ E5 email with dedicated copy) | expiry body |
| P9 | `PayoutService` (L72/131) | "Job completed!" / "Payout Processed" | completion/payout bodies |
| P10 | `NotificationService` critical fallback | varies | varies |

`PushNotificationService` prepends the app name to every title — the titles above are therefore double-branded in the tray ("TradieHunter TradieHunter New Job Request" style risk to verify).

### 2.3 Gaps found (the honest list)

1. **Zero branding** — no logo, no color, no footer with address/support links.
2. **Plain text only** — no HTML part at all; links (job, receipt upload, app) are not even clickable.
3. **No call-to-action** — "upload a corrected receipt" tells the user *what* but not *where*; there is no deep link to the screen.
4. **Copy inconsistencies** — E3 says "Your tradie has been booked and will be in touch" (push P6 says "Your tradie is booked"); mixed sentence endings; E6 uses an en-dash range "1–2 business days" while E4 uses "within 1 business day".
5. **Dead template** — E8 exists but no call site wires it.
6. **No plain-text twin for HTML** (needed once HTML lands: multipart/alternative).
7. **No preheader** text (the inbox preview line after the subject).
8. **Operational**: `localhost:1025` test relay only; no credentials/TLS in config; single `noreply@` identity for security (OTP) and billing (refunds) alike; no bounce address; no unsubscribe/path for transactional mail (not legally required in NZ for transactional, but a support path is professional).
9. **No tests** — nothing asserts subject/body/format of any email.
10. **Currency formatting is culture-sensitive** — `{amount:0.00}` renders `1,234.56` vs `1 234,56` depending on server locale; must be invariant with explicit NZD placement.

---

## 3. Design System → Email Theme Specification

Derived exclusively from `docs/design/v1.6.1/tokens/tokens.json` + `kit.css`. Email clients are not browsers: gradients/glass are dropped, contrast is raised, and everything degrades to readable black-on-white. (Rationale: the app is "outdoor mode"-adjacent when it lands in a mail client — flat, high contrast, brand-color accents only. See kit.css `/* outdoor */` block.)

### 3.1 Palette (hex — email-safe)

| Token | Hex | Email usage |
|---|---|---|
| `navy` (brand) | `#193957` | Header band background, headings color, footer text, primary button |
| `blue` | `#3C75AA` | Secondary accent, links (`a { color:#3C75AA }`) |
| `blue100` | `#E1EBF4` | Info panel background, table header rows, "summary" card |
| `amber` | `#E38B29` | Thin top border accent (2px) on hero panels — *sparingly* |
| `cream` (paper) | `#F6F4EE` | Page background behind the card (Outlook safe-area) |
| `surface` | `#FFFFFF` | Card background |
| `ink` | `#1D2226` | Body text |
| `ink-soft` | `#5B6570` | Secondary text, captions, footer meta |
| `green` | `#3A7D5C` | Positive status chips ("Confirmed") |
| `red` | `#B23A2E` | Negative status chips ("Rejected" only in E4/E7) — never the whole email |
| `paper-line` | `#E4E0D4` | Hairline dividers (`1px solid`) |

**Dark-mode mail clients** (Apple Mail, Gmail iOS): supply `prefers-color-scheme` meta + `[data-ogsc]` overrides → background `#14181B`, card `#1E2328`, text `#ECEAE3`, soft `#9AA4AC`, links `#89AFD2` (blue300). Content must stay readable with those styles stripped — they are progressive enhancement only.

### 3.2 Type ramp (desktop → 56% of opens are mobile: clamp at small widths)

| Role | Font stack (email) | Size/weight | Notes |
|---|---|---|---|
| Wordmark | image only (`wordmark-on-light.png`, 4:1 alt "TradieHunter") | 28px height, left-aligned | PNG (SVG unsupported in Outlook/Gmail); `@2x` asset from `assets/brand/png/` |
| H1 / subject echo | `Space Grotesk, Arial, sans-serif` | 24px / 700 | Navy; one per email; = the subject, minus the prefix |
| H2 / section | `Space Grotesk, Arial, sans-serif` | 18px / 600 | Navy |
| Body | `IBM Plex Sans, Arial, Helvetica, sans-serif` | 16px / 400, line-height 1.5, `#1D2226` | 46–60 chars/line target |
| Secondary | same | 14px / 400 `#5B6570` | context lines under H1, summary labels |
| Caption / legal | same | 12px / 400 `#5B6570` | footer, OTP expiry notes |
| Amounts / references | `IBM Plex Mono, 'Courier New', monospace` | 16px / 600 | right-aligned in summary tables; never wraps |
| Button label | `IBM Plex Sans` | 16px / 600, white on navy | 48px+ tap target, 14px radius |

Web fonts in email are **progressive enhancement**: they load only in Apple Mail/Thunderbird; everywhere else falls back to Arial/Helvetica — which is why the ramp pins sizes/weights, not the faces. System font fallbacks chosen to preserve metrics (Space Grotesk → Arial; Plex Sans → Helvetica).

### 3.3 Layout skeleton (all templates share one)

```
┌──────────────────────────────────────────────┐
│ cream page background (Outlook margin)        │
│  ┌────────────────────────────────────────┐   │
│  │ HEADER band — navy #193957             │   │
│  │   wordmark-on-light.png (h 28)         │   │
│  ├────────────────────────────────────────┤   │
│  │ CARD — white, 640px max-width         │   │
│  │   H1 + preheader-ish secondary line    │   │
│  │   ── hairline ──                       │   │
│  │   body paragraph(s)                    │   │
│  │   [ summary table: label/value ]       │   │
│  │   [ CTA button — navy, full-width ]    │   │
│  │   [ amber 2px-top hero panel: OTP /    │   │
│  │     amount / deadline — when urgent ]  │   │
│  ├────────────────────────────────────────┤   │
│  │ FOOTER — cream, hairline top           │   │
│  │   TradieHunter · support@… · 8am–6pm  │   │
│  │   NZ street address (placeholder)     │   │
│  │   "You received this because…" line    │   │
│  └────────────────────────────────────────┘   │
└──────────────────────────────────────────────┘
```

Rules carried over from kit.css: 20px gutter (`--gutter`), 20px card radius (`--r-card`) — email uses 8px radius because Outlook's rounded-corner support is patchy, and `100%`-width tables with `max-width:640px` centering. Cards use `box-shadow: 0 1px 2px rgba(25,57,87,.06)` only where supported (it's invisible in Outlook — harmless).

### 3.4 Email-HTML compatibility contract (the boring engineering that makes it production grade)

- **Tables for layout**, `role="presentation"`, zero `<div>` positioning; `bgcolor` attributes duplicated on every styled cell (Outlook overrides CSS).
- **MSO conditionals**: `<o:AllowPNG/>` + VML roundrect only for the CTA button (bulletproof button pattern); everything else square.
- **Images**: only the wordmark (+ any status glyph as text ✱). `alt` text on all; `width`/`height` attributes; hosted at `https://cdn.tradiehunter.nz/email/…` (add to BrandOptions/config, never hard-code URLs in Razor).
- **Multipart/alternative**: every email = HTML part + auto-generated plain-text twin (Razor renders both from the same model — see §4).
- **Preheader**: 80–95 char hidden `<span>` after the wordmark.
- **Plain text discipline**: 72-col wrap, `====` under headings, full URLs on their own line (no shortened links — deliverability).
- **Dark-mode**: §3.1 overrides + `color-scheme` meta; tested in Apple Mail dark only.
- **No JS, no forms, no external CSS**; all CSS inline (`style="…"`) — a build step does the inlining (premailer or Razor partial emitting inline styles directly; we choose the latter: zero build toolchain).
- **Accessibility**: `lang="en-NZ"`, semantic headings, contrast ≥ 4.5:1 for all text (navy/white = 10.4:1; ink-soft/white = 7:1; on-amber = 8:1 — all pass AA).

---

## 4. Target Architecture (code changes)

```
backend/
  Email/
    Layouts/
      _EmailLayout.cshtml          ← skeleton §3.3 (header card footer, dark-mode, preheader slot)
    Partials/
      _SummaryRow.cshtml            ← label/value mono rows (amount, reference, deadline)
      _CtaButton.cshtml             ← bulletproof button (navy; URL + label)
      _HeroPanel.cshtml             ← amber-top urgent panel (OTP, amount, deadline)
      _FooterNote.cshtml            ← "why you received this" + support line
    Templates/
      Otp.cshtml                    (E1)
      StaffInvite.cshtml            (E2)
      PaymentVerified.cshtml        (E3)
      PaymentRejected.cshtml        (E4)
      CriticalNotice.cshtml         (E5 — generic, section-driven)
      RefundProcessed.cshtml       (E6)
      AccountSuspended.cshtml      (E7)
      JobCancelled.cshtml           (E8 — finally wired, see below)
    EmailModels.cs                  ← POCOs, one per template, all fields required
    EmailTemplateRenderer.cs        ← IRazorRenderer wrapper; returns (html, text) tuple
  Services/
    SmtpEmailSender.cs              ← REWRITTEN (see below)
    EmailHostedPreviewService.cs    ← (optional phase 3) serves /admin/email-preview/{template}
```

**Why Razor and not a string-template library:** the templates are visual artifacts with layout/partials; Razor gives compiled type-checked models, `_ViewImports`, and `SmtpEmailSender` keeps a single dependency (`RazorLight` — a 2-file embed of the existing ASP.NET rendering engine, MIT, no runtime compilation in prod). Alternative considered: Scriban (lighter, but then layout/partials are hand-rolled — rejected).

**`SmtpEmailSender` rewrite (keeping the interface identical — zero call-site churn):**

```csharp
public async Task SendOtpAsync(string toEmail, string otpCode)
{
    var model = new OtpModel { Otp = otpCode, Brand = _brand.Value };  // BrandOptions injected
    var (html, text) = await _templates.RenderAsync("Otp", model);
    await SendAsync(toEmail, "Your TradieHunter verification code", html, text,
                    new SenderIdentity("security@tradiehunter.nz", "TradieHunter Security"));
}
```

- `SenderIdentity` per template class: OTP/invite → `security@`; payment/refund/payout → `billing@`; everything else → `hello@` (all on the same relay, aligned under one SPF/DKIM domain — no subdomain splitting in v1).
- `SendAsync(to, subject, html, text, identity)`: sets `IsBodyHtml` with `AlternateViews` (text first, then html — order matters for spam-score heuristics), `Reply-To` = `support@` for human-facing templates (NOT for OTP — unmonitored reply there would leak codes into a shared inbox), UTF-8 `SubjectEncoding`, and `X-Entity-Ref` header carrying the related entity (jobId/paymentId) so inbound threading can match.
- SMTP: `SmtpClient` is replaced by **MailKit** (`ISmtpEmailSender` options: host/port/user/pass/TLS mode from config — `System.Net.Mail.SmtpClient` is obsolete-flagged by Microsoft and doesn't do modern TLS negotiation well; MailKit is the documented replacement). Config gains `EmailSender:Username/Password/TlsMode/SandboxMode`.

### 4.1 Deep links (the "where do I tap" fix)

Every CTA is a real URL (scheme chosen because deep links are already routed in the app):

| Template | CTA | Link |
|---|---|---|
| Otp | (no button — the code IS the CTA) | — |
| StaffInvite | "Set your password" | `{frontendBaseUrl}/staff/activate?token=…` |
| PaymentVerified | "View job" | `https://…/jobs/{jobId}` (web fallback = app store link if app-only) |
| PaymentRejected | "Upload new receipt" | `{frontendBaseUrl}/jobs/{jobId}/payment` |
| RefundProcessed | "View payment" | job payment screen |
| AccountSuspended | "Contact support" | `mailto:support@…` (no login deep-link to a suspended account) |
| JobCancelled/Expired | "Post a job again" | `/jobs/new` |
| CriticalNotice | caller-supplied (optional) | — |

`frontendBaseUrl` from BrandOptions (new `FrontendBaseUrl` setting; empty → CTA omitted, body stands alone). This mirrors how the mobile router already resolves `/jobs/:id/payment` (app_router.dart L162) — same paths, one source of truth.

### 4.2 Message copy rewrites (every email, final copy)

Tone: sentence case, active voice, NZ English ("tradie", "mate" never), 2nd person, no exclamation marks in subjects, amounts and deadlines always explicit. All copy centralized in the templates — call sites pass data, never words.

**E1 — OTP**
- Subject: `Your TradieHunter verification code`
- Preheader: `Code 123456 — it expires in 10 minutes.`
- H1: `Verify your email`
- Hero panel (amber top): the 6-digit code, mono 32px, letter-spaced.
- Body: `Enter this code in the TradieHunter app to finish signing in. It expires in 10 minutes. Didn't request it? Ignore this email — nothing will happen.` (factual, anti-phishing-standard).

**E2 — Staff invite**
- Subject: `You've been invited to the TradieHunter admin panel`
- H1: `Set up your staff account`
- Body: `An administrator invited you to TradieHunter's staff console. Use the button below to choose a password and activate your account. The invitation is valid for 24 hours.` (24h = add an expiry when minting the token — currently unbounded; flagged as a small backend task.)

**E3 — Payment verified**
- Subject: `Payment confirmed — {jobTitle}`
- Preheader: `We matched your {amount} transfer. {tradieName} is booked.`
- H1: `Your payment is confirmed`
- Summary table: Job · Amount · Paid to · Reference (mono).
- Body: `We matched your transfer to {reference}. {tradieName} (or the TradieHunter team) will be in touch to confirm the visit time.` + CTA "View job". NO "escrow"/"protected" language (per truthfulness test doctrine already enforced in the app's payment tests).

**E4 — Payment rejected**
- Subject: `Action needed — receipt for {jobTitle}`
- Preheader: `Upload a new receipt by {deadline} to keep this booking.`
- H1: `We need a different receipt`
- Body: `Our team couldn't accept the receipt you uploaded for {jobTitle}. Reason: {reason}` + hero panel with the new deadline (from `PaymentDueAtUtc`, formatted `d MMM yyyy, h:mm a NZT` via a `NzTime` helper — the current `ToLocalTime()` is *server* time, a latent bug for NZ users when hosted offshore: flagged).
- CTA "Upload new receipt" → payment screen.

**E6 — Refund processed**
- Subject: `Your refund is on its way`
- Summary: Job · Amount · Reference (mono) · Expected: "1–2 business days".
- Body: `The refund for {jobTitle} has been processed from our account. Your bank will show the money within 1–2 business days.`

**E7 — Account suspended**
- Subject: `Your TradieHunter account has been suspended`
- Body: `Hi {name}, our team has suspended your TradieHunter account. If you believe this is a mistake, reply to this email or contact support@tradiehunter.nz (8am–6pm NZT, Mon–Fri) and we'll review it.` — warm but factual; never states cause (privacy), always gives recourse.

**E8 — Job closed/expired** (now actually wired: `ExpirationWorker` and the cancel paths route to it via `SendCriticalAsync`-equivalent instead of duplicating strings)
- Subject: `Your job "{jobTitle}" has been closed`
- Body: reason line + `Your job details are saved — post it again any time from the app.` + CTA.

**E5 — Critical/generic**: `CriticalNotice.cshtml` takes `Section[]` (heading, body, callout) so `NotificationService` passes structured content instead of pre-flattened strings; signature gains an optional structured payload (backwards-compatible overload).

### 4.3 Push copy alignment (same PR, same table)

Standardized: title ≤ 30 chars, no trailing period in titles, body one sentence ≤ 90 chars, sentence case. Branded once — **remove the double-brand risk** in `PushNotificationService` (prepend only when the title doesn't start with the brand, and drop the prepended variant for short titles like "Job cancelled"). Revised set (P1–P10 from §2.2): e.g. P1 → `New job request` / `Plumbing in Ponsonby — respond in 15 minutes`; P4 → `Job completed` / `How did it go with "Fence repair"? Leave a review.`; P6 rejected → `Receipt needs another look` / `Update your receipt for "Leaking tap" by Fri 5 pm.` Full copy table ships in the implementation PR (too long to duplicate here — the plan pins the rules, the PR pins the strings).

---

## 5. Production Send Hardening (operational "production grade")

1. **Relay choice**: SES ( Auckland region `ap-southeast-2`… note: SES has no NZ region; Sydney is the low-latency choice) or SendGrid/Postmark — all support the same SMTP envelope. v1 = SMTP to the chosen provider; v2 (post-launch) = provider API for bounce webhooks. Decision deferred to infra owner; the code change (MailKit + config) is provider-agnostic.
2. **Domain authentication**: SPF include for the relay, DKIM 2048-bit for `tradiehunter.nz`, DMARC `p=quarantine; rua=mailto:dmarc@…` after a 2-week `p=none` monitoring window. On DNS: `_dmarc.tradiehunter.nz`.
3. **Sender identities** (all authenticated, single domain): `security@` (OTP/invite, no Reply-To), `billing@` (payment/refund), `hello@` (everything else, Reply-To support@). Bounces → `bounces@` (configured as Return-Path on the relay).
4. **List hygiene**: transactional only — no marketing in v1; hard-bounced addresses get `EmailBouncedAtUtc` on `ApplicationUser` (small migration — the only schema change in this plan) and emails stop going to them; a weekly `LogWarning` report lists them.
5. **Observability**: every send logs `{Template, To, EntityRef, MessageId, ElapsedMs}`; two Prometheus counters (`emails_sent_total{template}`, `emails_failed_total{template}`) + one histogram (`email_render_seconds` — template rendering is a new failure mode and must be visible).
6. **Sandbox mode**: `EmailSender:SandboxMode=true` (dev default) routes everything to a Mailpit container at `localhost:1025` — the current dev loop stays intact; prod flips config only. Sandbox stamps a visible `[SANDBOX]` prefix on subjects so screenshots can't be mistaken for prod sends.
7. **Preview**: `EmailHostedPreviewService` (phase 3, admin-auth-gated route `/admin/email-preview/{template}`) renders any template with sample data — designers review without SMTP.

---

## 6. Testing Strategy

| Layer | What | How |
|---|---|---|
| Unit | Renderer returns non-empty (html, text) for every template + sample model | xUnit `[Theory]` over all 8 templates |
| Unit | Copy invariants: subject prefix "TradieHunter", amount formatted `1234.56 NZD` invariant, deadline format `d MMM yyyy h:mm a` | regex assertions on rendered text part |
| Unit | Plain-text twin contains no HTML, links as absolute URLs | assertion |
| Integration | Mailpit (docker-compose already implied by dev config) — send each template, fetch via Mailpit REST, assert `Content-Type: multipart/alternative` + both parts present | `FixoApi.Tests` (new project — currently zero backend tests) |
| Golden | `/{template}.html` snapshots committed under `tests/goldens/email/`; diff on change forces review | snapshot test |
| Manual matrix | Gmail (web/iOS/Android), Outlook 2016 + web, Apple Mail (light+dark), Yahoo | checklist in PR, screenshots attached |

---

## 7. Rollout & Migration

1. **Feature-flag**: `EmailSender:UseTemplates=true` (default false) — old string paths kept for one release; instant rollback if a template bug appears.
2. **Canary**: flag on for staff accounts only (AdminService already knows roles) → staff receive both old (to sandbox) and new (real inbox) for a day of eyeballing.
3. **Full flip + remove flag** in the next release.
4. **No DB schema change** except optional `EmailBouncedAtUtc` (§5.4) — additive, nullable, safe.
5. **Zero mobile changes required** (interface unchanged); the app's email *verification screen* copy stays consistent since the OTP email now states the 10-minute expiry the screen also shows.

---

## 8. Implementation Phases (est. 5–6 dev-days)

| Phase | Deliverable | Est | Risk |
|---|---|---|---|
| **1 — Theme & layout** | `EmailTemplateRenderer` + `_EmailLayout` + all partials + golden snapshots with dummy models; Mailpit verified in dev | 1.5 d | low |
| **2 — Port 8 templates + rewrite SmtpEmailSender** (MailKit, identities, multipart, config keys, feature flag, wire E8, fix `ToLocalTime`→NZ, invite-token expiry) | 2 d | medium — keep interface stable; call sites untouched |
| **3 — Copy & push alignment** | push title/body table implemented + double-brand fix in `PushNotificationService`; E5 structured payload | 0.5 d | low |
| **4 — Production hardening** | relay credentials + SPF/DKIM/DMARC docs (`docs/email-ops.md`), bounce field + logging, sandbox mode, observability counters | 1 d | low-medium (DNS waits on infra) |
| **5 — Preview service + full test matrix** | admin preview route, backend test project bootstrapped, manual matrix pass, PR with screenshots | 1 d | low |

Sequencing note: phases 1–2 are the PR that matters; 3–5 can trail by days. If time-boxed to one week, cut phase 5's preview service (nice-to-have) — nothing else is optional.

---

## 9. Open Questions (decisions needed, with recommendations)

| # | Question | Recommendation |
|---|----------|----------------|
| Q1 | Web-hosted CTA base URL — is there a marketing/web site yet? | If none: omit CTAs in v1 (body stands alone); add when web exists. The app currently has no universal-link fallback, so `https://` CTAs would 404 today. |
| Q2 | Relay provider (SES vs SendGrid vs Postmark) | SES (cheapest at this volume, existing AWS footprint if any); Postmark if deliverability hand-holding is wanted. |
| Q3 | Street address for the footer (NZ legal norm for business email footers) | Needs the registered office from the business — placeholder ` Auckland, New Zealand` until provided. |
| Q4 | Invite-token 24h expiry (currently unbounded) | Implement — one line where the token is minted; aligns email copy. |
| Q5 | Tradie payout emails (P9 has push only) | Out of scope v1; the `PayoutProcessed` email is a §10 candidate. |

---

## 10. Future Candidates (explicitly not in v1)

- Payout-processed email (tradie money movement — same class as refund, should exist; needs template + call site).
- New-message digest (weekly, only if users ask; otherwise noise).
- Two-factor OTP via email is currently the only OTP channel — SMS as a second channel when budget allows.
- Localized templates (nz-MI) — post-launch per MVP-SPEC language roadmap.
- AMP for Email (interactive receipt upload) — Gmail-only party trick today; revisit 2027.
