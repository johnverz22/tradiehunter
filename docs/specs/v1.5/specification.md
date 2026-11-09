# v1.5 — Mobile UI trust, clarity, and field usability

**Date:** 2026-10-27  
**Status:** Execution authorized by user in logical groups; functional decision gates remain applicable  
**Deliverables:** This product/design specification, [implementation plan](implementation-plan.md), and [tasks](tasks.md).

## 1. Purpose and evidence

Turn the supplied TradieHunter screenshot audit into a coherent redesign of the existing single Flutter app, with role-based homeowner and tradie views. Priorities are truthful identity/payment information, readable outdoor UI, a clear next action, and faster lead handling. This is not a new marketplace workflow or a second client.

The supplied audit is the source of reported visual findings, not proof that every issue is still present. Repository inspection checked scope documents, routes, tokens, models, and selected screens; no runtime/screenshot re-audit was performed for this specification. Reproduce findings before fixing them, especially profile ownership and placeholder identity issues previously addressed by v1.4.

### Sources and precedence

- `../../PRD.md`, `../../MVP-SPEC-v1.1.md`, `../../MVP-SPEC-v1.2.md`, `../../MVP-SPEC-v1.3.md`, and `../../ARCHITECTURE.md` govern product and technical behavior. The unversioned `docs/MVP-SPEC.md` referenced by rules is absent in this working tree; use the versioned progression, with later explicit amendments taking precedence.
- `../v1.4/` is the prior rebrand/functional audit, not evidence that all new recommendations are implemented. Its blanket payment/dispute exclusion is not carried forward: manual payment/dispute flows exist in v1.2/v1.3 and current code.
- The supplied audit and this v1.5 specification guide UI improvement and consistency. Existing mockups are explicitly excluded: do not use them as layout/acceptance constraints, update them, or create replacement mockups for this work. This user-directed exception supersedes mockup-matching instructions for v1.5 only.
- `../../design/design-system.html` and `mobile/lib/theme/` remain the palette/token baseline, not a requirement to preserve inconsistent geometry or layouts. Implement the v1.5 component contract while retaining the established functional behavior, architecture and safeguards in `mobile/AGENTS.md`. Repository paths in these documents are root-relative unless a Markdown link states otherwise.
- The audit claims 36 screens, but its subtotal is 6 + 18 + 13 = 37. Its redesign list contains 26 groups with multiple states/screens inside some groups. Coverage below uses those 26 groups; do not invent a screenshot inventory or equate groups to captures.

### Intended outcomes

1. Homeowners can identify their tradie, understand the amount due, and locate their next action without opening unrelated screens.
2. Tradies see amount, location/distance, schedule, and time remaining before responding to a lead.
3. All actionable controls are operable with 48 logical-pixel targets; all text is legible in both themes.
4. Screens share consistent geometry, hierarchy, headers, and navigation without changing server state semantics.

## 2. Scope and decision gates

### Included

Shared/auth/onboarding, homeowner posting/matching/jobs/payment/dispute/profile, tradie leads/jobs/onboarding/profile, shared chat/messages/settings, reusable components, accessibility, realistic test fixtures, and regression coverage. Small additive API read-model changes are permitted only after a contract review proves existing payloads insufficient. Preserve admin operations; no admin redesign.

### Excluded

Fixed quotes or bidding, payment gateways/BNZ, automated reconciliation/refunds/disputes, ML matching, loyalty/referrals, calendar sync, a new notes/checklist persistence system, direct booking that bypasses sequential offers, and manufactured portfolio/trust metrics. Existing manual receipts, human payment review, payouts, and disputes remain supported.

### Visual direction and remaining functional decisions

D1/D2 are settled implementation directions for the UI-consistency goal, not blockers requiring mockup alignment. D3–D7 require decisions only where a provider, data contract, permission or functional change is actually needed; independent visual improvements should proceed without waiting for optional enrichment.

