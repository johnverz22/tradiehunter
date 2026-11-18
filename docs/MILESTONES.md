# TradieHunter — Milestones

> One table of what shipped, what is verified, and what is open. Dates come from the original spec files. "Verified" means the source docs record test or device evidence; **this consolidation could not run any code**, so statuses are the repository's own claims as of 2026-11-16.

## Delivered

| Version | Date | Theme | Status |
|---|---|---|---|
| **v1.1** (M0–M5) | Sep 2026 | Scaffold, auth + profiles, job posting + matching, chat + job status, reviews + scheduling, admin + beta | ✅ Done, then superseded by v1.2 domain model |
| **v1.2** (P0–P9) | 28–29 Sep | Manual-payment domain model | ✅ P0–P8 done · P9 mostly done (see open items) |
| **v1.3** (P10–P11) | 1 Oct | Client-questionnaire gaps, payouts, rebrand, compliance | ✅ P10 done · ⏳ P11 not built |
| **v1.4** | 26 Oct | Rebrand to TradieHunter + functional/UI audit (18 findings) | ✅ Implemented |
| **v1.5** | 27–29 Oct | Mobile UI trust, clarity, field usability (26 screen groups, 21 tasks) | ✅ Implemented · device-level acceptance partly open |
| **v1.6** | 29 Oct – 10 Nov | Hierarchy, status clarity, touch targets, iPad; hard-coded value remediation; design system v1.7 | ✅ 26/26 tasks done |
| **v1.7** (P12) | 16 Nov | Job-flow revision: flexible timing, pay-at-completion, price adjustments, tradie browse, projects | 🟡 Code-complete on `dev`; CI verification pending; flag default off |
| **Design v2** | 16 Nov | Mobile design system rebrand: Trust Navy + Gold (Lexend + Source Sans 3). v1.7 archived; v2 AST, tokens, 30 screen stubs and widget library installed at `docs/design/`. Phase 1 (docs restructure) complete. Phases 2–6 (token wiring, component migration, screen migration, CI gate) pending. | 🟡 Phase 1 done · Phases 2–6 pending |

### v1.1 — original milestones (history)
M0 Docker + scaffolds · M1 auth + profiles · M2 job posting + matching · M3 chat + job status · M4 reviews + scheduling · M5 admin + closed beta. The beta plan and E2E happy path were superseded by the QA guide ([QA.md](QA.md)).

### v1.2 — phases P0–P9
| Phase | Delivered |
|---|---|
| P0 | Config extensions, roles + policies, 10-state `JobStatus`, `ReasonCode`, history, central `IJobStatusService`, job field expansion, data migration |
| P1 | Email OTP, Google login, staff invites, tradie onboarding endpoints + mobile wizard, admin credential queue |
| P2 | Service search, rate snapshot, reference codes, revised job request |
| P3 | `JobOffer`, ranking, sequential offers, Hangfire timeout, broadened stage, no-tradie-found terminal path, offer SignalR events |
| P4 | `Payment`, `IPaymentProvider`/`ManualReceiptProvider`, receipt hash, staff review queue, expiry job |
| P5 | Address privacy, check-in/out, reminders, auto-complete, reviews, chat lock until Booked |
| P6 | Cancellation flows, refund suggestion + admin processing queue |
| P7 | Disputes + evidence, no-show reporting, account flags + thresholds, admin dispute/flag UI |
| P8 | Audit log, report/block, private blob + SAS, email fallback for push, expiry service |
| P9 | Auth/security hardening (15 items) |

### v1.3 — phases P10–P11
P10 delivered: commission + payouts + batches, bank details, service catalogue + licence-gated matching, insurance badge, availability toggle, blind reviews, low-rating flag, edit lockout, photo limits, payment SLA indicators, support hours, brand config, rebrand. P11 (retention config, purge jobs, anonymisation) is **specified only**.

