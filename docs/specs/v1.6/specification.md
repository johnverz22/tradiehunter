# v1.6 — Hierarchy, status clarity, touch targets and iPad

**Date:** 2026-10-29
**Status:** Draft — awaiting review
**Deliverables:** This product/design specification, [visual-design.md](visual-design.md) (colour system, abstract assets, illustration, motion), and [tasks](tasks.md).

## 1. Purpose and evidence

The v1.5 release shipped functional depth — address autocomplete, lead pricing, earnings, payment breakdown, cancel sheets, and quick-reply chat. This follow-up audit (conducted against light, dark-mode sample, and iPad captures of the v1.5 build) found that the weaknesses have shifted from **missing information** to **too much information at equal weight**. Most screens are long stacks of identically weighted boxes.

This specification converts the audit findings into scoped, actionable improvements. It does not introduce new features or server-state changes.

### Sources and precedence

- `../../PRD.md`, `../../MVP-SPEC-v1.1.md`, `../../MVP-SPEC-v1.2.md`, `../../MVP-SPEC-v1.3.md`, and `../../ARCHITECTURE.md` govern product and technical behavior.
- `../v1.5/specification.md` is the prior visual/UX specification. Its global design contract (UX-01), state contracts (UX-02/UX-03), and decision gates (D1–D7) remain in effect. This spec refines and extends; it does not override settled decisions.
- `../../design/design-system.html` and `mobile/lib/theme/` remain the palette/token baseline.
- Existing mockups are excluded from inputs, deliverables and acceptance checks (carried from v1.5).
- The supplied follow-up audit is the source of reported visual findings. Reproduce findings before fixing them.

### Intended outcomes

1. **Hierarchy:** every screen has a clear visual lead — price on lead cards, trust on match, status on jobs — with supporting information subordinated.
2. **Status clarity:** a cancelled job and a completed job are visually distinct; orange is reserved for action-needed, not overloaded across four unrelated states.
3. **Touch targets:** Navigate, Message, Call, and View payment instructions are ≥48px tonal buttons, not 14px text links.
4. **iPad usability:** master-detail layout at ≥744pt; content max-width 640px for forms/lists; tab bar transitions to left rail at ≥1024pt.
5. **Contradictory states resolved:** dispute banner appears only on disputed jobs; confirm completion is disabled when a dispute is open.

## 2. Scope and decision gates

### Included

- Visual hierarchy and information reordering (all roles)
- Status pill system refinement (shape, fill, icon, contrast per state)
- Tracker replacement: vertical radio list → compact 4-segment progress bar
- Touch target enlargement for action buttons (Navigate, Message, Call, etc.)
- Container language unification (retire heavy dark outlines)
- Lead card and request detail reordering for tradies
- Match result trust reordering for homeowners
- Chat stepper replacement with one-line status pill
- Sign-up form scroll/clip fix
- Dead-end screens (expired/unavailable requests) with recovery paths
- Messages list enrichment (avatar, last message, time, unread dot)
- iPad responsive layout (master-detail, left rail)
- Dark-mode outline and border refinements
- Copy and placeholder cleanup

### Excluded (carried from v1.5)

Fixed quotes or bidding, payment gateways/BNZ, automated reconciliation/refunds/disputes, ML matching, loyalty/referrals, calendar sync, a new notes/checklist persistence system, direct booking that bypasses sequential offers, manufactured portfolio/trust metrics. Existing manual receipts, human payment review, payouts, and disputes remain supported.

### Decision gates

All v1.5 decisions (D1–D7) are settled and carried forward. No new functional decisions are required for this scope — all changes are visual hierarchy, layout, and copy improvements within existing data contracts.

| Decision | Status |
|---|---|
| D1 Geometry and headers | Settled v1.5; this spec refines container language |
| D2 Typography | Settled v1.5; this spec enforces two-family limit |
| D3 Address resolution | Settled v1.5; no changes |
| D4 Financial copy/data | Settled v1.5; this spec adjusts label hierarchy |
| D5 Profile actions | Settled v1.5; no changes |
| D6 Enrichment and external actions | Settled v1.5; this spec enlarges action buttons |
| D7 Tradie wizard | Settled v1.5; this spec trims visible categories |