| Decision | Direction | Status / restriction |
|---|---|---|
| D1 Geometry and headers | Adopt 20px cards, 14px buttons/inputs, 28px sheet tops, and flat operational headers; preserve splash gradient | Settled v1.5 direction. Replace the legacy 4px default where specified, centralize tokens and update relevant token/rule documentation. Do not reference or update mockups. |
| D2 Typography | Adopt audit size/weight hierarchy; retain Space Grotesk display + IBM Plex Sans body for this iteration | Settled baseline. Remove mono from ordinary UI. Inter remains an optional separately approved font change, not a prerequisite to making the UI consistent. |
| D3 Address resolution | Service → address search/selection, resolved coordinates hidden from users | User selected LINZ with a replaceable provider interface and confirmed an existing LDS API key. Backend IAddressResolver and provider-neutral address search contract keep Flutter independent of LINZ WFS. Keys stay server-side; search text is sent to LINZ. No new dependency approved or added. Typed addresses never manufacture coordinates. Server key configuration and authenticated current-layer/schema/coverage plus real app/posting-payload checks are verified. Successful matching-offer and visual/device acceptance remain open; one approved test job reached the existing no-eligible-candidate cancellation outcome. Future providers require their own privacy, billing, retention and attribution review. |
| D4 Financial copy/data | Separate job gross amount, estimated tradie net, earned net, and processed payout | Settled for the tradie weekly summary: Pacific/Auckland Monday-start week; separate earned net (payouts created), processed net (payouts processed), pending (all-time outstanding) and failed — via `GET /api/tradie/earnings`, server-computed decimals. Never label gross bookings as paid earnings. Legal/product approval still required before any claim about holding or protecting funds; other screens' copy decisions remain open. |
| D5 Profile actions | Request starts the existing eligible service/job flow; Message uses an authorized job conversation | No arbitrary direct messages or guaranteed preferred-tradie assignment. “See other options” must use existing permitted rematch/selection behavior or be omitted pending product approval. |
| D6 Enrichment and external actions | Show only supported photo, jobs completed, response time, years, licence, map, call, navigation fields | Inventory payloads and permissions first. Unknown values are omitted or explicitly unavailable, not zero or fabricated. New map/launcher packages require approval. Do not expose private contact/address data before policy permits. |
| D7 Tradie wizard | Proposed sections: Where you work / Trades / Verification / Payout | Current wizard also collects rates, schedule and bank details. Approve regrouping only if every required field and save/validation behavior survives. Do not remove required onboarding data for visual symmetry. |

## 3. Global design contract (UX-01)

All dimensions are Flutter logical pixels. Fixed heights are minimums and may grow for accessibility. Shared rules apply to every screen below, in light and dark mode.

### Palette and typography

- Preserve `DesignTokens.hue = 209`, its derived brand palette, amber `#E38B29`, warm paper, existing neutral/blue/peach treatments. The audit's approximate navy `#1F3A5F` is descriptive, not a replacement hex value. No new brand hues or hardcoded screen colors.
- Primary foreground uses `DesignTokens.onAmber`. Tints must be measured after compositing over each theme's surface. Text contrast ≥4.5:1, including captions/status labels; meaningful control boundaries/icons ≥3:1. Never rely on hue alone.
- Existing red/green semantic tokens may remain for their established error/success uses; new status designs should use navy/amber/tints rather than broaden the audit palette.
- H1 28/700 (26 allowed where necessary), H2 20/600, card title 18/600 (two lines), body 16/400, secondary 14/400, caption minimum 12/500, labels 13/500. Key amount 24/700; payment hero 32/700.
- Mono only for reference codes; tabular digits for amounts/timers are allowed without changing the body font. Greeting must not overpower amount, status, or next action.

### Geometry, spacing, and interaction

- Page margin 20; section spacing 24–32; card gap 12; card padding 16–20; inner gaps 8/12. Use the existing 4px token scale to compose an 8pt rhythm with intentional 12/20 exceptions.
- Cards 20 radius, 1px neutral border, soft navy shadow equivalent to `0 2px 8px` at 8%. In dark mode use existing elevated surfaces and visible borders, not white cards or heavy shadows.
- Primary CTA ≥56 high, radius 14, label 17/600, amber/dark foreground. Secondary ≥52, navy/theme-adapted outline 1.5px. Decline is a live outlined action, not a faded disabled label; paired action ratio 1:2 where width permits, stacked otherwise. Real disabled states have semantic disabled behavior.
- Inputs ≥56, radius 14, 1.5px neutral outline/focused brand outline, persistent label, 16px value, regular-font helper. Error text is specific, associated semantically, and preserves entered data.
- Chips/badges 28–32 visual height, pill shape, 13/600. Interactive chips use a ≥48 target with adequate separation; decorative badges need no tap behavior.
- Equal-height two-column information tiles, radius 16, 12px caption and 17/600 value. Address wraps; emphasized price can span both columns at 22/700. Collapse to one column when text scaling/width requires it.
- Icon family: consistent rounded-outline Material icons already available, 24 visual size (26 nav), filled active tab only. Every tappable icon ≥48 target with meaningful label/tooltip.
- Standard operational header is flat theme paper/subtle brand tint with clear title and high-contrast back/overflow controls. Splash may retain its branded gradient. Onboarding retains illustration/background language without blurred title surfaces.
- Bottom action region respects SafeArea and keyboard, has 16–20 side margins, ≥16 bottom padding before safe inset, subtle top shadow (`0 -4px 16px` at 10%), and enough scroll padding that no content is hidden. Primary actions should be reachable in the lower 40% at the reference sizes where practical.
- Nav ≥64 high plus safe area, 12px labels. Homeowner: Home / Jobs / raised Post job / Messages / Profile. Center Post is filled amber, 56 diameter, raised 8. Tradie: Dashboard / Jobs / Messages / Profile; no empty center placeholder or homeowner posting action. Settings remains discoverable from Profile via a ≥48 control.
- Support 320px narrow width, homeowner 393×852, tradie 430×932, large 6.9-inch-class devices, landscape/keyboard, and text scale 1.0–2.0 without clipped actions. Screen-reader reading order follows title → status → content → action. Respect reduced motion and avoid per-second timer announcements.