### v1.4 — rebrand + audit
Rebrand of user-facing surfaces, platform metadata and backend brand config; 9 functional, 2 test-infrastructure, 4 branding and 3 UI findings fixed. Code identifiers deliberately kept (see [README](README.md#naming-tradiehunter-vs-fixo)).

### v1.5 — mobile UI overhaul
Geometry/typography contract, 4-stage homeowner progress mapped from server states, truthful trust and money presentation, LINZ address search, tradie earnings endpoint, lead countdown + direct accept, shared components, regrouped onboarding, a11y. 18 of 21 tasks complete; V15-15, V15-20 and V15-21 are partial (physical-device maps/tel launch, literal VoiceOver, release sign-off).

### v1.6 — hierarchy and design system
Status pill system, compact progress bar, container language, typography enforcement, ≥48 dp action buttons, lead/match/detail reorders, chat + messages list, iPad master-detail, dark-mode refinement, `FixoNotice` feedback system, shared tradie job card, filter pills, web admin job stepper, ~1,090 hard-coded values replaced with tokens. Baseline: 511 → 607 Flutter tests passing (2026-11-09), `flutter analyze` clean apart from pre-existing infos. **Not visually re-verified on device** after the 2026-11-09 audit run.

### v1.7 — job-flow revision (P12)
27 of 28 tasks code-complete: P12-26 (milestone payments) is deliberately deferred. All eight decisions D1–D8 resolved 2026-11-16 (see [SPECS §11](SPECS.md#11-v17-job-flow-revision-phase-12)). Ships dark behind `JobFlow:Version`.

## Open items

Ordered by launch impact.

| # | Item | Owner/gate |
|---|---|---|
| 1 | **v1.7 verification:** run `dotnet build`, `dotnet test`, `flutter analyze`, `flutter test`, run migration `P12JobFlowV17` dry-run on a copy of the dev DB, run `scripts/p12-smoke.sh`, then QA-14 ([QA.md](QA.md)) | Engineering |
| 2 | Flip `JobFlow:Version` to 2 only after item 1 passes | Engineering + product |
| 3 | **Legal review** before enabling Project jobs in production (Building Act s362F summary is from government guidance, not legal advice) | Legal |
| 4 | Pre-launch compliance checklist ([PRD §8](PRD.md#8-pre-launch-compliance-open)): FSPR, dispute scheme, AML/CFT, trust account, ToS, Privacy Policy | Business + legal |
| 5 | **P11 data lifecycle** (retention config, purge jobs, anonymisation, ToS/Privacy links): spec exists, no code | Engineering |
| 6 | **P9 leftovers:** P9-07 release-build connectivity check, P9-08 release-safe logging, P9-11 FCM routing comment, P9-12 interceptor queue rejection, P9-14 in-memory access token. P9-06 refresh-token rotation is marked done in the spec but "open" in the QA guide: verify and settle. | Engineering |
| 7 | v1.5 device acceptance: physical maps/tel launch, VoiceOver/TalkBack on device, final release sign-off | QA |
| 8 | Visual verification of the 2026-11-09 mobile UI sprint on simulator/device (both themes) | QA |
| 9 | P6 optional notification when a refund becomes `Pending` | Product decision |
| 10 | Email: pick SMTP relay (SES Sydney suggested), publish SPF/DKIM/DMARC, host the logo on the CDN, set `Brand:FrontendBaseUrl` once deep links resolve, supply registered postal address | Infra |
| 11 | Real bank account details in `PaymentOptions` for production (missing/sentinel details correctly show a "support" state) | Business |
| 12 | Admin Playwright spec for payouts (`e2e/payouts.spec.ts`) and mobile integration tests for P10 and v1.7 flows | QA |
| 13 | **Web admin design system v1** is applied to every admin page, dialog and the shell (`web/src`, theme synced from `docs/design/web/`, legacy v1.7 names removed and guarded). Verified by scripts only (lint, build, sync check, legacy guard, design gate). Still manual: Playwright against a live API, frame comparison at 1280/820/390 in light and dark, keyboard and screen-reader walks, `forced-colors` and reduced-motion checks | Engineering + design |

## Conflicts found while consolidating

Resolved in these docs as noted; fix at source if the code disagrees.

| Conflict | Resolution used |
|---|---|
| v1.7 spec header said "implementation not started", README said code-complete, tasks table said IN PROGRESS | Treated as code-complete, unverified (tasks README is the newest) |
| v1.6 `tasks.md` header said "Draft — awaiting review" while all 26 rows were COMPLETE | Treated as complete |
| Sending domain `tradiehunter.co.nz` (MVP v1.3 config sample, ToS URLs) vs `tradiehunter.nz` (email runbook) | Unresolved: confirm the registered domain and align `Brand`/`Locale`/`EmailSender` config |
| .NET namespace written `Fixo.Api` and `FixoApi` | Written as `Fixo*` (project `FixoApi`) |
| Design tokens: v1.6 docs use `DesignTokens`/`FixoTheme`; design bundle rules say `THColors`/`THType` | Both exist in code per the sprint notes; see [DESIGN.md](DESIGN.md#flutter-token-map) |
| Firebase setup guide listed backend/mobile FCM steps as "to do" although push, device tokens and Google login ship | Setup guide trimmed to console steps and verification ([OPERATIONS.md](OPERATIONS.md)) |
| PRD title "Blueprint Marketplace", design bundle "Fixo (product) by TradieHunter (company)" | Product is TradieHunter everywhere |