## 3. Global refinements (extends UX-01)

These refinements extend the v1.5 global design contract. All v1.5 UX-01 rules remain in effect unless explicitly amended here.

### 3.1 Container language unification

**Problem:** Three competing container treatments — outlined (1.5px dark border, ~10-12px radius), shadowed (soft shadow, ~16px, no outline), and tinted — create visual noise.

**Resolution:** One container language for all cards, tiles, and panels:
- 20px radius, white/theme surface, 1px neutral border, soft shadow `0 2px 8px` at 8%.
- In dark mode: existing elevated surfaces, 1px border at ~12% white opacity. No light-grey 1.5px outlines.
- Heavy dark 1.5px outlines retired everywhere except focused input fields.
- Role cards, info tiles, match tiles, "Open Chat", "Message", "Navigate" panels all adopt this single container language.

### 3.2 Status pill system refinement

**Problem:** Orange is both the primary CTA and the status colour for four unrelated states (Awaiting payment, Requested, Receipt under review, Awaiting confirmation). Navy is used for In progress, Booked, Completed, Cancelled, Paid, and Expired alike.

**Resolution:** Status pills use shape, fill, and icon — not just hue:

| Semantic | Fill | Text | Icon | Example labels |
|---|---|---|---|---|
| Action needed | Solid orange | Dark text | `!` circle | "Pay now", "Review completion", "Upload receipt" |
| Active | Solid navy | White text | play/arrow | "In progress", "Booked" |
| Waiting | Navy tint 15% | Navy text | clock | "Under review", "Awaiting confirmation" |
| Done | Green tint 15% | Green text | checkmark | "Completed", "Paid", "Verified" |
| Cancelled / Expired | Neutral grey tint 15% | Grey text | strikethrough / x | "Cancelled", "Expired" |
| Problem | Red tint 15% | Red text | alert triangle | "Disputed", "Receipt rejected" |

Rules:
- Every pill has an icon and a human label. Labels use sentence case ("In progress", never `InProgress`).
- Pills hug content; never stretch to full width (the current full-width pills look like buttons).
- 28px height, 13px/600 text, pill radius.
- Green and red tokens are the existing semantic tokens already in the app (verified/error).

### 3.3 Tracker replacement

**Problem:** The 4-step vertical radio list dominates every card at ~150px, looks tappable, and is repeated on the jobs list and dashboard cards.

**Resolution:**
- **Cards and lists:** one 4-segment rounded bar (4px height, filled to current step), plus "Step N of 4 · Label" at 14px/600, single line. Total height ~24px.
- **Job detail page:** full vertical timeline available, collapsed by default behind a "View all steps" tap target.
- No radio buttons anywhere in the progress indicator.

### 3.4 Typography enforcement

**Problem:** Appears to use three font families; titles on adjacent screens don't match; chips/captions at ~11px and stat captions at ~10px wrap.

**Resolution:** Enforce the two-family decision from v1.5 D2:
- Space Grotesk for display headings (H1, H2).
- IBM Plex Sans for everything else (titles, body, captions, labels).
- Minimum caption size 12px/500. No 10px or 11px text anywhere.
- Stat captions should not wrap — use `FittedBox` scale-down for amounts.
- Mono font only for reference codes, never for captions or helpers.

### 3.5 Action button enlargement

**Problem:** "Navigate", "Message", "Call", "View payment instructions" are ~14px text links in ~36px rows.

**Resolution:** All interactive text-link actions become 48px tonal buttons:
- Blue tint fill, icon + label, 14px radius.
- Arranged in 2-up or 3-up rows with 8px gaps.
- Minimum 48×48 hit area per button.
- "View payment instructions" → 48px tonal button labelled "Payment details".

## 4. Screen-by-screen improvements

### 4.1 Entry & onboarding (S01–S06)