### Common components

Use one job-card structure: two-line title → service/location line → identity where relevant → bold right-aligned amount → human status → one explicit next-action row. Remove stacked metadata chip collections. A lead card is a purposeful variant, not a competing card system.

Provide reusable identity/rating block, four-stage progress, equal info grid, countdown, price breakdown, sticky action bar, grouped setting row, photo grid, and cancellation disclosure. Reuse `ModernJobCard`, `CustomBottomNavBar`, and existing widgets rather than creating parallel design systems.

## 4. State, trust, and money contracts

### UX-02: Four-stage homeowner presentation, unchanged server state machine

| Server state | Progress presentation | Current label and next action |
|---|---|---|
| Requested | Requested (1/4) | Searching/contacting, driven by actual offer state; view matching |
| AwaitingPayment | Requested (1/4) | Payment required; Pay [amount] |
| PaymentReview | Requested (1/4) | Receipt under review; View payment status |
| Booked | Booked (2/4) | Scheduled date/time; Open chat |
| InProgress | In progress (3/4) | Work underway; Open chat |
| AwaitingConfirmation | In progress (3/4) | Awaiting your confirmation; Review and confirm completion |
| Completed | Done (4/4) | Review only when eligible under existing blind-review rules |
| Cancelled / Expired | Terminal banner, not Done | Clear reason and permitted retry/repost action |
| Disputed | Distinct dispute banner; no fabricated progress | View dispute; retain history/last known progress only if provided |

Display four labels without truncation and “Step N of 4 · [stage]” plus the specific current-state label. On narrow layouts show the current label and accessible full sequence, not six unreadable labels. Future stages are distinguishable from disabled controls. Unknown states use a neutral “Status unavailable” and safe refresh, never completion. Centralize display mapping; do not rewrite wire enums or derive permission solely from stage index.

Every actual transition retains existing authorization and server rules, history, and SignalR publication. A direct Accept uses the same offer command as request detail. Disable duplicate submission; stale/expired offers refresh with a clear outcome. Countdown uses server `expiresAtUtc`, clamps to zero, refreshes on resume/reconnect, and never extends the server deadline.

### UX-03: Truthful trust and financial presentation

- Verified/Insured appear only with affirmative server evidence; missing/rejected/expired evidence never earns a badge. Use actual display name and permitted photo; initials fallback is acceptable. Never use “Tradie Verified” as a stand-in name.
- Zero published reviews renders “New to TradieHunter”, not 0.0 stars. Preserve blind-review visibility/eligibility; no “Leave a review” action on self-profile or without a qualifying job. Unknown review count is not zero.
- Show hours × the snapshotted hourly rate and authoritative total. Materials disclaimer comes from config. Do not add a homeowner platform surcharge just because commission exists: v1.3 commission is deducted from tradie payout. Itemize additional fees only if the server actually charges them.
- Pre-match range requires real returned rates and stated hours; otherwise show “Choose a rate to see your estimate.” Do not invent a range or imply an estimate is a fixed quote. Emergency helper must not invent a surcharge or guaranteed response.
- Tradie amount labels distinguish “Job total”, “Estimated net” (only with an authoritative basis), “Earned” and “Paid”. Calculations stay decimal-safe; server money is decimal and historical payout snapshots take precedence over current commission config.
- Transfer account/name/reference come from configured payment instructions. Missing/sentinel instructions produce a safe unavailable/support state, not a transferable placeholder. Do not substitute a brand name for the legal bank account holder.
- Use factual payment reassurance: “Upload your receipt so our team can review your transfer.” Receipt uploaded is not payment verified. Any protected-funds/escrow claim requires D4 approval.
- Remove MVP implementation notes and fixture-looking customer copy in release/stakeholder captures. Keep synthetic data in tests, clearly separated from production. Do not rewrite real customer job titles to conceal them.

