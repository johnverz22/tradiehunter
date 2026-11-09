# TradieHunter MVP v1.3 — Gap Resolution & Extended Specification

> **Rebrand note:** "Fixo" remains the internal codename and codebase identifier. All user-facing UI, copy, push notifications, and marketing material use **TradieHunter**. The `--hue` CSS variable and design tokens remain the source of truth for theming. Container names, config keys, and code namespaces keep `Fixo` to avoid a rename-everything migration.

> **Provenance:** This spec resolves the gaps identified in the Client Clarification Questionnaire (Oct 2026). All pre-answers are accepted as agreed — the client has not overridden any. Each section maps back to the questionnaire item (e.g., A1, B2) and notes whether the gap requires new code, a config change, documentation only, or is deferred.

---

## 0. External Verification of Presumptions

Before accepting the questionnaire's pre-answers, each was validated against NZ market research and regulation. The summary below captures findings that **confirm, refine, or flag** the pre-answers.

### Confirmed

| Item | Pre-Answer | External Finding |
|------|-----------|------------------|
| A1 | Tradies set own rate | Confirmed. Builderscrack, BuildAndFix, NoCowboys, Airtasker — all let tradies price their own work. No NZ platform centrally prices trades. |
| A2 | No min/max range for MVP | Confirmed. No NZ competitor enforces rate ranges. |
| A3 | One rate per trade/service | Confirmed. BuildAndFix verification is per-trade; Builderscrack profiles are per-trade. |
| A5 | Hourly-only for MVP | Confirmed viable. Most competitors support quoting, but hourly-only is a valid simplification for an auto-match MVP. Quoting requires a request-quote-accept sub-flow that breaks instant matching. |
| B1 | Materials billed separately, off-platform | Confirmed. Lead-based NZ platforms (Builderscrack, NoCowboys) have no materials handling at all. |
| D1 | Per-job commission only for MVP | Confirmed. Simpler than subscription. Builderscrack moved *away* from commission (success fees) to subscription+tokens due to tradies taking work off-platform; monitor for the same risk. BuildAndFix uses \$50/mo subscription with zero per-job fees. |
| D2 | No promos/referrals in MVP | Confirmed. No NZ competitor offers referral bonuses at launch. |
| E1 | Start with 4–6 high-frequency trades | Confirmed. Standard marketplace launch strategy. |
| E3 | Tradie can serve multiple categories | Confirmed. Already supported by `tradie_rates` (one rate per service). |
| F2 | Max 5 photos, 10 MB each | Reasonable. Competitors vary (Builderscrack allows gallery uploads with no stated limit). 5 × 10 MB is generous for job descriptions. |
| G1 | Multiple active jobs, no cap | Confirmed. No NZ platform caps concurrent jobs. |
| G2 | Vacation/pause mode | Confirmed. Standard feature across platforms. |
| H3 | Two-way reviews | Confirmed beneficial. Builderscrack is one-way (homeowner→tradie). Two-way is better for platform trust. Already in data model (`reviews.from_user`, `reviews.to_user`). |
| K2 | English only at launch | Confirmed. No NZ competitor is multi-language. |

### Refined

| Item | Pre-Answer | Refinement |
|------|-----------|------------|
| A4 | No enforced location-based rate variation | **Confirmed, but note:** some NZ tradies charge travel fees for rural areas. This is handled naturally by their hourly rate; no platform enforces it. |
| C2 | Flat % commission | **Confirmed model, but note competitive risk:** Builderscrack abandoned success fees because tradies took work off-platform. TradieHunter mitigates this by controlling the payment flow (receipt → verify → payout), making off-platform diversion harder. Commission % to be set by client (suggest 10–15% range based on NZ market norms). |
| H1 | Blind reviews | **Confirmed beneficial**, but not standard in NZ. Builderscrack shows reviews immediately. Blind reviews reduce retaliation — keep for MVP. Reveal window: 7 days or when both submit, whichever first. |
| I2 | Trade licence required, insurance optional but badged | **Refined:** For regulated trades (electrical/EWRB, plumbing+gas+drainlaying/PGDB, building/LBP), licence verification should be **required** — it's a legal requirement under the Building Act 2004 and relevant registration boards. For unregulated trades (cleaning, handyman, painting, gardening), no licence exists to verify; insurance badge is the trust signal. BuildAndFix's 5-step verification (NZBN, licensing boards, identity, insurance, compliance) is the gold standard. |