| Finding | Fix |
|---|---|
| Sign-up: sticky "Create account" covers Email field; role tiles push form down | Shrink role selector to 2-up segmented control (72px tall); form scrolls above sticky CTA with sufficient bottom padding; CTA never covers a field |
| "Forgot password?" left-aligned between Email and Password | Move to right-aligned under the Password field |
| Role-select: check-circle icon for Homeowner vs. house icon elsewhere | Unify to house icon on both sign-up and role-select |
| Slide 2 copy | Rewrite to "See credentials and reviews before you hire" |
| "Verification applies to the evidence shown" | Rewrite: "We verify the documents your tradie provides" |

### 4.2 Homeowner dashboard & jobs (H07–H08)

| Finding | Fix |
|---|---|
| Dashboard cards stack too much metadata at equal weight | Reorder: [tradie avatar + name + status pill] → title → price 24/700 → single primary button ("Pay now" / "Review completion" / "View matching") → compact progress bar. Move reference code and trade/location to a secondary line |
| Tracker radio list on every card | Replace with compact progress bar per §3.3 |
| "Hey Homeowner," placeholder greeting | Use first name with neutral fallback ("Welcome back") |
| Jobs list cards tall and sparse with per-line status pills | Compact card with inline status pill, amount right-aligned |

### 4.3 Post a job (H09)

| Finding | Fix |
|---|---|
| Three character counters (0/160, 0/200, 0/2000) | Show counters only when ≥80% of limit reached |
| Flat unstyled "Review your job" instruction list | Replace with a live estimate card that updates as fields are completed |
| Greyed-out "Search nearby rates" | Remove if non-functional, or surface as an active action |
| Date field looks like a chip | Style as a tappable input field matching other inputs |
| Photos far down the form | Move Photos up after Description |
| Sticky "Post Job" always active when required fields empty | Disable until all required fields are valid; show helper text naming the missing field |

### 4.4 Match result & payment (H10–H15)

| Finding | Fix |
|---|---|
| Match screen: three stat tiles fill the screen; tradie card cut off at bottom | Reorder: tradie hero first (72px photo, name 20/700, Verified + Insured badges, distance, "New to TradieHunter" or rating, jobs completed) → single price-breakdown card (hours × rate = total, platform fee line) → sticky "Continue to payment" + secondary "See another tradie" |
| "Match Found" appears twice (header and body) | Remove duplicate; single heading in the body area |
| "No reviews yet" appears three times on one profile | Replace with "New to TradieHunter" plus whatever proof exists (licence verified, insured, jobs completed). Show once |
| Payment status pill stretches full width (looks like a button) | Pills hug content per §3.2 |
| Two stacked buttons + ~10-row receipt summary is cramped | Collapse receipt summary behind "View receipt details" expandable; space buttons vertically with 12px gap |

### 4.5 Job detail lifecycle (H12, H16)

| Finding | Fix |
|---|---|
| "Active dispute under review" banner appears on Awaiting confirmation, Completed, and Cancelled jobs | Show dispute banner **only** on disputed jobs. Verify logic: `disputeStatus == 'Open'` is the sole trigger |
| Awaiting-confirmation screen offers "Confirm Completion" next to active dispute banner | Disable "Confirm Completion" when a dispute is open; show explanatory text |
| Info tiles staggered (2-up then full-width) with unequal heights | Equal-height 2-column grid: Scheduled \| Duration, then full-width Address, then Price row 24/700 |
| Every block full-width at the same gap; nothing leads | Group into three cards: **Status** (pill + progress + banner), **People** (tradie with Chat/Message/Call as 48px tonal buttons), **Details** (grid + description) |
| "Job not found" dead ends for expired/unavailable | Replace with friendly screen: illustration, "We couldn't find this job" or "This job is no longer available", buttons "Back to my jobs" and "Contact support" |
| Dispute evidence photo tile is dark navy with faint icon | Change to neutral tint with visible icon; add "What happens next" 3-line card |

### 4.6 Tradie dashboard & leads (T19–T20)