## 5. Screen-by-screen specification

Each row provides structural changes, local layout additions to UX-01, and a mid-fidelity concept. These are text concepts, not delivered image assets. Loading, empty, permission-denied, error/retry, and applicable offline states are required throughout; never fill missing data with invented statistics.

### Shared (S01–S06)

| ID / screen | Structure and behavior | Local layout | Mid-fidelity concept |
|---|---|---|---|
| S01 Splash | Preserve wordmark and branded gradient; optional subtle amber underline, no auth-flow change | Centered mark; tagline 16/500; safe area | Navy/amber wordmark anchored over the existing restrained background; short readable tagline below |
| S02 Onboarding | Three slides: finding local tradies, evidence-based verification, tracking work/payment review; clear Next/Skip | Illustration approximately top 50% where space allows; H1 26/700; body 16; pill dots; Next 56; Skip target 48 | One illustration and one promise per page, amber Next at bottom; no unsupported “pay safely” guarantee |
| S03 Login | Sign in primary; Google secondary; forgot-password and create-account accessible; retain real auth/error paths | Inputs 56; Google outline 56; divider; links target 48 | Wordmark, Welcome back, labelled fields, amber Sign in, quiet alternate route |
| S04 Signup | Select role, persistent labels, live password rules, sticky Create account | Two selectable role tiles radius 20; amber-tint selection and explicit selected semantics | Role choice above a clean single-column form; checklist uses body font, not debug mono |
| S05 Verify email | Six-digit entry supports auto-advance, full-code paste/autofill, backspace, invalid/expired code, resend timer | Six 48×56 boxes with 20px digits at reference width; adaptive gaps/width on 320px without overflow; grouped accessible input | Code row, concise instruction/error, amber Verify; resend explains remaining wait |
| S06 Role select | Explicit selection then Continue; preserve one-time registration token behavior | Two cards radius 20, icon tile 56, title 18/600, description 14; upper two-thirds placement | Two welcoming role choices with a visible selected state, not heavy black borders |

### Homeowner (H07–H18)