### Flagged (Legal — Must Resolve Before Launch)

| Item | Flag |
|------|------|
| C4 | **Holding customer funds triggers regulatory obligations.** The Financial Service Providers Act 2008 (Section 5) defines "financial service" to include keeping/administering money on behalf of others. The FMC Act 2013 Client Money or Property Services (CMPS) regime may apply. **Requirements before launch:** (1) Register on the FSPR, (2) Join an approved dispute resolution scheme, (3) Comply with AML/CFT Act 2009 if classified as a "financial institution," (4) Maintain trust account separation. Get NZ legal counsel sign-off per deployment country. |
| I1 | **Liability clause needs legal drafting.** Pre-answer (tradie is liable, platform is connector) is the standard marketplace position but must be in properly drafted Terms of Service reviewed by NZ counsel. |
| I3 | **Data retention policy.** Privacy Act 2020 Principle 9 is purpose-based (no fixed period). The 7-year figure comes from the Tax Administration Act 1994 for financial records. Chat/photos: 2 years post-job is reasonable if disclosed in privacy policy. Must be documented and disclosed per Privacy Act requirements. |

---

## 1. Rate Setting & Pricing (A1–A7)

### What Changes

**Already implemented:** `tradie_rates` table (P1-06) lets tradies set one hourly rate per service. Rate snapshot on job creation (P2-03). No changes to the core data model are needed.

**New in v1.3:**

| Change | Scope | Phase |
|--------|-------|-------|
| A6: Add "scope negotiation" guidance copy in chat when job hours seem low for the service | Mobile UI copy | P10 |
| A7: No callout fee — document in tradie onboarding help text | Mobile UI copy | P10 |

### Risk Note: Hourly-Only Pricing

> [!WARNING]
> External research indicates hourly-only pricing works well for standardized/small trades (handyman, cleaning, emergency callouts) but NZ homeowners resist open-ended hourly billing for larger projects (building, decking, painting). Competitors (Builderscrack, BuildAndFix) are quote-based. **Hourly-only is accepted for MVP per A5**, but monitor early user feedback closely. If tradie or homeowner adoption stalls, quote pricing should be fast-tracked to V1.1.

### What's Deferred (V1.1)
- Rate ranges / min-max enforcement (A2 — only if abuse detected)
- Fixed-quote pricing flow (A5) — **priority escalation trigger: if >20% of jobs are cancelled due to pricing disputes**
- Location-based rate variation (A4)
- Separate callout/diagnostic fee (A7)

---

## 2. Materials & Scope Changes (B1–B4)

### What Changes

Materials are off-platform for MVP. The spec gap was that nothing in the existing system communicates this to users.

**New in v1.3:**

| Change | Scope | Phase |
|--------|-------|-------|
| B1: Add "Materials not included" disclaimer on job detail and payment screens | Mobile UI copy, backend `GET /api/config/locale` extended with `materialsDisclaimer` field | P10 |
| B3: "Scope change" chat prompt — if tradie sends a message containing cost-related keywords during InProgress, surface a reminder that homeowner must approve changes | Mobile UI pattern (not enforcement) | P10 |
| B4: No cap logic — every increase via chat approval | Documentation only | — |

### What's Deferred (V1.1)
- In-app materials itemization and homeowner approval flow (B2)
- Automated scope-change approval workflow with cost adjustment

---

## 3. Payments & Tradie Payouts (C1–C4)