| Finding | Fix |
|---|---|
| Lead cards: price, duration, suburb, time, expiry all ~12px with icons, one per row | Reorder: **price 24/700 + urgency tag** → countdown progress bar with time → distance · start time · duration (14px) → one-line summary + photo thumbnail → Decline (outline, 1/3 width) \| Accept (primary, 2/3 width), 56px buttons |
| Expiry "Expires in 8:32" is small orange text | Replace with a visible countdown bar (progress segment + bold time remaining) |
| "Today 21" jobs with tall sparse cards, no grouping | Group by time: Now / Next / Later sections |
| Dashboard list: status pill on its own line | Move pill to top-right of card, price stays left |
| Outdoor readability: pale peach gradient lead cards with orange text and light-grey Decline | Increase contrast: darker text on lead cards; Decline button uses navy-tint outline (visible in sunlight), not grey |

### 4.7 Tradie request detail (T21)

| Finding | Fix |
|---|---|
| Price is blue (reads as a link) | Price in dark foreground at 24/700 (never looks like a link) |
| Status/Stage tiles take ~25% of screen with no decision value | Remove Status/Stage tiles entirely; move Category into a chip |
| Missing: distance/travel time, net after fee, photos up top, map | Add "You earn \$X after fee" below gross price. Photos after description. Map card if coordinates authorized (pre-Booked: omit, show address only) |
| "Gross" shown with no net | Show both: "Job total \$256.50 · You earn \$230.85" |
| Screen order buries the decision | Reorder: price + "You earn" → countdown bar → address/map → schedule → description → photos → sticky Decline \| Accept |

### 4.8 Tradie active job & wizard (T22, T25)

| Finding | Fix |
|---|---|
| Navigate dropdown chevron is an unlabelled icon | Replace with 48px "Navigate" tonal button; map-app picker as bottom sheet (Apple Maps / Google Maps), not a popup dropdown |
| "Job total (gross)" label is jargon | Replace with "You earn \$X" using net amount |
| Chat: 4-row stepper permanently occupies ~200px of viewport | Replace with one-line status pill under the header: "Step 3 of 4 · In progress" |
| Wizard step 1 sticky Continue clips content | Add bottom padding equal to CTA height + 32px to scrollable content |
| Wizard step 2 lists every trade category even though Plumber is selected | Show only the selected trade's services; other trades already chosen in step 1 |
| Wizard step 3 "Upload" sits awkwardly beside intro paragraph | Document cards with status pills; "Upload document" as 48px secondary button below cards |

### 4.9 Chat & messages (H13, H18, T23)

| Finding | Fix |
|---|---|
| 4-row stepper at top of chat viewport | Replace with one-line pill: "Step 3 of 4 · In progress", positioned under header |
| Messages list: every row reads "Tradie / No messages yet" with tiny status chip; no avatar, last message, or time | Redesign: 72px rows with avatar, tradie name, job title, last-message preview, time, unread dot. Status as a small icon, not a chip |

### 4.10 Profiles & settings (H17, H18, T24, T26)

| Finding | Fix |
|---|---|
| "No reviews yet" appears three times | Single trust row: rating or "New to TradieHunter", jobs completed, verified badge. One instance only |
| Profile fields grey-on-grey (looks disabled) except Phone | All editable fields use white/theme-surface fill, 56px height; pencil icon toggles edit mode |
| Tradie profile: verification copy sounds legalistic | Rewrite to friendly, factual language |

### 4.11 Dark mode

| Finding | Fix |
|---|---|
| Heavy light-grey 1.5px outlines on all containers | Replace with 1px border at ~12% white opacity per §3.1 |
| Tracker block is harsh in dark mode | Remove tracker block per §3.3 |
| Status pill contrast | Re-tint all pills per §3.2 dark-mode equivalents |
| Verify every text pair ≥4.5:1 | Audit all text/surface pairs in dark mode |

### 4.12 iPad

| Finding | Fix |
|---|---|
| Phone layout reused: cards in ~360px column, logo/avatar at screen edges, tab icons spread across full bottom bar | Content max-width 640px for forms/lists; at ≥744pt use master-detail (jobs/messages list left 360px, detail right); chat uses full width with 640px message column |
| Tab bar stretches full width on iPad | Transition to left rail navigation at ≥1024pt |
| Header content misaligned with body | Align header content to the same max-width grid as body content |