| ID / screen | Structure and behavior | Local layout | Mid-fidelity concept |
|---|---|---|---|
| H07 Dashboard | First-name greeting with neutral fallback; Needs your attention sorted by actionable state/deadline; active jobs; collapsed past jobs | H1 28; one amber-tint attention card with exact action/amount; standard job cards and progress; homeowner nav | A payment-required job leads the page; named tradie, total, status and next step visible together |
| H08 Jobs list | Active / Completed / All; explicit terminal/disputed status; tap opens state-appropriate screen; do not require swipe | Accessible segmented filter ≥48 target; two-line titles and 12 card gap | Calm list with clear amount/status and no metadata-chip wall |
| H09 Post job | Service → resolved Address → description/photos → When → explained urgency → hours/rate and review → Post job; preserve required title and all server-required fields | Description min 120; photos 3-up at 88 where space permits, adaptive grid; Today/Tomorrow/Pick date targets 48; cost card | Location pin/address above a photo-friendly brief; estimate only from real rates and hours. No lat/long fields |
| H10 Matching | Keep radar with reduced-motion fallback; Searching → Contacting → Confirmed only when events substantiate each state; truthful timeout/no-match/retry | Center illustration/status, readable step copy; Cancel secondary target ≥48 | “Finding your tradie…” above progress, not “Contacting Tradie 1” as a person |
| H11 Match result | Named tradie, photo, verified/insured evidence, rating-or-New, available real metrics, distance, bio, rationale; price breakdown; request within existing flow | Identity photo 72; name 20/700; bio max two-line preview; sticky Request [Name]; optional alternatives subject to D5 | Trust hero card over price summary; “Why we matched you” uses known service/distance facts, not invented ranking explanations |
| H12 Job detail | Booked/in-progress plus confirmation/terminal variants; one calm status banner; identity/contact; info grid; description; cancellation disclosure | Contact targets ≥48; two-column info grid with full-width price; sticky primary is state-specific, Open chat where appropriate | Named tradie and schedule lead, details remain compact; confirm-completion is not hidden behind generic chat |
| H13 Chat | Identity/call in header where authorized; history; composer/camera/send; optional role-appropriate quick replies | Bubble radius 18; text 16; navy sent/theme surface received; composer min 56; all actions ≥48 | Conversation-first view with job context and visible delivery/failure state; quick replies populate/send only with clear behavior |
| H14 Payment | Amount; 1 Copy reference → 2 Transfer → 3 Upload receipt; authoritative bank details and hours/rate/total; materials disclaimer | Amount 32/700; numbered card; copy targets 48; sticky Upload receipt | Clear manual-transfer instructions with factual staff-review reassurance; no placeholder bank account |
| H15 Payment status | Current review timeline, receipt summary, rejection/re-upload or expiry guidance, Back to job | Current step emphasized by text/icon, not color alone; compact receipt card; bottom action ≥56 | “Receipt under review” stands apart from “Payment verified”; no unnecessary repeated instruction wall |
| H16 Dispute | Existing reason options, details, evidence and submit; explain human review and how to follow progress | Standard flat header; reason sheet radius 28; details min 120; adaptive photo grid; next-steps card | Calm form with three short factual next steps; no promised resolution deadline or automated outcome |
| H17 Tradie public profile | Owner-aware actions; photo/name/badges; supported stats/about/service area/reviews; Request/Message subject to D5; Report/Block overflow | Hero photo; three stat tiles only when data exists; sticky contextual action; overflow target 48 | “New to TradieHunter” is welcoming; visitor never sees Edit Profile; unavailable metrics do not become zeros |
| H18 Messages / self-profile / Settings | Messages lead with counterparty then job/preview/time/unread; self-profile retains editable fields; settings grouped and discoverable | Message rows min 72, grow for scale; fields/setting rows min 56; setting cards radius 20 | Human conversation list and simple grouped account screens; no fixture-title-only threads |

Post-job details: retain hourly-only pricing and required hours, with guidance rather than removing the field. Preserve max five photos/10MB each and server validation; three-up is layout, not a three-photo limit. Date shortcuts use configured local time and convert once to UTC. User edits to address invalidate prior coordinates/rate results. Denied location permission must leave an accessible address-resolution path. Review summarizes service/address/time/urgency/hours/rate/total before submit without introducing a new booking state.

### Tradie (T19–T26)

| ID / screen | Structure and behavior | Local layout | Mid-fidelity concept |
|---|---|---|---|
| T19 Dashboard | Availability → weekly financial summary/jobs done/rating if authoritative → New leads → Today → collapsed upcoming | Toggle target 48; three adaptive stat tiles; lead price 24/700; prominent countdown; Decline:Accept 1:2 | Field-ready lead shows amount, distance, time, summary and photo if available; Accept uses one command without a forced detail visit |
| T20 Jobs list | Today / Upcoming / Awaiting payment / Done; retain access to all other states via All/additional filter; local-day grouping | Filter targets 48; cards show amount/address/status/time | A tradie can find today's work without scanning dozens of flat entries; pending review/disputed jobs are not lost |
| T21 Request detail | Location/map if approved; amount/countdown; info grid; brief/photos; Decline/Accept | Map region 160 when real map available, otherwise useful address card; timer visually dominant; bottom paired actions | Price and time remaining are readable immediately, not a small mono helper |
| T22 Active job | Booked/in-progress variants; address + Navigate, Call/Message, existing job brief, amount/net labels; Check in/out; cancellation overflow | Large address card; contact targets 48; CTA 56 full width; confirmation sheet for cancel | On-site controls sit within thumb reach; no accidental header cancel. Job notes mean existing description, not a new editable notes system |
| T23 Chat / Messages | Shared H13/H18 components with tradie quick replies such as On my way / Running late | Same geometry/semantics; timestamp and unread state preserved | Familiar shared conversation UI, with useful shortcuts and no second implementation |
| T24 Profile / Settings | Availability first, supported financial summary, business information, verification checklist, payout details restricted to owner | ≥48 controls, settings rows ≥56; consistent cards | Clear Pending/Approved/Rejected verification text; no MVP helper notes or public bank details |
| T25 Onboarding wizard | Four labelled sections per D7, benefits line per section, all required rates/schedule/credentials/bank data retained; save/retry behavior preserved | Progress labels ≥12; fields min 56; sticky Continue; responsive step labels | “Where you work” explains local leads before address entry; one coherent section at a time without dropping required tasks |
| T26 Homeowner public profile | Photo/name; supported member-since/jobs/reviews; authorized Message; Report/Block overflow | Same profile shell as H17; CTA min 56, overflow target 48 | A restrained customer identity page without tradie-only verification or earnings fields |