### What Changes

The existing spec covers homeowner→admin payment (P4) and refunds (P6) but has **no tradie payout model**. This is the largest gap.

**New in v1.3:**

#### 3.1 Commission Model (C2, D1)

| Field | Value |
|-------|-------|
| Model | Per-job commission (flat %) |
| Default rate | Configurable via `PayoutOptions:CommissionPercent` (suggest 12.5% initial) |
| Applied to | `TotalAmount` of completed jobs |
| Visible to tradie | Yes — shown as "Platform fee" on job detail after completion |

#### 3.2 Payout Tracking (C1, C3)

New `tradie_payouts` table:

| Column | Type | Notes |
|--------|------|-------|
| `Id` | Guid | PK |
| `TradieId` | Guid | FK → users |
| `JobId` | Guid | FK → jobs |
| `GrossAmount` | decimal | `TotalAmount` from job |
| `CommissionAmount` | decimal | `GrossAmount × CommissionPercent` |
| `NetAmount` | decimal | `GrossAmount − CommissionAmount` |
| `Status` | string | `Pending`, `Scheduled`, `Processed`, `Failed` |
| `PayoutBatchId` | Guid? | Links to weekly batch |
| `BankAccountName` | string | From tradie profile |
| `BankAccountNumber` | string | From tradie profile (encrypted at rest) |
| `TransferReference` | string | Admin fills on processing |
| `ProcessedBy` | Guid? | Admin who processed |
| `ProcessedAtUtc` | DateTime? | |
| `CreatedAtUtc` | DateTime | Set on job completion |

New `payout_batches` table:

| Column | Type | Notes |
|--------|------|-------|
| `Id` | Guid | PK |
| `PeriodStart` | DateTime | Monday 00:00 UTC |
| `PeriodEnd` | DateTime | Sunday 23:59 UTC |
| `TotalAmount` | decimal | Sum of net amounts |
| `PayoutCount` | int | Number of payouts in batch |
| `Status` | string | `Open`, `Processing`, `Completed` |
| `CreatedAtUtc` | DateTime | |
| `CompletedAtUtc` | DateTime? | |

#### 3.3 Payout Flow

1. Job reaches `Completed` → system creates a `tradie_payout` record with status `Pending`, calculates commission.
2. Hangfire weekly batch job (configurable day, default Monday) collects all `Pending` payouts, creates a `payout_batch`, sets payouts to `Scheduled`.
3. Admin reviews batch in web dashboard → processes each payout (bank transfer) → marks as `Processed` with reference.
4. Tradie receives push notification when payout is processed.

#### 3.4 Tradie Bank Details (Profile Extension)

Add to `tradie_profiles`:
- `BankAccountName` (string, encrypted)
- `BankAccountNumber` (string, encrypted)
- `BankAccountVerified` (bool, default false)

Collected during onboarding wizard Step 1 (profile), required before first job can complete.

#### 3.5 Configuration

Add to `appsettings.json`:

```json
{
  "PayoutOptions": {
    "CommissionPercent": 12.5,
    "PayoutDay": "Monday",
    "MinimumPayoutAmount": 0,
    "PayoutBatchCron": "0 2 * * 1"
  }
}
```

#### 3.6 Admin Payout Queue (Web)

New admin pages:
- **Payout Queue** (`/payouts`): List pending/scheduled payouts grouped by batch
- **Batch Detail** (`/payouts/batches/{id}`): Individual payouts with "Mark Processed" action
- Each row shows: tradie name, job reference, gross, commission, net, bank details (masked except last 4), status

---

## 4. Service Categories & Geography (E1–E3)

### What Changes

**Already implemented:** `services` table with `Name` and `Category` (P1-01). Tradies register for services with rates (P1-06).

**New in v1.3:**

#### 4.1 Seed Service Catalog (E1)

Initial 6 categories for NZ pilot:

