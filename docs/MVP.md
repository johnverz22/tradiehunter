# TradieHunter — MVP Scope (final, through v1.7)

> Replaces MVP-SPEC v1.1, v1.2 and v1.3. Where earlier specs disagreed, **later decisions win** and the superseded one is listed in §7.

## 1. Platforms

| Platform | Role |
|---|---|
| **Flutter mobile** | One app, role-based views (homeowner / tradie). Primary client. |
| **React web** | Admin dashboard only (Staff + Superadmin). Cookie-based auth. |
| **.NET 10 API** | REST + SignalR (chat, status, offers), Hangfire jobs, FCM push. |

## 2. In scope (shipped)

**Tier 1 — core loop**
- Email + OTP registration, Google login, role select; staff/admin invites (Superadmin only)
- Tradie onboarding wizard: profile, base address + radius, trades with hourly rates, weekly schedule, licence/insurance credentials, bank details
- Job posting: service, address (LINZ search, no manual coordinates), description, up to 5 photos, timing, urgency
- Matching: rule-based ranking (distance, rating, schedule fit), sequential offers with timeouts, broadened second stage, licence-gated for regulated services
- Job state machine with full status history, SignalR + FCM on every transition
- Chat (job-scoped, unlocked at `Booked`), push notifications with email fallback for critical events

**Tier 2 — trust and quality**
- Tradie profiles with rating, verified/insured badges, reviews; public profile with report/block
- Blind two-way reviews; low-rating admin flag
- Scheduling, reminders, check-in/check-out, auto-confirm

**Tier 3 — operations**
- Manual payment: bank-transfer instructions, receipt upload with duplicate-hash detection, staff verification queue with SLA colours
- Tradie payouts: weekly batches, commission, admin "mark processed"
- Cancellations, no-shows, refund queue (legacy flow only), disputes with evidence, account flags, audit log
- Admin web: dashboard, users, credentials, payments, refunds, payouts, disputes, flags, settings

**v1.7 additions (job-flow revision, code-complete, flag-gated)**
- Optional timing (Flexible / ASAP / date / range); no rate or hours needed to post
- Choose-a-Tradie list + profile-in-context + direct request (fixes the "chosen tradie ignored" bug); Quick match remains as fallback
- Pay at completion; final amount = labour + approved adjustments
- Price adjustments with recorded homeowner approval
- Project jobs: up to 3 concurrent quotes, large-job (NZD 30k+) contract confirmation
- GST-inclusive consumer pricing with `IsGstRegistered`

**Cross-cutting**
- Brand: TradieHunter on every user-facing surface (config-driven `Brand:*`)
- Locale config (NZD, +64, Pacific/Auckland, km), `IPaymentProvider` seam, per-deployment legal entity and payment instructions
- Transactional email system (templated, branded, bounce handling)
- Security hardening (P9) and UI/UX system (v1.5/v1.6 → design system v1.7)

## 3. Core user flow (v1.7, flow version 2)

**Homeowner:** post job → choose tradie (or Quick match) → request sent → tradie accepts → **Booked** (address revealed, chat opens) → work → tradie checks out with final hours → homeowner reviews itemised summary → **Approve & pay** → bank transfer + receipt → staff verify → **Completed** → blind review.

**Tradie:** receive request (amount, distance, countdown) → accept/decline → check in → work, propose extra costs if needed → check out → get paid weekly net of commission.

**Admin:** verify credentials, verify receipts, process payouts, resolve disputes, act on flags.

Flow version 1 (pay before booking) remains for jobs created before the flag flips; see [SPECS §4](SPECS.md#4-job-state-machine).

## 4. Technical decisions

| Decision | Choice |
|---|---|
| Database | PostgreSQL 16 + PostGIS (dev); EF Core + Npgsql + NetTopologySuite; SQL Server swappable. Spatial LINQ only, never raw PostGIS SQL. |
| Blob storage | Azure Blob (Azurite locally); private containers read via short-lived SAS |
| Real-time | SignalR, single hub, Redis backplane |
| Jobs | Hangfire (Redis) |
| Push | Firebase Cloud Messaging via Admin SDK |
| Address | LINZ Data Service behind `IAddressResolver` (server-side key) |
| Payments | `IPaymentProvider` → `ManualReceiptProvider` now; gateway later without state-machine change |
| Money / time | `decimal(18,2)` always; UTC on the wire, localised on the client |

## 5. Explicitly out of scope

In-app card payments / BNZ / Stripe · deposits and escrow · milestone payments (P12-26) · pre-approved materials allowance · pre-booking chat · parallel offers for hourly jobs · invoiced cancellation fees · automated dispute resolution · ML matching · subscriptions for tradies · referrals/promos · nationwide launch · location-based rate variation · minimum job value · calendar sync · multi-language · Facebook/Apple login · portfolio galleries · automated reconciliation.

Escalation triggers recorded earlier: fixed-quote pricing was to be fast-tracked if more than 20% of jobs cancel over pricing disputes (v1.7 delivers quotes for projects); reconsider commission vs subscription if off-platform diversion appears.

## 6. Questionnaire decisions (v1.3, all accepted)

| Area | Decision |
|---|---|
| Rates (A) | Tradie-set hourly rate, one per service; no range; no callout fee; scope-negotiation guidance copy in chat |
| Materials (B) | See §7 — now handled by price adjustments |
| Money (C/D) | Per-job commission, weekly payouts, no promos |
| Catalogue (E) | 6 trades, tradies may serve several, Auckland pilot (guidance, not geo-fence) |
| Posting (F) | No edits after an offer is sent; max 5 photos × 10 MB; no minimum duration |
| Capacity (G) | Multiple active jobs, pause mode (`IsAvailable`) |
| Reviews (H) | Two-way, blind (7-day window), low-rating flag |
| Trust/legal (I) | Licence mandatory for regulated trades, insurance badge, tradie liable, retention policy 7 yrs financial / 2 yrs chat and photos |
| Support (J) | 8am–6pm NZT, 30-min payment SLA, 48 h disputes |
| White-label (K) | Per-deployment legal entity and brand config; English only |

## 7. Superseded decisions

| Earlier decision | Superseded by (2026-11-16, owner sign-off) |
|---|---|
| **A5** hourly-only pricing, timing required | Timing optional; projects use quotes |
| **B1** materials billed off-platform | In-app price adjustments with recorded approval |
| **P4** upfront payment before booking | Pay at completion (payment is the last step) |
| Monetary cancellation penalties and partial refunds | Non-monetary consequences (legacy flow only keeps them) |
| Aha moment measured at `Booked` after payment | Measured at `Booked` on acceptance |
| v1.1 "Won't have: quotes/bidding" | Quotes for Project jobs only |

Everything else in v1.1–v1.3 stands.