## 6. Audit coverage and disposition

| Audit theme | Resolution | Screen coverage |
|---|---|---|
| Mixed radii, black borders, cramped spacing, uneven tiles, flat hierarchy | UX-01; settled D1/D2 visual direction, independent of existing mockups | All groups |
| Tiny/mono typography, low contrast, pale Decline/status, mixed icons, nav ambiguity | UX-01/UX-02 | All groups, especially T19–T22 |
| Muddy gradient, whitespace, dangerous cancel | Flat operational headers, useful existing content, confirmed overflow cancellation | H12/H13/H16, T21/T22 |
| Money absent, buried Accept, weak countdown, flat jobs | Accurate amounts, direct Accept, server deadline, role filters | T19–T22; D4 |
| Missing identity/trust, zero ratings, wrong profile CTA | Evidence-based identity and permission-aware actions | H11/H12/H17/H18/T26; D5/D6 |
| Dense dashboard, six-step tracker, unclear next action | Attention card and four-stage presentation with full state labels | H07/H08/H12; UX-02 |
| Coordinates, weak job form, urgency without context | Address resolution, reordered form, photos, required hours/rates, explained urgency | H09; D3 |
| Receipt friction, repeated payment data, alarming warnings | Retain required manual review; numbered guidance, truthful status, policy disclosure | H12/H14/H15 |
| No quote flow | Deliberately excluded: preserve hourly accept model and show price earlier | H09/H11/T19/T21 |
| Contact/navigation/maps, earnings, extra profile metrics | Conditional on authorization, real contracts, and provider approval | D4–D6; H11/H12/T19/T21/T22 |
| Onboarding/OTP/auth polish, role borders | Shared primitives and responsive OTP/role choices | S01–S06/T25 |
| Dev copy, placeholders, raw status casing, fixture titles | UX-02/UX-03 and curated capture fixtures | All groups |
| Duplicate dashboard captures | Verify route/state coverage; duplicate images are not evidence of duplicate runtime content | H07 and final capture manifest |

## 7. Release acceptance (AC-01–AC-10)

- **AC-01 Coverage:** capture manifest names every S/H/T group, expanded combined screens and key states; reference sizes in both themes; annotate approved deviations. No unsupported screen-count claim.
- **AC-02 Accessibility:** text contrast ≥4.5:1; meaningful non-text ≥3:1; all interactive targets ≥48; 1.0/1.3/2.0 text scaling and 320px width pass without clipped/overlapping controls; VoiceOver/TalkBack and reduced motion checked.
- **AC-03 Consistency:** approved tokens, geometry, font decision, flat operational headers, shared icons/nav, two-line job titles, safe bottom actions and keyboard behavior across all routes.
- **AC-04 State correctness:** every current JobStatus has a tested display/action mapping; cancelled/expired/disputed never appear Done; payment review and confirmation remain visible; server authorization/history/SignalR preserved.
- **AC-05 Lead safety:** direct dashboard Accept/Decline and detail actions share behavior; expired, already-handled, reconnect/resume, duplicate-tap, server-rejected cases tested; no client countdown extends an offer.
- **AC-06 Trust:** own/other profile matrix passes for both roles; badges and metrics use real authorized fields; empty/new/missing states distinct; blind review and job-scoped messaging eligibility preserved.
- **AC-07 Money/payment:** snapshot amount/breakdown and decimal precision agree with server; no invented surcharge, rate range, net/paid claim, escrow guarantee, or transferable placeholder; review/rejection/re-upload/expiry paths verified.
- **AC-08 Posting:** address resolves without manual coordinates; changed address invalidates old coordinates/rates; denied permission/no results/network failures recover; required fields, photo limits, locale scheduling and review remain correct.
- **AC-09 Regression:** existing auth/Google/OTP, sequential matching, manual receipt review, booked/check-in/check-out/confirmation/review, cancellation, dispute, navigation and reconnect flows pass the repository harnesses appropriate to changed code.
- **AC-10 Evidence:** implementation records commands/results, screenshot manifest and before/after comparisons, known issues and approval decisions. Draft documentation is not runtime verification or release sign-off.
