# TradieHunter — Product Requirements

> **Status:** current through v1.7 (2026-11-16). Final product decisions only; build scope is in [MVP.md](MVP.md), behaviour in [SPECS.md](SPECS.md).
> **Naming:** the product was developed as *Fixo* and rebranded to **TradieHunter** in v1.3/v1.4. See [README](README.md#naming-tradiehunter-vs-fixo) for why code identifiers still say `Fixo`.

## 1. Problem

NZ homeowners struggle to find reliable tradies for repairs and renovations: pricing is opaque, availability is uncertain, and work quality is a worry. Tradies get inconsistent work, slow payment and unqualified leads. TradieHunter connects the two with transparent rates, fast matching, in-app chat, platform-mediated payment and reviews, with an admin team keeping the marketplace trustworthy.

**Goal:** a confirmed, named, rated tradie committed to a job in minutes, not days (the "Aha!" moment), then a clean path to completion, payment and review.

## 2. Personas

| Persona | Pain points | Goals |
|---|---|---|
| **Homeowner** — Sarah Thompson, 38, marketing manager, Auckland | Opaque pricing, slow urgent repairs, doubts about quality | Qualified tradies fast, clear rate and payment terms, accountability |
| **Tradie** — James Wilson, 45, licensed electrician, Wellington | Inconsistent work, late payment, juggling clients | Steady nearby leads, getting paid, building a reputation |
| **Admin/Staff** — Emily Carter, 32, platform admin, Christchurch | Disputes, cancellations, compliance, monitoring | Smooth platform, fast and fair resolution |

Mental models: Sarah thinks "book an Uber" (describe once, see price and rating, commit). James treats the app as a lead and cash-flow tool, not a social network; his trust threshold is payment certainty more than UI polish.

## 3. Market position (NZ)

| Competitor | Model | Gap we exploit |
|---|---|---|
| Builderscrack | Post a job, tradies quote, homeowner picks; pays tradie directly at the end | "Post and wait": no instant matching; tradies funded by lead fees |
| Tradee | Uber-style, consumer-friendly, in-app payment (~6% fee) | Closest analogue to our direct-match vision |
| Houzz NZ | Inspiration/portfolio led | Heavier than a task-led MVP needs |
| BuildAndFix / NoCowboys / Airtasker | Verification-led or escrow-led | Confirms tradies set their own rates; none offer blind two-way reviews |

Differentiators: instant rule-based matching, platform-mediated payment (hard to take off-platform), **blind two-way reviews** (reduces retaliation), licence-gated matching for regulated trades.

## 4. Product principles

1. One-tap job description, not a form: structured chips over free text.
2. Progressive trust disclosure: rating, rate, verified/insured badges at the decision point, never fabricated.
3. Status-first navigation: home shows what is happening with active jobs, not a browse feed.
4. Low-friction reciprocity: every homeowner action creates a minimum-effort tradie action (accept/decline).
5. Visible accountability loop: reviews, cancellation history and response stats surfaced where decisions are made.

## 5. Capabilities

Status as of v1.7. ✅ shipped · 🟡 shipped behind a flag / pending verification · ⏳ deferred.

| # | Capability | Status |
|---|---|---|
| 1 | Registration/login (email+OTP, Google), roles Homeowner / Tradie / Staff / Superadmin | ✅ |
| 2 | Tradie onboarding: profile, trades, rates, schedule, licence/insurance credentials, bank details; admin credential verification | ✅ |
| 3 | Job posting with address search (LINZ), photos, timing, urgency | ✅ (v1.7 flow 🟡) |
| 4 | Matching: rule-based ranking, sequential offers with timeouts, broadened radius, licence gating | ✅ |
| 5 | Tradie browse + profile + direct request (homeowner picks the tradie) | 🟡 v1.7 |
| 6 | Transparent pricing: tradie hourly rate snapshotted on the job; GST-inclusive consumer prices | ✅ / 🟡 v1.7 |
| 7 | In-app chat (job-scoped, from Booked) and push (FCM) | ✅ |
| 8 | Manual payment: bank transfer + receipt + admin verification; tradie payouts net of commission | ✅ |
| 9 | Pay-at-completion with on-demand, approval-recorded price adjustments | 🟡 v1.7 |
| 10 | Project jobs with up to 3 concurrent quotes and large-job contract guardrail | 🟡 v1.7 |
| 11 | Scheduling, reminders, check-in/out, auto-confirm | ✅ |
| 12 | Blind two-way reviews, low-rating flags | ✅ |
| 13 | Cancellations, no-shows, disputes with evidence, account flags, block/report | ✅ |
| 14 | Admin web: users, credentials, payments, refunds, payouts, disputes, flags, audit log | ✅ |
| 15 | Data retention, purge and anonymisation | ⏳ specified, not built |
| 16 | In-app card/BNZ payments, milestone payments, ML ranking, referrals, multi-language | ⏳ out of scope |

## 6. Business rules (decisions of record)

- **Pricing:** tradies set their own hourly rate per service; no platform range, no callout fee. Rate is snapshotted on the job so later edits don't change bookings. Homeowner-facing prices are final and GST-inclusive where the tradie is GST-registered ("Incl. GST" / "No GST charged").
- **Payment (v1.7):** homeowner pays **after** work is approved, by bank transfer to the platform; staff verify the receipt; payout to the tradie follows. No deposits and no in-app card payments until an automated gateway exists.
- **Commission:** flat percentage per completed job (default 12.5%, config), shown to tradies only, applied to labour by default.
- **Materials / extras:** added in-app as price adjustments, each needing the homeowner's explicit recorded approval before it can be billed. No pre-approved allowances.
- **Cancellations:** non-monetary consequences only under the v1.7 flow (strike counters, account flags, suspension, reliability score). No invoiced fees.
- **Reviews:** two-way and blind; revealed when both submit or 7 days after completion. Average below 3.0 after 3+ reviews raises an admin flag (no auto-suspension).
- **Trust:** licence upload is mandatory for regulated trades (plumbing/gas/drainlaying, electrical, restricted building work); insurance is optional but badged.
- **Capacity:** tradies may hold several active jobs and may pause availability. Max 5 photos × 10 MB per hourly job.
- **Service catalogue (NZ pilot, Auckland):** Plumbing, Electrical, Building, Handyman, Cleaning, Painting. English only.
- **Support:** 8am–6pm NZT; target payment verification under 30 min in business hours; dispute resolution target 48 h.
- **Liability:** platform connects; tradie is liable for the work. Terms of Service need NZ legal drafting.

## 7. Success metrics

| Metric | Target |
|---|---|
| Activation (homeowner posts within 24h of signup) | ≥ 30% |
| Request → booked time (median) | ≤ 15 min |
| Tradie response rate within offer window | ≥ 60% |
| Payment verification time (business hours) | ≤ 30 min |
| Review completion (both parties) | ≥ 50% |
| Payout processing | ≤ 3 business days from batch creation |
| Commission collection | 100% of completed jobs |
| Dispute resolution | ≤ 48 h from opening |

## 8. Pre-launch compliance (open)

Holding customer funds engages NZ financial-services rules. Before launch: FSPR registration, approved dispute-resolution scheme, AML/CFT assessment, trust-account separation, NZ-lawyer-reviewed Terms of Service and Privacy Policy, a documented and disclosed data-retention schedule, per-country legal-entity review for white-label deployments, and legal review before enabling project jobs in production (large-job contract rules). None of this is code-complete; see [MILESTONES](MILESTONES.md#open-items).