| Category | Services | Licence Required |
|----------|----------|-----------------|
| Plumbing | General plumbing, Hot water systems, Drain unblocking | Yes (PGDB) |
| Electrical | General electrical, Lighting, Switchboard | Yes (EWRB) |
| Building | Carpentry, Decking, Fencing, Minor renovations | Yes (LBP) for restricted work |
| Handyman | General repairs, Furniture assembly, Shelving, Odd jobs | No |
| Cleaning | House cleaning, End-of-tenancy, Window cleaning | No |
| Painting | Interior painting, Exterior painting, Wallpapering | No |

Add `RequiresLicence` (bool) and `LicenceBoard` (string, nullable — e.g., "EWRB", "PGDB", "LBP") to the `services` table. Matching service will require verified credentials for services where `RequiresLicence == true`.

#### 4.2 Pilot Region (E2)

Configuration-driven via `Locale` section. Add:

```json
{
  "Locale": {
    "PilotRegion": "Auckland",
    "MaxSearchRadiusKm": 50,
    "DefaultSearchRadiusKm": 25
  }
}
```

No geo-fencing enforcement in MVP — the pilot region is operational guidance, not a hard boundary.

---

## 5. Job Posting & Editing Rules (F1–F3)

### What Changes

**New in v1.3:**

| Rule | Implementation | Phase |
|------|---------------|-------|
| F1: No editing after offer sent | Backend: reject `PUT /api/jobs/{id}` when `JobStatus >= Requested` and offers exist. Mobile: hide edit button once matching starts. | P10 |
| F2: Photo limit enforcement | Backend: `CreateJobRequestValidator` — max 5 files, each ≤ 10 MB. Already partially enforced by blob upload; formalize in validator. | P10 |
| F3: No minimum job duration | No code change. Document in spec. Monitor analytics for low-value spam. | — |

---

## 6. Tradie Capacity & Availability (G1–G2)

### What Changes

**G1 — Multiple active jobs:** Already supported. No cap in matching logic.

**G2 — Vacation/pause mode:**

**Already partially implemented:** `TradieProfile.IsVerified` gates matching. But there's no explicit "available/unavailable" toggle independent of verification.

**New in v1.3:**

Add `IsAvailable` (bool, default `true`) to `tradie_profiles`. When `false`:
- Tradie excluded from matching (alongside `IsVerified` check)
- Dashboard shows "You're offline — toggle to receive new jobs"
- Existing active jobs are unaffected

Toggle endpoint: `POST /api/profile/availability` with `{ "available": true/false }`.

Mobile: Toggle switch on tradie dashboard header.

---

## 7. Ratings & Reviews (H1–H3)

### What Changes

**Already implemented:** `reviews` table with `from_user`, `to_user`, `stars`, `comment`, `status` (P5-05). Review prompt on completion (P5-07). Two-way reviews already in the data model.

**New in v1.3:**

#### 7.1 Blind Review Window (H1)

> [!TIP]
> **Competitive differentiator:** No NZ competitor (Builderscrack, NoCowboys, BuildAndFix) offers blind two-way reviews. Builderscrack is one-way (homeowner→tradie) with immediate visibility. Tradies universally complain about retaliatory reviews and homeowners using ratings as leverage. Blind two-way reviews are TradieHunter's strongest trust signal for tradie acquisition.

Reviews are hidden until **both** parties submit or **7 days** elapse after job completion, whichever comes first.

| Change | Detail |
|--------|--------|
| Backend | Add `VisibleAfterUtc` computed field on review creation: `min(both_submitted_at, completed_at + 7d)`. `GET /api/jobs/{id}/reviews` returns reviews with `isVisible: false` (stars/comment redacted) until the window opens. |
| Mobile | Show "Your review has been submitted. It will be visible once [the other party also reviews / 7 days pass]." |
| Hangfire | Schedule a `RevealReviewsJob` 7 days after completion to flip visibility and notify both parties. |