## 5. Audit coverage and disposition

| Audit theme | Resolution | Screen coverage |
|---|---|---|
| Too much information at equal weight | Hierarchy reordering across all card and detail screens | All groups |
| Three container languages (outlined, shadowed, tinted) | Unified container language §3.1 | All groups |
| Status colour ambiguity (orange overloaded, navy for everything) | Status pill system §3.2 | All status-bearing screens |
| Tracker radio list dominates cards | Compact progress bar §3.3 | H07, H08, H12, T19, T20 |
| Three font families, tiny captions, wrapping stats | Two-family enforcement §3.4 | All groups |
| 14px text-link actions | 48px tonal buttons §3.5 | H12, T21, T22 |
| Lead card buries price and decision | Reordered lead card §4.6 | T19, T21 |
| Match screen buries tradie (trust element) | Trust-first reorder §4.4 | H11 |
| Sign-up form clipped by sticky CTA | Segmented control + scroll fix §4.1 | S04 |
| Dead-end "Job not found" screens | Recovery screens with navigation §4.5 | T21 (expired/unavailable) |
| Chat stepper occupies ~200px | One-line pill replacement §4.8 | H13, T23 |
| Messages list lacks avatar/preview/time | Enriched message rows §4.9 | H18, T23 |
| iPad stretched phone layout | Master-detail + left rail §4.12 | All iPad screens |
| Dark-mode harsh outlines | Lighter borders §4.11 | All dark-mode screens |
| Contradictory dispute banner states | Logic fix §4.5 | H12 |
| Copy and placeholder issues | Copy cleanup across §4.1–4.10 | Multiple screens |

## 6. Release acceptance (AC-01–AC-08)

- **AC-01 Hierarchy:** every card and detail screen has a clear visual lead element (price, identity, or status) that is visually dominant over supporting metadata; verified at both reference sizes.
- **AC-02 Status clarity:** cancelled, completed, expired, and disputed jobs are visually distinct; no two semantically different states share the same pill appearance; pills hug content.
- **AC-03 Touch targets:** all interactive elements ≥48×48; Navigate, Message, Call, and payment-action buttons are tonal buttons, not text links; verified with accessibility inspector.
- **AC-04 Container consistency:** one container language across all cards and tiles; no heavy dark outlines on non-input elements; dark mode uses subtle borders.
- **AC-05 Progress bar:** no radio-style steppers anywhere; compact bar + single-line label on cards; full timeline only on detail pages (collapsed by default).
- **AC-06 iPad:** master-detail at ≥744pt; content max-width enforced; left rail at ≥1024pt; no stretched single-column phone layout.
- **AC-07 State correctness:** dispute banner only on disputed jobs; confirm completion disabled mid-dispute; expired/unavailable requests show recovery paths.
- **AC-08 Regression:** existing auth, matching, payment, booking, chat, and dispute flows pass repository harnesses; v1.5 acceptance criteria (AC-01–AC-10) remain green.


---

## 7. Visual design

High-fidelity visual treatment — colour system, backgrounds, abstract graphics, illustration, depth, shadows, and motion — is specified separately in **[visual-design.md](visual-design.md)**. That document is jointly authoritative with this one. On conflicts: this document governs layout, state logic, copy, and functional behaviour; visual-design.md governs colour expression, decorative assets, and deliverable format.

Key inter-document rules:
- The six source colours from visual-design.md §2 are the only hues used in implementation. `DesignTokens` token values take precedence over any descriptive hex in the design document.
- Tonal button fill (§3.5 above) uses mid-blue at 20% opacity over surface — consistent with visual-design.md §2.2 tint definitions.
- Status pill tints (§3.2 above) use 12–15% opacity — the "12%" tint step from visual-design.md §2.2 is the reference. Adjust to nearest passing contrast ratio.
- Hero bands in visual-design.md §4.2 use the `heroGradient` — this does not affect working screens (lists, forms, payment), which remain flat cream.
- Component sheet (V16-23) approval gates implementation of any screen. Do not implement a screen whose frame is not yet approved.
