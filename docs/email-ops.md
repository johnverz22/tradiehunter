# Email Operations Runbook — TradieHunter

> Companion to **EMAIL-TEMPLATE-REVISION-PLAN.md** (§5 "Production Send Hardening").
> Everything the template code does operationally, and what infra must supply to send mail for real.

## 1. What the code does

| Concern | Behaviour | Where |
|---|---|---|
| Rendering | RazorLight runtime-compiles embedded `.cshtml` templates (`backend/Email/Templates/`), one shared layout + 4 partials, into HTML; a plain-text twin is composed from the same model (72-col wrap, `====` headings, URLs on their own line) | `Email/EmailTemplateRenderer.cs`, `Email/EmailFormatting.cs` |
| Transport | MailKit SMTP (System.Net.Mail.SmtpClient is obsolete-flagged by Microsoft); TLS mode from config; multipart/alternative with **text part first** | `Services/SmtpEmailSender.cs` |
| Sender identities | OTP/invite → `security@` (no Reply-To), payment/refund → `billing@`, everything else → `hello@` (Reply-To support@). All on **one domain** — no subdomain splitting in v1 | `Services/SmtpEmailSender.cs` |
| Feature flag | `EmailSender:UseTemplates` (default **false** in base config) — old plain-text paths kept for one release; instant rollback | §7.1 rollout |
| Sandbox mode | `EmailSender:SandboxMode=true` stamps subjects `[SANDBOX] …` so screenshots can't be mistaken for prod sends | §5.6 |
| Bounces | Permanent (5xx) recipient failures set `ApplicationUser.EmailBouncedAtUtc` (nullable, additive — migration `AddEmailBouncedAtUtc`); the sender short-circuits future sends to those addresses | §5.4 |
| Reporting | `EmailBounceReportJob` Hangfire recurring job (Mondays 06:00 UTC) logs bounced addresses + per-template send/render counters | `Jobs/EmailBounceReportJob.cs` |
| Observability | Every send logs `{Template, To, EntityRef, Response, ElapsedMs}`; counters `sent/failed` + render-avg per template via `IEmailMetrics` | §5.5 |
| Preview | Staff-gated `GET /api/admin/email-preview/{template}` renders any template with sample data (`?frontend=true` for the CTA variant, `?text=true` for the plain-text twin) | §5.7 |
| Deep links | CTAs are built from `Brand:FrontendBaseUrl`. **Empty (shipped default) = every CTA omitted** — there is no universal-link web app yet (plan §9 Q1). Set it when links resolve | §4.1 |
| Invite tokens | `DataProtectionTokenProviderOptions.TokenLifespan = 24h` in Program.cs — matches the "valid for 24 hours" copy (Q4) | Program.cs |
| NZ time | Deadlines render in Pacific/Auckland via `NzTime` (invariant culture, lowercase am/pm) — replaces the server-locale `ToLocalTime()` latent bug | `Email/EmailFormatting.cs` |
| Money | Invariant `1234.56 NZD` via `Money.Format` — kills the culture-sensitive `{amount:0.00}` bug | §2.3 #10 |

## 2. Configuration

All under the `EmailSender` config section (env-var style: `EmailSender__Username`):

| Key | Dev default (Docker) | Production |
|---|---|---|
| `Host` / `Port` | `mailhog` / `1025` (MailHog container) | relay host from the provider decision below |
| `Username` / `Password` | *(empty)* | relay credentials |
| `TlsMode` | `None` | `StartTls` (SES/Postmark/SendGrid all support it) |
| `SandboxMode` | `true` | `false` |
| `UseTemplates` | `true` (canary in dev) | `true` after the manual matrix passes (§6) |
| `MailDomain` | `tradiehunter.nz` | the authenticated sending domain |
| `BounceAddress` | `bounces@tradiehunter.nz` | same; configured as the relay's Return-Path |

`Brand:FrontendBaseUrl` — set to the app/web origin once CTA links resolve; empty keeps CTAs off.

## 3. Relay provider (decision deferred to infra — plan §9 Q2)

The code is provider-agnostic (plain SMTP envelope). Recommendation from the plan: **Amazon SES** (`ap-southeast-2`, Sydney — SES has no NZ region; Sydney is the low-latency choice) at this volume, or **Postmark** if deliverability hand-holding is wanted. v1 = SMTP to the provider; v2 = provider API for bounce webhooks.

## 4. Domain authentication (DNS checklist)

1. **SPF** — include the relay provider in the sending domain's SPF record.
2. **DKIM** — 2048-bit keys for the sending domain, provisioned via the relay console.
3. **DMARC** — after a **2-week `p=none` monitoring window** (watch `rua=` reports), move to `p=quarantine; rua=mailto:dmarc@…`. Record: `_dmarc.tradiehunter.nz`.
4. **Bounces** — configure the relay so the envelope sender (Return-Path) is `bounces@…` (config key above).

## 5. Sender identities (all authenticated, single domain)

| Identity | Used by | Reply-To |
|---|---|---|
| `security@tradiehunter.nz` | OTP, staff invite | **none** — unmonitored replies there would leak codes into a shared inbox |
| `billing@tradiehunter.nz` | payment verified/rejected, refund | `support@` |
| `hello@tradiehunter.nz` | job closed, account suspended, critical notices | `support@` |

## 6. Rollout (plan §7)

1. **Feature flag off** in base config; dev/canary runs with `UseTemplates=true`.
2. **Canary**: staff accounts receive both old (sandbox) and new renders for a day of eyeballing.
3. **Flip** `EmailSender:UseTemplates=true` in production; remove the flag in the next release.
4. Manual client matrix before the flip: Gmail (web/iOS/Android), Outlook 2016 + web, Apple Mail (light + dark), Yahoo — screenshots attached to the PR.

## 7. Testing

- `dotnet test backend/FixoApi.Tests` — renderer tests over all 8 templates, copy invariants (subjects, invariant currency, NZT deadlines, no-HTML text twin, preheaders), **golden snapshots** under `backend/FixoApi.Tests/Goldens/email/` (any layout change diffs in the PR; regenerate with `UPDATE_EMAIL_GOLDENS=1 dotnet test` and review the diff).
- Mailpit/MailHog in dev asserts the send loop; the integration assertion (`Content-Type: multipart/alternative` + both parts) lands with the API integration-test phase.

## 8. Assets

The email header wordmark is the `@2x` export of `docs/design/v1.6.1/assets/brand/png/wordmark-on-light.png`, hosted at:

```
https://cdn.tradiehunter.nz/email/wordmark-on-light@2x.png
```

Upload that asset to the CDN bucket before launch; the URL is config (`Brand:EmailLogoUrl`), never hard-coded in templates. Alt text ("TradieHunter") renders if the image is blocked.

## 9. Metrics wiring (deferred)

`IEmailMetrics` keeps in-memory counters; the weekly job logs them. When infra adds a `/metrics` endpoint (e.g. prometheus-net + `Add prometheus`, decision owned by infra), expose `emails_sent_total{template}`, `emails_failed_total{template}` and an `email_render_seconds` histogram from `EmailMetrics.Snapshot()` — the data is already structured for it.

## 10. Footer address

The footer prints `Brand:PostalAddress` (placeholder "Auckland, New Zealand", plan §9 Q3). Replace it with the registered office address when the business supplies one.