#### 7.2 Two-Way Reviews Confirmed (H3)

Already in data model. Ensure:
- Tradie review of homeowner is collected on the same completion flow
- Tradie-side review modal includes: star rating (1–5), comment (optional)
- Homeowner profile shows aggregate rating from tradies (visible to tradies only on job detail, not to other homeowners)

#### 7.3 Low-Rating Admin Flag (H2)

When a user's average rating drops below 3.0 (after ≥3 reviews), create an `AccountFlag` of type `LowRating`. No auto-suspension — admin reviews.

Add `LowRating` to the `AccountFlagType` enum.

---

## 8. Legal, Liability & Verification (I1–I3)

### What Changes

These are primarily documentation and operational items, not code.

| Item | Action | Owner |
|------|--------|-------|
| I1 | Draft Terms of Service with liability clause (platform = connector, tradie = liable for work). **Must be reviewed by NZ lawyer.** | Legal + Product |
| I2 | Licence verification already in P1. **New:** For services with `RequiresLicence == true`, credential upload is **mandatory** before tradie can be matched to those services. Insurance upload is optional but earns an "Insured" badge. | P10 (backend + mobile) |
| I3 | Implement data retention policy: financial records 7 years (Tax Administration Act), chat/photos 2 years post-completion. Add `RetentionPolicy` config section. Hangfire job to purge expired data. | P11 |

#### 8.1 Insurance Badge

Add `CredentialType.Insurance` to the credential type enum. When approved by admin:
- `TradieProfile.HasInsurance = true`
- Badge shown on tradie cards in search results and job detail

#### 8.2 Licence-Gated Matching

Extend matching service: for jobs where the selected service has `RequiresLicence == true`, only match tradies who have an `Approved` credential of the matching `LicenceBoard` type.

---

## 9. Support & Operations (J1–J2)

### What Changes

| Item | Action | Phase |
|------|--------|-------|
| J1 | Target < 30 min payment verification during business hours. **Implementation:** Admin dashboard shows time-since-submission on payment queue; items > 15 min get amber highlight, > 30 min get red. Hangfire escalation notification to admin after 30 min. | P10 |
| J2 | Support hours 8am–6pm NZT, 48h dispute resolution target. **Implementation:** Display support hours on dispute screen. Admin dispute queue shows age badge. No automated SLA enforcement in MVP. | P10 |

---

## 10. White-Label & Localization (K1–K2)

### What Changes

**Already implemented:** Locale config (currency, phone, timezone), `IPaymentProvider` abstraction, per-deployment payment instructions.

**New in v1.3:**

#### 10.1 Per-Deployment Legal Entity (K1)

Add to `Locale` config:

```json
{
  "Locale": {
    "LegalEntityName": "TradieHunter Ltd",
    "LegalEntityCountry": "NZ",
    "TermsOfServiceUrl": "https://tradiehunter.co.nz/terms",
    "PrivacyPolicyUrl": "https://tradiehunter.co.nz/privacy"
  }
}
```

Surfaced via `GET /api/config/locale` for mobile/web to display in footers and onboarding.

#### 10.2 Brand Configuration

Add to existing config:

```json
{
  "Brand": {
    "AppName": "TradieHunter",
    "SupportEmail": "support@tradiehunter.co.nz",
    "SupportHoursDisplay": "8am – 6pm NZT, Mon–Fri"
  }
}
```

All push notification titles, email subjects, and in-app copy read from `Brand:AppName` rather than hardcoding.

---

## 11. TradieHunter Rebrand (UI)

### Scope

The rebrand from "Fixo" to "TradieHunter" affects user-facing surfaces only:

| Surface | Change |
|---------|--------|
| **Mobile — Splash/Onboarding** | Replace "Fixo" text and logo with "TradieHunter" |
| **Mobile — App bar / headers** | App name reads "TradieHunter" |
| **Mobile — Push notifications** | Title prefix "TradieHunter:" |
| **Web admin — Header/sidebar** | "TradieHunter Admin" |
| **Email templates** | "TradieHunter" in subject and body |
| **Config** | `Brand:AppName = "TradieHunter"` drives all dynamic references |

### What Does NOT Change

- Docker container names (`api`, `postgres`, etc.)
- Namespace (`Fixo.Api`, `Fixo.Models`)
- Database name (`fixo`)
- Blob container names (`fixo-photos`, `fixo-credentials`, `fixo-payments`)
- CSS variable (`--hue`) — same design system, different brand name
- Internal documentation and `AGENTS.md`

---

## 12. Implementation Phases (v1.3)

All v1.3 changes are organized into two new phases, appended after the existing P0–P9:

### Phase 10: Gap Resolution — Business Rules & UI

Covers: Rate setting UI copy (A6–A7), materials disclaimer (B1), scope change chat guidance (B3), commission model + payout tracking (C1–C3), service catalog seed + licence gating (E1, I2), job editing lockout (F1), photo limits (F2), tradie availability toggle (G2), blind reviews (H1), two-way review UI (H3), low-rating flags (H2), insurance badge (I2), payment queue SLA indicators (J1), support hours display (J2), brand config + rebrand (K1–K2, §11).

### Phase 11: Compliance & Data Lifecycle

Covers: Data retention policy implementation (I3), Hangfire purge jobs, per-deployment legal entity config (K1), Terms of Service / Privacy Policy link surfacing.

---

## 13. Deferred to V1.1+

| Feature | Questionnaire Item | Reason |
|---------|-------------------|--------|
| Fixed-quote pricing | A5, A6 | Breaks instant match flow; needs quote sub-workflow |
| Rate min/max ranges | A2 | Only if abuse detected |
| In-app materials tracking | B2 | Scope management flow required |
| Automated scope-change approval | B3, B4 | Needs pricing adjustment workflow |
| Payment gateway (BNZ/Stripe) | C4 | Deferred per original spec |
| Subscription model for tradies | D1 | May replace commission if off-platform risk detected |
| Promotional credits / referral incentives | D2 | Growth phase |
| Nationwide expansion | E2 | After pilot validation |
| Location-based rate variation | A4 | After multi-region launch |
| Minimum job value | F3 | After spam monitoring |
| Automated dispute resolution | Existing deferral | V1.1+ |
| ML-based matching | Existing deferral | V1.1+ |
| Multi-language support | K2 | After NZ pilot |

---

## 14. Success Metrics (Updated)

| Metric | Target | New in v1.3 |
|--------|--------|-------------|
| Activation rate | ≥ 30% post job within 24h | — |
| Match-to-AwaitingPayment time | ≤ 15 min median | — |
| Payment verification time | ≤ 30 min during business hours | ✓ |
| Tradie response rate | ≥ 60% accept/decline within offer window | — |
| Review completion rate | ≥ 50% both parties review | — |
| **Payout processing time** | ≤ 3 business days from batch creation | ✓ |
| **Commission collection rate** | 100% of completed jobs | ✓ |
| **Dispute resolution time** | ≤ 48h from opening | ✓ |

---

## 15. Compliance Checklist (Pre-Launch)

- [ ] FSPR registration for entity holding customer funds (C4)
- [ ] Approved dispute resolution scheme membership (C4)
- [ ] AML/CFT assessment — determine if "financial institution" classification applies
- [ ] Terms of Service reviewed by NZ lawyer (I1)
- [ ] Privacy Policy drafted per Privacy Act 2020 (I3)
- [ ] Data retention schedule documented and disclosed (I3)
- [ ] Trust account separation for customer funds (C4)
- [ ] Per-country legal entity assessment for white-label deployments (K1)

---

*This spec extends [MVP-SPEC-v1.2](MVP-SPEC-v1.2.md). All existing v1.2 phases (P0–P9) remain unchanged. v1.3 adds P10–P11.*
