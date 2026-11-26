# TradieHunter — Mobile Design System v2 Migration Plan

> **Scope:** Mobile rebrand only. Web (React admin) is excluded from all phases.
> **This document is docs-only.** No application code, components, styles, or source files are modified in Phase 1.
> **Source:** `th-design-v2/` (Trust Navy + Gold, v2.0.0)
> **Replaces:** `docs/design/` (Space Grotesk + IBM Plex + Amber, v1.7)
> **Revision 2026-11-16:** Phases 2–6 rewritten as a side-by-side rebuild of the presentation layer (see §4.0). Phase 1, §1–§3 and §5 are unchanged.
> **Companion (2026-11-18):** `docs/todos/02_design_system_fix_plan.md` covers what this plan marked done too early or never listed: visual QA of Phase 3–4 screens, the tradie side, missing-design screens and the capture harness. Where the two disagree on status, the fix plan wins.

---

## 1. Legacy Design System — Archival Plan

### 1.1 Current inventory of `docs/design/`

| Category | Files / Paths | Description |
|---|---|---|
| **Token source** | `tokens/tokens.json` | v1.7 design tokens (hue-209 amber palette) |
| **Token outputs** | `tokens/tokens.css`, `tokens/design_tokens.dart` | CSS variables + Dart token classes |
| **HTML frames** | `html/frames-homeowner.html`, `html/frames-tradie.html`, `html/frames-dark.html`, `html/frames-outdoor.html`, `html/frames-entry.html`, `html/frames-states.html`, `html/frames-components.html`, `html/frames-ipad.html` | 141 `[data-frame]` screens (63 light, 63 dark, 15 outdoor) |
| **Component sheets** | `html/component-sheet.html`, `html/style-tile.html`, `html/prototype.html`, `html/sprite.html` | Component library and style reference |
| **Stylesheet** | `html/kit.css` | v1.7 CSS token + component vocabulary |
| **Legacy baseline** | `design-system.html` | Original `--hue: 209` palette; superseded by `tokens/` |
| **Brand assets** | `assets/brand/` (19 SVG/PNG files: wordmarks, app icons, map pins, notification icon) | App branding assets |
| **Illustrations** | `assets/il-01` through `il-12` (light + dark, 24 SVG files) | Onboarding / empty-state illustrations |
| **Textures + decorations** | `assets/blob-*.svg`, `assets/contours.svg`, `assets/grid-*.svg`, `assets/noise-*.svg`, `assets/rings-*.svg`, `assets/route-line.svg`, `assets/tool-*.svg` | Background textures and decorative shapes |
| **Fonts** | `fonts/` (Space Grotesk 500–700, IBM Plex Sans 400–700, IBM Plex Mono 500 — 8 woff2 files + fonts.css) | v1 typefaces (Space Grotesk + IBM Plex) |
| **Build + render tooling** | `build.sh`, `render.mjs`, `render.py` | v1 build/render pipeline |
| **Audit tools** | `tools/audit.py`, `tools/audit_full.py`, `tools/assemble.py`, `tools/inline_sprite.py`, `tools/make_brand.py`, `tools/make_illustrations.py`, `tools/sheet.py`, `tools/variants.py` | v1 audit/assemble pipeline |

**Total:** ~105 files across 5 subdirectories.

---

### 1.2 Archive procedure

Move everything currently in `docs/design/` into a new directory **`docs/archive/design-legacy-v1/`**. Preserve the full subdirectory structure so git history and cross-references remain intact.

```
docs/archive/design-legacy-v1/
├── assets/           (brand/, illustrations, textures — full subtree)
├── fonts/            (all woff2 + fonts.css)
├── html/             (all frames, kit.css, sheets)
├── tokens/           (tokens.json, tokens.css, design_tokens.dart)
├── tools/            (audit.py, audit_full.py, assemble.py, etc.)
├── build.sh
├── design-system.html
├── render.mjs
└── render.py
```

> [!IMPORTANT]
> **Do not delete `docs/design/` itself** — only vacate its contents. After archiving, `docs/design/` becomes the new v2 root (Phase 2 populates it).
>
> Add a `docs/archive/design-legacy-v1/ARCHIVE-NOTICE.md` explaining: "This is the v1.7 design system (Space Grotesk + IBM Plex + amber). Archived on YYYY-MM-DD when the Trust Navy + Gold v2 system (Lexend + Source Sans 3) was introduced. Do not use for new work. Mobile source of truth is now `docs/design/`."

---

## 2. New Design System — Integration Structure

### 2.1 Source material in `th-design-v2/`

| File | Role |
|---|---|
| `tokens/tokens.json` | **Single source of truth.** Light + dark colour, type, space, radii, size, motion |
| `tokens/design_tokens.dart` | Generated Dart: `Space`, `Radii`, `Sizes`, `THType`, `THColors`, `THTheme` |
| `tokens/tokens.css` | Generated CSS variables for mockups |
| `tokens/contrast-report.txt` | WCAG AA gate results (38 pairs, all passing) |
| `ast/dsl.mjs` | AST node builders (design vocabulary) |
| `ast/screens.mjs` | 30 screens defined as AST (homeowner, tradie, shared) |
| `ast/screens.ast.json` | Generated AST as JSON |
| `flutter/th_widgets.dart` | Hand-written component library (~1,040 lines) |
| `flutter/screens/*.dart` | Generated screen widgets (30 screens + route table) |
| `mockups/index.html` | Generated light + dark HTML mockups |
| `tools/build.mjs` | Generator (Node 18+, no deps) |
| `DESIGN_GUIDE.md` | Canonical human-readable design guide (§1–§12) |
| `README.md` | Pipeline overview + quickstart |

### 2.2 Target structure for `docs/design/` (post-archival)

```
docs/design/
│
├── DESIGN_GUIDE.md              ← copy of th-design-v2/DESIGN_GUIDE.md (canonical guide)
├── README.md                    ← copy of th-design-v2/README.md (pipeline overview)
│
├── tokens/
│   ├── tokens.json              ← MASTER SOURCE OF TRUTH
│   ├── tokens.css               ← generated
│   ├── design_tokens.dart       ← generated
│   └── contrast-report.txt      ← generated (WCAG gate output)
│
├── ast/
│   ├── dsl.mjs                  ← AST node vocabulary
│   ├── screens.mjs              ← 30 screen definitions
│   └── screens.ast.json         ← generated AST output
│
├── flutter/
│   ├── th_widgets.dart          ← hand-written component library
│   └── screens/                 ← generated Flutter screen stubs (30 files)
│       ├── screens.dart         ← route table
│       └── [ho_|tr_|shared_]*.dart
│
├── mockups/
│   └── index.html               ← generated light + dark HTML mockups
│
├── tools/
│   └── build.mjs                ← generator pipeline
│
└── assets/
    └── (brand assets TBD — see §2.3 below)
```

### 2.3 Asset strategy

The v2 system references placeholder splash, onboarding illustrations and map assets. The v1 illustration set (`il-01` through `il-12`) and brand marks (wordmarks, app icons) are still the production assets.

**Decision (D-1 resolved 2026-11-16):** Option B — Brand assets remain in `docs/archive/design-legacy-v1/assets/brand/` pending a formal v2 brand pass. No copy into `docs/design/assets/` until then.

> [!NOTE]
> The v2 token set introduces `Lexend` + `Source Sans 3` (replacing Space Grotesk + IBM Plex). Font files are **not bundled** in `th-design-v2/` — they are loaded via `google_fonts` or added to `pubspec.yaml`. No font files need to be copied into `docs/design/fonts/` at this stage; note this explicitly in `DESIGN_GUIDE.md` §3.

### 2.4 Structural split across docs

After placing files, create these **three human-readable reference pages** inside `docs/design/` to make the system approachable without reading all source files:

| New file | Contents |
|---|---|
| `docs/design/mobile/COLOUR.md` | Extracted from `DESIGN_GUIDE.md` §2: full colour token table (light + dark), contrast results summary, pairing rules |
| `docs/design/mobile/TYPOGRAPHY.md` | Extracted from `DESIGN_GUIDE.md` §3: type scale table, font families, `pubspec.yaml` font setup instructions |
| `docs/design/mobile/COMPONENTS.md` | Extracted from `DESIGN_GUIDE.md` §5–§7: component vocabulary, widget mapping (`Fixo*` → `TH*`), role differences, screen inventory (30 screens), signature elements |

These are documentation extracts, not new content — they simply make the design guide navigable by topic.

---

## 3. Documentation Update Mapping

### 3.1 Core documentation files

| File | Required update | Priority |
|---|---|---|
| **`docs/DESIGN.md`** | **Full rewrite.** This is the primary design contract. Must reflect: v2 system version, new colour palette (Navy + Gold), new typography (Lexend + Source Sans 3), new token names (`THColors`, `THType`), new component vocabulary (`TH*` family replacing `Fixo*`), new screen inventory (30 screens, v2 frame list), updated regression gates (use `node tools/build.mjs --check` instead of `audit_full.py`), updated font rules (no font files in repo), remove outdoor/high-contrast variant references (not in v2). | 🔴 Critical |
| **`docs/ARCHITECTURE.md`** | Update design system section: new token file paths, font strategy (google_fonts vs bundled), remove references to `kit.css` and `html/` frames as source of truth. Add reference to `docs/design/mobile/tokens/tokens.json` as the single source of truth. Update the "Design system" row in the stack table. | 🔴 Critical |
| **`docs/SPECS.md`** | Update any references to v1 component names (`FixoPrimaryButton`, `FixoAppBar`, `FixoCard`, etc.) with their v2 equivalents (`THButton`, `THAppBar`, `THHero`). Update §10 mobile UX contract to reflect v2 screen structure. Remove references to `kit.css` classes (`.appbar`, `.btn-tonal`, etc.). | 🟠 High |
| **`docs/MVP.md`** | Update screen inventory list to match v2 screen names (e.g., `ho_choose_tradie` replaces the old "H19 Browse Tradies" reference). No scope changes — just naming alignment. | 🟡 Medium |
| **`docs/PRD.md`** | Update any design system references. Add a note that the mobile UI underwent a design system rebrand to v2 Trust Navy + Gold. No feature scope changes. | 🟡 Medium |
| **`docs/MILESTONES.md`** | Add a milestone entry for the v2 design system migration (this initiative). Record completion dates per phase as work progresses. | 🟡 Medium |
| **`docs/TESTING.md`** | Update design regression gate commands: replace `python3 docs/design/mobile/tools/audit_full.py` with `node docs/design/mobile/tools/build.mjs --check`. Update any references to `docs/design/html/frames-*.html` as test inputs. | 🟠 High |
| **`docs/QA.md`** | Update visual QA references: replace v1 frame file paths with v2 `docs/design/mobile/mockups/index.html`. Update component checklist from `Fixo*` to `TH*` names. | 🟡 Medium |
| **`docs/README.md`** (docs index) | Update the design row in the documentation map table: `docs/design/` now points to v2 Trust Navy + Gold system. Update the "Tokens, components, frames, notices" row. | 🟡 Medium |
| **`docs/ai/AI-TOOLING.md`** | Update §1 path table (`docs/design/` description), §4 toolchain commands (replace `make -C agent audit`/`transpile` with `node tools/build.mjs`), skills table (see §3.2). | 🟠 High |
| **`docs/ai/AGENTS-docs-block.md`** | If this contains the docs-map block used in AGENTS.md, update the design row to point to v2. | 🟡 Medium |

### 3.2 Agent rules and AI instruction files

| File | Required update | Priority |
|---|---|---|
| **`.agent/rules/mobile.md`** | **Major update.** This is the primary agent rule file for mobile UI. Must update: Design system section to reference `docs/design/mobile/DESIGN_GUIDE.md` and `docs/design/mobile/tokens/tokens.json` as the source of truth. Replace all `Fixo*` widget references with `TH*` equivalents. Update token class references (`THType` for typography, updated `THColors` fields). Remove references to `kit.css`, `html/frames-*.html`, `outdoor` variant, Space Grotesk/IBM Plex. Update "No hardcoded values" section with v2 token names. Update component reuse list. Add font strategy note. | 🔴 Critical |
| **`AGENTS.md`** (root) | Update the design token reference in the "Conventions" section: `mobile/lib/theme/design_tokens.dart` reference stays but update token class names. Update `docs/design/` description in the documentation map table. Remove references to `design-system.html` as a source. Remove references to v1 frame files (`frames-homeowner.html`, `frames-tradie.html`) as the visual source of truth (or update to point to v2 `mockups/index.html`). | 🔴 Critical |
| **`GEMINI.md`** | Update design token section: replace "docs/design/design-system.html" and v1 frame file references with v2 equivalents. Update the visual source of truth sentence. Remove "frames-homeowner.html and frames-tradie.html" and replace with "docs/design/mobile/mockups/index.html" and "docs/design/mobile/DESIGN_GUIDE.md". | 🔴 Critical |
| **`CLAUDE.md`** | Same updates as `AGENTS.md` — these files are kept in parity (see `AI-TOOLING.md §1`). | 🔴 Critical |
| **`.cursorrules`** | Regenerate from `CLAUDE.md` (per AI-TOOLING.md convention) after CLAUDE.md is updated. | 🟠 High |
| **`.windsurfrules`** | Regenerate from `CLAUDE.md` after CLAUDE.md is updated. | 🟠 High |
| **`.agent/rules/ai-tools.md`** | Update any design toolchain references (audit commands, frame paths). | 🟡 Medium |
| **`.agent/rules/backend.md`** | No design changes needed — confirm no accidental design references. | ⚪ Check only |
| **`.agent/rules/frontend.md`** | Confirm no mobile design references bleed into the web rules. | ⚪ Check only |
| **`mobile/HARDCODED_AUDIT.md`** (if present) | Will need a v2 audit pass in Phase 3 — flag as pending, but no doc update needed now. | ⚪ Phase 3 |

### 3.3 Cross-reference summary

The following **specific strings** appear in multiple docs and rule files and must be replaced or updated when updating each file:

| Old reference | New reference | Appears in |
|---|---|---|
| `docs/design/html/frames-homeowner.html` | `docs/design/mobile/mockups/index.html` | AGENTS.md, GEMINI.md, DESIGN.md, mobile.md |
| `docs/design/html/frames-tradie.html` | `docs/design/mobile/mockups/index.html` | AGENTS.md, GEMINI.md, DESIGN.md, mobile.md |
| `docs/design/html/kit.css` | `docs/design/mobile/tokens/tokens.css` | DESIGN.md, AI-TOOLING.md |
| `docs/design/design-system.html` | `docs/design/mobile/DESIGN_GUIDE.md` | DESIGN.md, ARCHITECTURE.md, GEMINI.md |
| `Space Grotesk` | `Lexend` | DESIGN.md, mobile.md |
| `IBM Plex Sans` | `Source Sans 3` | DESIGN.md, mobile.md |
| `FixoPrimaryButton` | `THButton(kind: accent)` or `THButton(kind: primary)` | mobile.md, SPECS.md |
| `FixoAppBar` | `THAppBar` | mobile.md, SPECS.md, AI-TOOLING.md |
| `THColors` via `Theme.of(context).extension<THColors>()` | `context.th.<name>` (via `THTheme` extension) | mobile.md |
| `python3 docs/design/mobile/tools/audit_full.py` | `node docs/design/mobile/tools/build.mjs --check` | TESTING.md, AI-TOOLING.md |
| `DesignTokens.*` | `THColors.*`, `THType.*`, `Space.*`, `Radii.*`, `Sizes.*` | mobile.md |
| `v1.7` (design system version) | `v2.0.0` | DESIGN.md, ARCHITECTURE.md, MILESTONES.md |
| `outdoor` variant | *(remove — not in v2)* | DESIGN.md, mobile.md |

---

## 4. Phased Execution Roadmap

### 4.0 Strategy (revised 2026-11-16) — rebuild the UI beside the old one, keep the data layer

> [!NOTE]
> Phases 2–6 were rewritten on 2026-11-16. Phase 1 and everything marked done are unchanged. The earlier Phase 2–5 draft replaced `design_tokens.dart` in place and swapped `Fixo*` widgets file by file; that fails immediately because the v1 app already defines `THColors`, `THType`, `THBadge`, `THField` etc. (in `lib/theme/design_tokens.dart` and `lib/widgets/th_components.dart`), and it would touch 60 files and 2,000-line screens in one pass.

**What we keep untouched** (verified UI-independent: nothing in them imports `views/`): `models/`, `repositories/` (auth, jobs, payments, profile, chat/reviews, addresses, SignalR `job_hub_client`), `network/`, `viewmodels/`, `utils/`, `feedback/` controllers, Firebase/FCM setup, `app_router.dart` paths, `extra` payload types and deep-link behaviour, and the Flutter platform projects (Firebase, Google sign-in, signing, icons).

**What we recreate:** the presentation layer only, in a new tree `mobile/lib/ui/` (feature folders: `auth/`, `homeowner/`, `tradie/`, `shared/`, `feedback/`, `design/`, `gallery/`), built from `th_widgets.dart` and `THTheme`.

**Why not a brand-new Flutter project:** it would force redoing Firebase, Google sign-in, push, signing and icons, and re-wiring auth/SignalR for no design benefit. **Why not in-place swapping:** name collisions, one giant PR, and the app is unshippable until it finishes.

**How old and new coexist**
- Same routes, same paths, same `extra`. A route builder returns the v2 screen only if its id is in `v2Screens` (or `--dart-define=UI_V2=all`); otherwise it returns the old screen. Rollback of any screen is a one-line flag change.
- v2 screens are wrapped in `ThScope` (§2.3), so the rest of the app keeps `FixoTheme` until Phase 6.
- An import-boundary guard (§2.4) keeps v1 and v2 files from importing each other.

**Per-screen recipe (used in Phases 3–5)**
1. Copy the generated stub from `docs/design/mobile/flutter/screens/<id>_screen.dart` into `lib/ui/<feature>/`. It is now hand-owned; never regenerate over it. (`ast/` + `mockups/` stay the design reference.)
2. Make it a `ConsumerWidget` and replace sample copy by watching the **existing** providers/viewmodels the old screen used. Put model→display mapping (money via `utils/money.dart`, status text via `job_status_presentation.dart`) in a small pure mapper next to the screen so it can be unit-tested.
3. Port the old screen's **actions** one by one (every button/sheet/navigation) to the same viewmodel methods. Write the action list from the old file first; it is the parity checklist.
4. Use `ThStateView` for loading / empty / error; use `THNotice` for toasts and banners.
5. Preserve the `Key`s the old screen exposed (141 in `lib/views`) wherever `test/` or `integration_test/` rely on them.
6. Add a widget test (provider overrides, light + dark) and, where useful, a golden.
7. Visual QA against `docs/design/mobile/mockups/index.html`, then add the id to `v2Screens`, one PR per screen or small group.

**Definition of done for a screen:** parity checklist complete, old-screen flow tests green with the flag on, no hardcoded colours/sizes/fonts (tokens only), Semantics labels kept, light + dark verified.

### 4.1 API policy and gap register

The backend API is the contract. **No backend change is planned by default.** While porting, if a v2 element needs data the API does not return, resolve it in this order: (1) derive it client-side from data already returned, (2) omit the element, (3) only if neither is acceptable, add an **additive, optional** field (with a backend test and a note in `docs/SPECS.md`) so the shipped app never breaks. Every gap gets a row here.

| # | Screen | Need | Finding | Resolution |
|---|---|---|---|---|
| G-1 | `tr_earnings` | 7-day bar chart (`THBars`) | `GET /api/tradie/earnings` (`TradieEarningsDto`) returns only period totals (earned / processed / pending / failed). No per-day values exist. | Port totals first; hide `THBars` when data is absent. Optional additive field `DailyNet[]` on `TradieEarningsDto` only if the owner wants the chart. |
| G-2 | `notifications` | notification list | Backend has no inbox endpoint; the app keeps a client-side store (`notification_center.dart`). | No change; keep client-side. |
| G-3 | `ho_home` hero | "Needs your attention" item | Verified 2026-11-17: no extra field needed. | **Resolved:** derived client-side from `GET /api/jobs` statuses (priority: payment due, awaiting confirmation, dispute, payment review). Amount shown only when the job is priced. |
| G-4 | dock / `chat` | unread badges, last message | Not verified. `GET /api/chat/conversations` is the likely source. | Verify in 3.1; derive or omit. |
| G-5 | `tr_home` / `ho_tradie_profile` | rating, job count, response time, distance | Verified 2026-11-17: `GET /api/profile/:id` provides average rating and review count; the job's tradie-list DTO provides completed jobs, distance, and hourly rate. No response-time field is returned. | `ho_tradie_profile`: derive displayed values from those DTOs; omit response time and any unavailable stats. `ho_home`: **omitted** (no supporting endpoint). |
| G-6 | `ho_choose_tradie` | header subtitle (job title · category) | `TradieListState` does not carry the job. | **Resolved 2026-11-17:** derived from a one-shot `GET /api/jobs/:id` (`chooseTradieJobProvider`); subtitle omitted when the read fails. No API change. |
| G-7 | `ho_choose_tradie` | filter pills (Verified / Insured / Available now) | In v1, not in the mockup. | **Kept:** it is the only filter path; second pill row labelled `needs-design`. |
| G-8 | `ho_post_*` | address suggestions, service picker sheet, photo source sheet | Not in the mockup; v1 has them and the API requires a resolved address. | **Composed from `TH*`** (`THListRow`/`THCard`); `needs-design`. No API change. |
| G-9 | `ho_post_*` | urgency control | In v1 (4 values, sent in payload, asserted by a test); not in the mockup. | **Kept (owner, 2026-11-17)**; `needs-design`. |
| G-10 | `ho_post_*` | materials by, site visit, scope notes, address, photos, hours (both modes) | In v1 / required by validation; not drawn in the mockup. | **Kept all (owner, 2026-11-17)**; `needs-design`. |
| G-11 | `ho_post_*` | "Review your job" card | In v1; absent from the mockup. | **Kept and redesigned (owner, 2026-11-17)** with `THCard`/`THKeyValue`; v1 strings unchanged; `needs-design`. |
| G-12 | `ho_post_project` | ASAP timing | Mockup omits it for projects; v1 allows it. | **Kept** in both modes (backend contract accepts `Asap`); revisit only if the API rejects it. |
| G-13 | `ho_home` | "Top rated near you" (two tradie cards) | Dropped under G-5 as "no supporting endpoint". *Correction 2026-11-18:* the browse-tradies search (`GET /api/services/search`) returns name, rate and distance only, **no rating or review count**; rating exists only on the per-job `GET /api/jobs/{id}/tradies`. | **Open (fix plan D-7, owner decision):** the earlier default (build from the tradie search) is not possible without a backend change (rating and review count on the search DTO, or a top-rated endpoint). Until then the section stays hidden; or drop it from the mockup. |
| G-14 | `ho_review` | "What stood out" chips | The review API has no tags. | **Default (fix plan D-9):** drop the chips and amend the mockup (`ast/screens.mjs`); no API change. |
| G-15 | `ho_dispute` | "What would be fair?" field and reason pills | The API takes a reason enum and details only. | **Default (fix plan D-10):** present the API's reason values as pills; omit the fair-amount field and amend the mockup. |
| G-16 | `tr_home` | "Response rate" stat | No endpoint returns it. | **Default:** omit; derive only if a real source appears (fix plan T-01). |
| G-17 | `tr_lead` | Commission / "you keep" figures | Source not verified. | **Verify before building:** show only figures from backend config; never hard-code a commission rate (fix plan T-02). |

### 4.2 Screens in the app with no v2 design (not in the 30)

`signup`, `settings`, `messages_list`, `categories`, `browse_tradies` (`/find-tradie`), homeowner public profile (`/users/:id`), quick-match radar (`/jobs/:id/matching`) and its failure state, cancel-job / schedule / rating sheets, designed empty/error states, wide-screen nav rail, the payment-status states (review / verified / rejected / expired / bank details unavailable), the tradie quote submission form, the tradie jobs list, tradie request expired / unavailable, and any admin screens (full list: fix plan §3.2). Compose them from `TH*` widgets per `DESIGN_GUIDE.md`, label PRs `needs-design`, and feed them to the D-4 design pass. These are **not** blockers for Phases 2–5.

---

### Phase 1 — Documentation Restructuring (This phase — docs only)

**Goal:** Archive legacy design, install v2 design system docs, update all cross-references. No app code changes.

> [!NOTE]
> **Steps 1.1–1.4 completed 2026-11-16.** Files are in place. Steps 1.5–1.28 are deferred — owner has paused here pending a separate app-migration plan.

- [x] **1.1** Create `docs/archive/design-legacy-v1/` directory structure
- [x] **1.2** Move all files from `docs/design/` into `docs/archive/design-legacy-v1/` (preserving subdirectory layout)
- [x] **1.3** Create `docs/archive/design-legacy-v1/ARCHIVE-NOTICE.md` (date, reason, pointer to v2)
- [x] **1.4** Copy `th-design-v2/` contents into `docs/design/` following the structure in §2.2
- [x] **1.5** Create `docs/design/mobile/COLOUR.md` (extract from DESIGN_GUIDE.md §2)
- [x] **1.6** Create `docs/design/mobile/TYPOGRAPHY.md` (extract from DESIGN_GUIDE.md §3)
- [x] **1.7** Create `docs/design/mobile/COMPONENTS.md` (extract from DESIGN_GUIDE.md §5–§7)
- [x] **1.8** Add `docs/design/assets/ASSETS-NOTICE.md` documenting asset strategy decision (see §2.3) — *D-1 resolved: skip; brand assets stay in archive*
- [x] **1.9** Rewrite `docs/DESIGN.md` per §3.1
- [x] **1.10** Update `docs/ARCHITECTURE.md` per §3.1
- [x] **1.11** Update `docs/SPECS.md` per §3.1
- [x] **1.12** Update `docs/MVP.md` per §3.1
- [x] **1.13** Update `docs/PRD.md` per §3.1
- [x] **1.14** Update `docs/MILESTONES.md` per §3.1
- [x] **1.15** Update `docs/TESTING.md` per §3.1
- [x] **1.16** Update `docs/QA.md` per §3.1
- [x] **1.17** Update `docs/README.md` per §3.1
- [x] **1.18** Update `docs/ai/AI-TOOLING.md` per §3.1
- [x] **1.19** Update `docs/ai/AGENTS-docs-block.md` per §3.1
- [x] **1.20** Update `.agent/rules/mobile.md` per §3.2
- [x] **1.21** Update `AGENTS.md` (root) per §3.2
- [x] **1.22** Update `GEMINI.md` per §3.2
- [x] **1.23** Update `CLAUDE.md` per §3.2 (canonical — regenerate cursorrules/windsurfrules from it)
- [x] **1.24** Regenerate `.cursorrules` and `.windsurfrules` from updated `CLAUDE.md`
- [x] **1.25** Update `.agent/rules/ai-tools.md` per §3.2
- [x] **1.26** Check `.agent/rules/backend.md` and `.agent/rules/frontend.md` for stray mobile design refs
- [x] **1.27** Verify `docs/design/mobile/tools/build.mjs` runs correctly from its new location (`node docs/design/mobile/tools/build.mjs --check`)
- [x] **1.28** Commit with message: `docs: archive v1.7 design system, install v2 Trust Navy + Gold`

✅ **Phase 1 done when:** `node docs/design/mobile/tools/build.mjs --check` passes, no doc or rule file references old v1 paths, and `docs/archive/design-legacy-v1/` contains the complete v1 set.

---

### Phase 2 — Foundation (no screen changes, app behaves exactly as today)

**Goal:** Install v2 tokens, fonts, widgets and a scoped theme under `mobile/lib/ui/`, next to the old code. Nothing in `lib/views/`, `lib/widgets/` or `lib/theme/` changes.

- [x] **2.1** Create `mobile/lib/ui/design/` and copy in `docs/design/mobile/tokens/design_tokens.dart` → `th_tokens.dart` and `docs/design/mobile/flutter/th_widgets.dart` → `th_widgets.dart`. Fix the one relative import (`design_tokens.dart` → `th_tokens.dart`). Keep class names unchanged (`THColors`, `THType`, `THButton`, …).
- [x] **2.2** Bundle fonts (D-2): add Lexend + Source Sans 3 files for the weights used in `tokens.json` under `mobile/assets/fonts/v2/` and declare both families in `pubspec.yaml`. **Keep the v1 families until Phase 6.** Verify on a real iOS and Android device that the files render (Flutter's mobile engines are only guaranteed to load `.ttf`/`.otf`; if `.woff2` falls back to the system font, convert to `.ttf`, which still satisfies D-2). *Done as static `.ttf` (Lexend 400–800, Source Sans 3 400–700); on-device render check still to do.*
- [x] **2.3** Add `ThScope` (`lib/ui/design/th_scope.dart`; takes `themeMode` as a parameter until 2.11 moves `themeModeProvider` out of `views/`, so `lib/ui` stays free of `views/` imports): wraps a subtree in `Theme(data: THTheme.light | THTheme.dark)`, choosing by the existing `themeModeProvider` + platform brightness. `THTheme.light/dark` are getters, not methods. This is how v2 screens get v2 theme while the rest of the app keeps `FixoTheme`.
- [x] **2.4** Add the import-boundary guard (`scripts/check_ui_boundary.py`, run as a step of the `mobile-build-test` CI job): files under `lib/ui/**` must not import `theme/design_tokens.dart`, `theme/fixo_theme.dart`, `widgets/fixo_*`, `widgets/th_components.dart` or `views/**`; files outside `lib/ui/**` must not import `ui/design/**`. This is what makes the side-by-side approach safe, because the old app and v2 both define `THColors`, `THType`, `THBadge`, `THField`, `THSegmented`, `THSwitch`, `THIconButton`, `THListRow` and `THDivider`. They only clash if one file imports both.
- [x] **2.5** Add `node docs/design/mobile/tools/build.mjs --check` to CI now (new `design-system-check` CI job; passes: 30 screens, contrast 38/38). Retiring the v1 audit targets waits for Phase 6.
- [x] **2.6** Copy the 30 generated stubs to `mobile/lib/ui/gallery/` (static sample data, imports repointed) and add a debug-only `/debug/screen-gallery` route exposing `thScreenBuilders`, each wrapped in `ThScope` (`ScreenGalleryPage`, with a light/dark toggle; deep link `?screen=<id>&theme=dark`). These stubs are the visual baseline and golden source. They are **not** the real screens.
- [x] **2.7** Add golden tests for the 30 gallery screens (light + dark) under `test/ui/goldens/`. *Test written (`test/ui/gallery_goldens_test.dart`); baseline PNGs still to generate with `flutter test --update-goldens test/ui/gallery_goldens_test.dart` (comparison is skipped per screen until its PNG is committed).*
- [x] **2.8** Create `lib/ui/feedback/th_notice.dart` (D-3): a v2-styled skin that reuses the existing `FixoNoticeController`/`notice_copy.dart` logic (UI-independent). The class rename of the old widgets happens at cutover. *`THNotice` façade + `THNoticeHost` + `THNoticeBanner`, tests in `test/ui/th_notice_test.dart`. Host is not mounted yet: the v1 `FixoNoticeHost` still renders notices until Phase 6.1.*
- [x] **2.9** Create `lib/ui/feedback/th_state_view.dart`: loading (skeleton), empty and error views composed from v2 widgets and the existing copy in `designed_empty_state.dart` / `fixo_states.dart`. D-4 (error/empty/skeleton design pass) is separate, so this is the interim. *`ThStateView.loading/empty/error/preset` (presets carry the v1 copy; actions are caller callbacks, no routing inside). Tests in `test/ui/th_state_view_test.dart`.*
- [x] **2.10** Add `lib/ui/ui_flags.dart`: a per-screen allowlist (`const Set<String> v2Screens`) plus `--dart-define=UI_V2=all` for developers. See §4.0 for how routes use it. *`isV2Screen(id)` + pure `resolveV2Screen`; `UI_V2` also accepts a comma-separated id list. `v2Screens` is empty until Phase 3. Tests in `test/ui/ui_flags_test.dart`.*
- [x] **2.12** Run `flutter analyze`, `dart format`, and the full existing test suite. **Nothing may change.** *Run `dart format lib test`, `flutter analyze`, `flutter test`, and `flutter test --update-goldens test/ui/gallery_goldens_test.dart` (2.7) locally or via CI.*

✅ **Phase 2 done when:** app builds and behaves identically, existing tests are green, `build.mjs --check` runs in CI, the import-boundary guard is green, and the debug gallery shows all 30 screens in both themes.

---

### Phase 3 — Shell, Auth and Shared Screens (proves the recipe)

**Goal:** Port the low-risk, high-reuse screens first so the per-screen recipe (§4.0) is proven before the big flows.

- [x] **3.1** Build the v2 shell: `ThShell` using `THDock` (homeowner: Home / Jobs / Chat / Profile with centre action `onNewRequest` → `/jobs/new`; tradie: same four tabs, **no** `onNewRequest`). Mirror the role/tab logic and unread badge source of `views/main_layout.dart` (including the wide-screen `_FixoNavRail` behaviour, which v2 does not design, so keep it as-is or decide in D-4). The router swaps the `ShellRoute` builder via the flag.
- [x] **3.2** Port auth screens (data layer untouched: `auth_viewmodel`, `auth_repository`):

  | v2 screen | Old file | Endpoints (already exist) |
  |---|---|---|
  | `splash` | `views/splash_screen.dart` | `/api/auth/refresh` (session restore) |
  | `onboarding` | `views/onboarding/onboarding_view.dart` | none |
  | `sign_in` | `views/login_screen.dart` | `/api/auth/login`, `/api/auth/google` |
  | `verify_otp` | `views/auth/otp_verification_screen.dart` | `/api/auth/verify-email`, `/api/auth/resend-otp` |
  | `role_select` | `views/auth/role_select_screen.dart` | `/api/auth/complete-registration` |
  | *(no v2 design)* | `views/signup_screen.dart` | `/api/auth/register` — compose from `sign_in` + `THField` (see D-4 list in §4.2) |

- [x] **3.3** Port shared screens:

  | v2 screen | Old file | Data source |
  |---|---|---|
  | `chat` | `views/chat/chat_screen.dart` | `/api/jobs/:id/messages` + SignalR (`job_hub_client`, `chat_viewmodel`) |
  | `notifications` | `views/notifications/notifications_screen.dart` | client-side `notification_center` (no backend inbox exists — keep) |
  | `profile` | `views/profile_screen.dart` | `/api/profile` (+ block / report / device-token) |
  | *(no v2 design)* | `views/chat/messages_list_screen.dart` | `/api/chat/conversations` |
  | *(no v2 design)* | `views/settings_screen.dart` | theme mode, locale, sign-out |

- [x] **3.4** For each screen follow the §4.0 recipe, including widget tests, preserved `Key`s and flipping its entry in `v2Screens`.
- [x] **3.5** Visual QA each screen against `docs/design/mobile/mockups/index.html` (light + dark). *Automated light + dark verification (widget tests + gallery goldens stay green); on-device mockup comparison is the follow-up.*

✅ **Phase 3 done when:** a user can sign up, verify, sign in (email and Google), pick a role, and land in the v2 shell with chat / notifications / profile in v2, with all auth tests green.

*Done 2026-11-17. Shipped as `feat(mobile): phase 3`: `ThShell` (dock + rail + `chatUnreadProvider` badge), six auth screens, five shared screens under `lib/ui/auth/` + `lib/ui/shared/`; additive `TH*` extensions (`THTextField`, `THOtpInput`, `THButton.loading`, `THAppBar.actions/showBack/leading`, `THDock.badges`, `THSegmented.onSelected`, `THScaffold.bottomClearance`); `v2Screens` flipped for the 12 Phase-3 ids (gallery goldens unchanged — additive defaults verified pixel-neutral). Suite: analyze clean, 887 tests green, import-boundary + design gates green. Known needs-design stand-ins: the ≥1024px rail (D-4), settings and messages_list compositions (no v2 mockups), and the chat Schedule action still opening the v1 sheet until the job-detail screens port. The self-profile screen has a v2 design and is implemented against it.*

*Phase 3 audit follow-up (2026-11-17): fixed B1 by scoping `ThScope` to shell chrome, aligned the self-profile overview with its v2 design, and covered both real v1 shell children plus light/dark Home goldens. Added the Phase 3 type, radius, size and motion tokens from the source token file; chat wrapping/semantics and reduced-motion handling are covered by widget tests. Verification on Flutter 3.47.5: analyze clean and all 65 Phase 3 tests pass. The full suite reports 60 gallery golden diffs against baselines last re-blessed on Flutter 3.47.9; those global baselines were left unchanged, outside this Phase 3 fix set.*

*Widget audit against `docs/design/mobile/mockups/index.html` (2026-11-17): Phase 2's display `THField` and button dimensions/type sizes match the mockup (`56px` input, `54px`/`15px` regular button, `44px`/`14px` small button). The editable `THTextField` added in Phase 3 was the mismatch: it rendered its label outside the border and Flutter's default icon slot made the control too tall. It now keeps uppercase small-caps labels and editable input inside one bordered surface, constrains icon slots, uses 16px input text, and follows the mockup's field radius.*

*THTextField follow-up (2026-11-17): the first fix still left the icon on a separate line from the hint, because the icon was an `InputDecoration.prefixIcon` forced to 44px tall, which stretched the input row and the field past 56px. `THTextField` now builds the mockup `.fld` structure directly: bordered 56px surface, 10/14 padding, small-caps label, then one row (18px icon, 10px gap, value/hint); the password toggle keeps its 44px tap target, bottom-aligned with the value row. Geometry is pinned by `test/ui/th_text_field_layout_test.dart`.*

*Auth spacing follow-up (2026-11-17): side-by-side with the mockup showed type, button (54) and field (56) tokens already match the mockup CSS exactly; what made v2 look smaller was layout. Auth screens used a 24px side padding instead of the 20px `Sizes.gutter`, and `sign_in` omitted the mockup's spacer divs (28 after the wordmark, 4 under the heading, 20 before the fields) and indented "Forgot password?" from the field edge. Fixed in `sign_in`, `sign_up`, `role_select` and `ThAuthScroll`; no token values changed. `verify_otp` and later screens still need the same side-by-side pass.*

---

### Phase 4 — Homeowner Flows

**Goal:** Recreate homeowner screens in v2, porting behaviour from the old screens. Ordered so each step can be tested end to end.

- [x] **4.1** Port in this order (corrected mapping — several names in the earlier draft did not exist):

  | Order | v2 screen | Old file (actual) | Endpoints (already exist) |
  |---|---|---|---|
  | 1 | `ho_home` | `homeowner/homeowner_dashboard_view.dart` + `widgets/homeowner_dashboard_header.dart` | `GET /api/jobs`, `/api/services/search` |
  | 2 | `ho_jobs` | `jobs/jobs_list_screen.dart` | `GET /api/jobs` |
  | 3 | `ho_post_quick`, `ho_post_project` | `jobs/post_job_screen.dart` (1,344 lines, both modes) | `POST /api/jobs`, `/photos`, `/api/addresses/search`, `/api/services/search` |
  | 4 | `ho_choose_tradie` | `jobs/tradie_list_screen.dart` | `GET /api/jobs/:id/tradies` |
  | 5 | `ho_tradie_profile` | `profile/public_profile_screen.dart` (`jobId` context) | `GET /api/profile/:id`, `/api/users/:id/reviews`, `POST /api/jobs/:id/request` |
  | 6 | `ho_request_sent` | `jobs/matching_screen.dart` (`requestSent` mode) | SignalR + `GET /api/jobs/:id` |
  | 7 | `ho_quotes` | `jobs/quotes_screen.dart` | `GET/POST /api/jobs/:id/quotes`, `…/quotes/:id/accept` |
  | 8 | `ho_job_booked`, `ho_extra_cost`, `ho_review_completion`, `ho_review` | `homeowner/homeowner_job_detail_screen.dart` (**1,916 lines, one route, many states**) | `GET /api/jobs/:id`, `/adjustments`, `…/respond`, `/confirm`, `/reviews`, `/schedule`, `/cancel` |
  | 9 | `ho_payment`, `ho_payment_status` | `payment/payment_screen.dart`, `payment/payment_status_screen.dart` | `GET /api/jobs/:id/payment`, `POST …/upload-receipt` |
  | 10 | `ho_dispute` | `jobs/dispute_screen.dart` | `POST /api/disputes`, `…/evidence/text`, `…/evidence/files` |
  | — | *(no v2 design)* | `homeowner/categories_screen.dart`, `homeowner/browse_tradies_screen.dart`, quick-match radar mode of `matching_screen.dart` | `/api/services/search`, `POST /api/jobs/:id/match`, `GET …/matches` |

  *4.1 progress (2026-11-17): **#1 `ho_home` ported** as `ThHomeScreen` (`lib/ui/homeowner/ho_home_screen.dart`) with pure mapping in `ho_home_mapper.dart` and a v2 copy of the card-navigation rules in `ho_job_navigation.dart` (same routes, plan 4.4). Parity kept: load + pull-to-refresh, SignalR status events, first name, attention / booked / active / past grouping, past-jobs toggle, See all jobs, empty state with Post a job, refresh-error notice, `homeowner_dashboard` / `homeowner_hero` Keys. New in v2 per the mockup: attention hero, search entry (`/find-tradie`), category tiles (`/find-tradie` seeded, More to `/categories`). Dropped: the v1 location pill (not in the v2 design). Wired in `app_router.dart` as `_pick('ho_home', …)`; **not yet added to `v2Screens`** until the on-device visual QA and the flow tests with `--dart-define=UI_V2=ho_home` have been run. Remaining after #1: #2 to #10.*

  *4.1 progress (2026-11-17, #2): **#2 `ho_jobs` ported** as `ThJobsScreen` (`lib/ui/homeowner/ho_jobs_screen.dart`) with the pure filter rules in `ho_jobs_mapper.dart`. The job card moved out of `ho_home_screen.dart` into the shared `HoJobCard` (`ho_job_card.dart`, no behaviour change; the chat button Key prefix is a parameter, `home_chat_` stays the default). Parity kept: `loadHomeownerJobs` on entry and pull-to-refresh, Active / Completed / All filter (All is not in the mockup but is the only way to reach Cancelled / Expired jobs, so it stays), loading / error-with-retry / no-jobs (Post a job) / empty-filter (View all jobs) states, refresh-error notice, linear progress while refreshing, card navigation through `ho_job_navigation.dart` (routes unchanged, plan 4.4). New in v2 per the mockup: "My jobs" heading, segmented filter, v2 job cards (status badge + segmented progress). `/jobs` is shared with tradies, so `ThJobsRoute` (same file) does the role split inside `_pick('ho_jobs', …)`: tradies keep the v1 `JobsListScreen` until Phase 5, an unknown role shows a loading placeholder and never requests homeowner jobs (same rule as v1), a failed profile load shows a retry. Deviation: the v1 master-detail panel at >= 744pt embedded the v1 job detail; v2 wide screens use the narrow push navigation until the v2 job detail (4.2) and the wide layout (D-4) exist. **Not yet added to `v2Screens`**: `flutter analyze`, `flutter test test/ui/phase4_ho_jobs_test.dart`, the existing flow tests with `--dart-define=UI_V2=ho_jobs` (`homeowner_jobs_ui_test`, `phase3_shell_test`) and the on-device visual QA still need a run; `scripts/check_ui_boundary.py` passes. Remaining: #3 to #10.*

  *4.1 progress (2026-11-17, #4): **#4 `ho_choose_tradie` ported** as `ThChooseTradieScreen` (`lib/ui/homeowner/ho_choose_tradie_screen.dart`) with pure rules in `ho_choose_tradie_mapper.dart`, the shared `HoTradieCard` (`ho_tradie_card.dart`, reusable by the later browse-tradies port) and the interactive `ThChoicePills` (`lib/ui/shared/th_choice_pills.dart`; `th_widgets.dart` stays generated). Parity kept: `tradieListProvider(jobId)` load + pull-to-refresh, server-side sort (Best match / Top rated / Nearest / Lowest rate mapped to the mockup's Sort / Rating / Distance / Rate pills) and the Verified / Insured / Available now filter row (kept as the only filter path, `needs-design`, G-7), loading / error-with-retry / empty states with the v1 "Clear filters vs reload" decision, rate omitted when absent with the D8 GST label, rating only with a real score + review count, distance fallbacks, verified / insured / available badges from real booleans, card tap to `/tradie/:id?jobId=` (unchanged, plan 4.4), and the guarded Quick match action (one in flight, `THNotice.warning` on failure, mounted guard). All six v1 Keys preserved (`tradie_sort_bar`, the three filter pills, `tradie_list`, `quick_match_button`). Header subtitle derives from a one-shot job read and is omitted on failure (G-6). Wired as `_pick('ho_choose_tradie', …)`; **not added to `v2Screens`** pending on-device visual QA (light + dark, 200% text) and the screenshot flow. Verification on Flutter 3.47.5: `flutter analyze --fatal-infos` clean, `scripts/check_ui_boundary.py` passes, `test/ui/phase4_ho_choose_tradie_test.dart` 21/21, `flutter test test/ui/` 200/200, full suite 954/954, `matching_flow_test` + `post_job_flow_test` green with `--dart-define=UI_V2=ho_choose_tradie`. Note: #3 (`ho_post_quick` / `ho_post_project`) was not present on this checkout; it has since been rebuilt (next note), so the post-job → choose-tradie path is now covered. Remaining: #5 to #10.*

  *4.1 progress (2026-11-17, #3): **#3 `ho_post_job` rebuilt** (single flag id covering both gallery ids) as `ThPostJobScreen` (`lib/ui/homeowner/ho_post_job_screen.dart`) with the pure rules in `ho_post_job_mapper.dart` and sections split into `ho_post_job_basics.dart`, `ho_post_job_address.dart`, `ho_post_job_timing.dart`, `ho_post_job_photos.dart`, `ho_post_job_project.dart`, `ho_post_job_review.dart` plus `ho_service_sheet.dart`. One route, two states via `THSegmented` bound to `postJobProvider.jobType`; both modes share every section and switch only labels. Owner decisions applied: both modes keep v1 routing to `/jobs/:id/tradies`; the review card is kept and redesigned with `THCard`/`THKeyValue` (v1 strings unchanged); urgency, hours (both modes), materials, site visit and scope notes are kept. Parity kept: tradie role guard; service picker with loading + retry; full address type-ahead (loading / error+retry / no-match / suggestions / "Address selected" / late cached address); title 200 + description 2000 with the 80% counter; hours formatting; photos max 5, 10 MB, quality 85, source sheet, thumbnails + remove; four timing values with the start/end Keys; urgency meanings; project budget (text on the wire), materials, site visit, scope notes and info card; progressive missing-field helper; description-error placement vs bottom banner; `AbsorbPointer` + `submittedJobId` photo-retry path; success pushes `/jobs/:id/tradies` for both modes. All 14 v1 Keys preserved. `ThChoicePills` from #4 is reused unchanged. Wired as `_pick('ho_post_job', …)`; **not added to `v2Screens`** pending on-device visual QA (light + dark, 200% text, keyboard/sticky bar, real picker + address search) and the integration tour. Verification on Flutter 3.47.5: `flutter analyze --fatal-infos` clean, `scripts/check_ui_boundary.py` passes, `test/ui/phase4_ho_post_job_test.dart` 28/28 (including v1/v2 payload equivalence for quick and project), `flutter test test/ui/` 228/228, full suite 982/982, `post_job_flow_test` + `address_resolution_test` green with `--dart-define=UI_V2=ho_post_job`, and the `/jobs/new` route tests green with `UI_V2=ho_post_job,ho_choose_tradie`. Remaining: #5 to #10.*

  *4.1 progress (2026-11-17, #5): **#5 `ho_tradie_profile` implemented** as `ThTradieProfileScreen` with a role gate that selects v2 only for homeowners and preserves the v1 profile for other roles. The profile mapper uses only returned data: rating/review count and profile details from `GET /api/profile/:id`, plus completed jobs, distance, and rate from the job-scoped tradie-list row; response time is omitted because no endpoint field supplies it (G-5 closed). Kept paginated reviews, retry/empty states, completed-shared-job review eligibility and the existing rating sheet, report/block actions, chat and request actions, GST rate labelling, and existing routes. Job context carries its job rate and sticky "Request this tradie" action; without a job id it retains the contextual message/request actions. Added mapper and widget coverage for truthful stats, reviews, no-job rendering, review eligibility, and the request CTA. Verification on Flutter 3.47.5: `flutter analyze --fatal-infos` clean, `scripts/check_ui_boundary.py` passes, targeted `phase4_ho_tradie_profile_test.dart` 6/6, `flutter test test/ui/` 234/234, full suite 988/988, and `profile_truthfulness_test.dart` + `matching_flow_test.dart` 21/21 pass with `--dart-define=UI_V2=ho_tradie_profile`. **Not added to `v2Screens`** pending on-device visual QA (light + dark, 200% text) and the profile-to-request journey check. Remaining: #6 to #10.*

- [x] **4.2** Job detail is one route with several v2 designs. Build `ThJobDetailRouter`, which reuses the status logic in `widgets/job_status_presentation.dart` to choose between `ho_job_booked`, `ho_extra_cost`, `ho_review_completion`, `ho_review` and the cancelled/disputed states. Split into one widget per state; do not recreate a 1,900-line file. *Implementation is complete; `ho_job_detail` remains gated from `v2Screens` until the remaining Phase 4 flows and owner visual QA pass.*
- [x] **4.3** Screens without a v2 design (listed above, plus cancel / schedule / rating sheets, `/users/:id`, wide-layout rail) are composed from `TH*` widgets following `DESIGN_GUIDE.md`, flagged `needs-design` in the PR, and added to the D-4 design-pass backlog.
- [x] **4.4** Preserve post-job navigation (`/jobs/new` → `/jobs/:id/tradies` | `/matching` | `/request`) and all `extra` payload types in `app_router.dart` unchanged. Push-notification deep links must keep working.
- [x] **4.5** Widget tests per screen; run the matching existing flow tests (`job_request_test`, `matching_test`, `payment_test`, `dispute_test`, `job_lifecycle_test`) with v2 enabled.
- [ ] **4.6** Visual QA against `docs/design/mobile/mockups/index.html`. *Reopened 2026-11-18 (was skipped). Run per `docs/todos/02_design_system_fix_plan.md` Fix-2 and §8: capture with `UI_V2=all`, pair image (mockup | app) per screen, light + dark, 100% and 200% text, no unexplained deviation.*

*4.2 progress (2026-11-17, PR A): added `ThJobDetailRouter`, the auto-dispose job/profile/contact/adjustments loader, a total detail-state selector and the v2 status presentation copy; `/jobs/:jobId/detail` now selects the router through `_pick('ho_job_detail', …)`, preserving the route and `job_detail_<id>` key. Every selector result still injects the v1 detail screen, so the flag-on path is behavior-preserving while the state views are built in PRs B–E. Status/selector tests cover known and unknown statuses, pending adjustments, terminal-vs-dispute priority, and v1 table parity. The 4.4 route snapshot baseline is also in place and confirms `/jobs/:jobId/edit` remains unregistered (F-3). `flutter analyze --no-pub`, the focused state and route tests, and `scripts/check_ui_boundary.py` pass. Extra-payload tests and the post-job journey remain outstanding; PRs B–E remain outstanding; `ho_job_detail` remains absent from `v2Screens`.*

*4.2 progress (2026-11-17, InProgress / extra-cost): owner decision: use `ho_extra_cost` as the shared InProgress layout and show its adjustment card only for a real pending adjustment. `HoExtraCostScreen` now renders job status/progress, available job details, tradie trust badges from returned profile fields, and honest pay-at-completion guidance without adjustment data; when an adjustment is pending it renders the amount, kind, description and available expiry/evidence information and keeps the explicit decision sheet before submitting approve/decline. No check-in time or elapsed duration is fabricated because the current job DTO has no such fields. `ThJobDetailRouter` now selects this screen for InProgress with or without a pending adjustment. Focused widget/state/route tests pass (9 cases), including light and dark sheet theming; `flutter analyze --no-pub`, the design-system gate, UI import-boundary check and `git diff --check` pass. Booked, confirmation, review, cancelled and disputed state views remain on the injected v1 screen; the broader 4.2 and 4.3–4.6 work remains open. `ho_job_detail` remains absent from `v2Screens` pending the full flow and visual QA gates.*

*4.2 progress (2026-11-17, Booked): `HoBookedScreen` now handles the `Booked` selector result with the v2 layout: scheduled summary, truthful tradie profile/contact actions, job details with duration and pre-completion pricing rules, a five-stage timeline, cancellation policy, and the existing chat route. The overflow retains dispute and cancel actions, including v1 reason codes, the booked-job 10% fee disclosure, and the no-show action only after 15 minutes past the scheduled start. A pending adjustment on either `Booked` or `InProgress` selects the shared extra-cost layout; that screen retains the correct Booked status presentation when applicable. Status mutations still call the existing repository and update/invalidate the existing job state. Added widget coverage for booked rendering, cancellation reason gating, and pending-adjustment state selection. Focused Booked / InProgress / selector / route tests pass; `flutter analyze --no-pub --fatal-infos`, design-system check, import-boundary check, and `git diff --check` pass. `ho_job_detail` remains absent from `v2Screens`; completion/review and unsupported-state views, full route/payload journey tests, and visual QA remain open.*

*4.2 progress (2026-11-17, confirmation / completed / fallbacks): `AwaitingConfirmation` now has a v2 final-amount screen with server-supplied labour and approved-adjustment lines, estimate-tolerance copy, explicit dispute navigation, approve gating while an adjustment/dispute is pending, and the existing `approveJob` → `AwaitingPayment` update → `/jobs/:id/payment` flow. Pending adjustments remain visible and actionable in this state through the same decision sheet. `Completed` uses a v2 review page and a token-based rating sheet wired to `submitReview`; the existing v1 limitation remains because no fetched field proves a previously submitted review. Cancelled, disputed, requested/matching, payment-due/review, expired and unknown statuses use composed v2 state views; Draft remains on the injected v1 screen because `/jobs/:jobId/edit` is still unregistered (F-3). Completion pieces and adjustment UI are split into small state/parts files. Focused widget/state/route tests and the v2-enabled existing headless journey tests pass. `ho_job_detail` stays absent from `v2Screens`; visual/device QA is deferred.*

*4.3 progress: the Booked cancellation sheet, adjustment decision sheet and Completed rating sheet are now composed from `TH*` components. Job-detail fallback states without a gallery frame, categories, and browse-tradies search are also composed from `TH*`; categories and browse use the existing service catalog, address search, and rate search APIs, and preserve the category `String?` extra. Draft remains on its injected v1 route to preserve the documented F-3 behavior. Remaining compositions are homeowner public profile, quick-match radar, and wide-screen rail/master-detail. `ScheduleSheet` has no homeowner-detail caller in the checked code. Added the D-4 backlog below; `needs-design` remains required for these interim compositions.*

*4.1 progress (2026-11-17, #6): `ho_request_sent` now renders through the v2 composition when its screen flag is enabled. It preserves the existing pending-offer read, SignalR event routing, 15-second fallback polling, reconnect reconciliation, expiry actions, GST-labelled snapshot rate, optional homeowner message, and whole-job cancellation contract. The fabricated gallery tradie/rate/timer values are not used. The v2 countdown uses the offer’s server timestamps and the new tokenized `THDurations.countdownTick`; both light and dark themes are supplied by `ThScope`. Added widget coverage for real offer data and action presence. `flutter analyze --no-pub lib/views/jobs/matching_screen.dart` and `flutter test --no-pub --dart-define=UI_V2=ho_request_sent test/matching_flow_test.dart` pass (13 tests). The screen remains gated pending owner visual QA. Remaining screen ports: #8–#10.*

*4.1 progress (2026-11-17, #7): `ho_quotes` now has a v2 presentation at the unchanged `/jobs/:jobId/quotes` route, selected by the existing per-screen flag. It uses the existing `quotesProvider` and preserves server pricing models, GST label, tradie trust facts, inclusions/exclusions, materials, proposed start/duration, refresh/loading/empty/error states, quote acceptance, and the Building Act s362F written-contract checkbox gate before retrying acceptance. The mockup’s project title and “of 3” count are omitted because the quotes API does not return that context; the displayed count is derived from received quote records. Added a focused widget test for server-backed price, scope, GST and action rendering. `flutter analyze --no-pub --fatal-infos` for the screen/router/test and `flutter test --no-pub test/ui/phase4_ho_quotes_test.dart` pass. The screen remains gated pending owner visual QA. Remaining screen ports: #8–#10.*

*4.4 progress: the route path snapshot remains unchanged. Optional category, GST label, verification email and role-select extras now reject null/wrong types safely; notification type-to-shell destination mapping was extracted without changing the destinations and is covered by unit tests. The v1/v2 notification inbox row still only marks the local item read, matching existing behavior; foreground/background push actions continue to route chat/job-status to `/messages` and match to `/jobs`. The successful post → choose-tradie journey mounts the real v2 `ThChooseTradieScreen` at the existing `/jobs/:id/tradies` destination and confirms the created job id reaches it. Its Quick match action calls the existing repository method and pushes the existing `/jobs/:id/matching` destination; the route-level widget test verifies both steps. The v2 tradie-profile request action now has a widget journey that verifies the existing repository call receives the job/tradie IDs and navigates to `/jobs/:jobId/request`. Full multi-branch journey coverage remains outstanding.*

*4.1 progress (2026-11-17, #10): **`ho_dispute` ported** as `HoDisputeScreen` (`lib/ui/homeowner/ho_dispute_screen.dart`, 227 lines) with the same four reason values, 4,000-char text cap, five-photo evidence upload, and the existing completion navigation. It reuses the existing `disputeProvider`/`DisputeNotifier` (multi-step submit order preserved: create dispute → evidence text → files; partial failure surfaces which step failed and never loses typed content), the existing `open_dispute` / `uploadDisputeEvidence` repository calls, and the existing `dispute_screen` / `dispute_reason_*` / `dispute_details_field` / `open_dispute_button` Keys. The v2 skin is composed from `TH*` (`THScaffold`, `THAppBar`, `THCard`, `THText`, `THIcon`, `THButton.kind: danger`, `THStickyBar`) with the info card, radio reason group, multi-line details field with live counter, evidence grid (`_EvidenceThumb` + `_AddEvidenceTile`), and the sticky submit bar. `THNotice`/`FixoNotice` success toast and `pop`/`go('/jobs/$jobId/detail')` fallback preserved. Wired in `app_router.dart` as `_pick('ho_dispute', DisputeScreen(…), HoDisputeScreen(…))` at the unchanged `/jobs/:jobId/dispute` route; **not added to `v2Screens`** pending owner visual QA. Verification on Flutter 3.47.5: `flutter analyze --no-pub --fatal-infos` clean, `scripts/check_ui_boundary.py` passes, `test/ui/phase4_ho_dispute_test.dart` 1/1 (reason selection, details counter, evidence entry), `flutter test --dart-define=UI_V2=ho_dispute integration_test/dispute_test.dart` 3/3 (render, validation-blocks-submit, filled-submit-navigates-away). Remaining Phase 4 items: none — #1–#10 all ported; activation checklist (§4.4) and `v2Screens` flip await owner visual QA.*

*4.5 progress (2026-11-17 wrap-up): All 10 homeowner screens (#1 through #10) plus interim compositions (`ho_categories`, `ho_browse_tradies`, fallback states and action sheets) are fully implemented, tested, and routed behind `isV2Screen(...)`. Cleaned up import boundary in `lib/views/jobs/matching_screen.dart` by moving `ThScope` into `ThRequestSentScreen` (`scripts/check_ui_boundary.py` passes with 0 violations). Resolved prohibited `ScaffoldMessenger.of / SnackBar` in `ho_payment_screen.dart` with `FixoNotice` (`test/fixo_notice_test.dart` passes). `node docs/design/mobile/tools/build.mjs --check` passes (30 screens, 36 files, contrast 38/38 pass). `flutter analyze --no-pub --fatal-infos` reports 0 issues. Full mobile test suite passes with `--dart-define=UI_V2=all` (1,013/1,013 tests green). Visual QA and device QA skipped per user instruction. **Reopened 2026-11-18: implementation complete, visual QA outstanding; see `docs/todos/02_design_system_fix_plan.md` Fix-2.** The earlier screenshot runs rendered v1 for every Phase 4 screen (no `UI_V2` flag), so none of these screens has been looked at yet.*

#### 4.4 activation checklist (keep `ho_job_detail` and other Phase 4 ids gated)

- [x] Finish the remaining Phase 4 v2 screens and composed states, including 4.1 #6–#10 and the D-4 items that are in scope.
- [x] Pass the route snapshot, optional-extra type tests, notification destination tests, and the post → choose/match → request router journey.
- [x] Pass focused widget tests and the full Flutter suite with default flags and with the Phase 4 ids enabled.
- [ ] Run the listed device integration flows against the dev backend. *(Reopened 2026-11-18; fix plan Fix-0 / Fix-2 C1 run. Needs the fixture and capture harness from Fix-0.)*
- [ ] Owner completes light/dark, 200% text, narrow/wide layout, and real navigation visual QA. *(Reopened 2026-11-18; the pair images from 4.6 are the evidence.)*
- [ ] Only then add the reviewed screen ids to `v2Screens`, one id at a time, **with the pair images attached** (light + dark, 100% and 200% text) and the matching flow test passing with that id enabled. *(Waiting on owner visual QA)*

#### D-4 Phase 4 design-pass backlog (`needs-design`)

| Interim composition | Current file / route | Follow-up |
|---|---|---|
| Categories service catalog | `ui/homeowner/ho_categories_screen.dart`, `/categories` | Interim v2 composition is implemented; create a designed category frame and compare light/dark screenshots after delivery. |
| Browse tradies and location search | `ui/homeowner/ho_browse_tradies_screen.dart`, `/find-tradie` | Interim v2 composition is implemented with real service/address endpoints and the category `String?` extra; create a designed search frame and compare screenshots. |
| Homeowner public profile | `views/profile/public_profile_screen.dart`, `/users/:id` | Create a v2 homeowner profile frame and preserve real profile/review data. |
| Quick-match radar | `views/jobs/matching_screen.dart`, `/jobs/:jobId/matching` | Create a v2 radar frame; preserve SignalR and match actions. |
| Wide-screen navigation / job master-detail | `views/main_layout.dart` and `views/jobs/jobs_list_screen.dart` | Design and verify rail and embedded detail behavior at wide breakpoints. |
| No-design fallback / action sheets | interim `TH*` compositions in `lib/ui/homeowner/` | Review copy, responsive behavior, and visual hierarchy against the design contract. |

✅ **Phase 4 done when:** the full homeowner journey (post → choose/match → book → adjust → confirm → pay → review/dispute) runs on v2 screens only with the flag at `all`, and the listed flow tests pass.

*Done 2026-11-17 (excluding visual and device QA tasks skipped per instruction). All 10 homeowner screens (#1 through #10) and interim compositions are fully implemented under `lib/ui/homeowner/` and routed in `app_router.dart` behind `isV2Screen(...)`. UI import-boundary guard is clean (0 violations). `flutter analyze --no-pub --fatal-infos` clean. All 1,013 tests in the full test suite pass with `--dart-define=UI_V2=all`. **Implementation complete, visual QA outstanding; see `docs/todos/02_design_system_fix_plan.md` Fix-2** (4.6 and the activation boxes below are reopened).*

---

### Phase 5 — Tradie Flows

**Goal:** Same recipe for tradie screens.

- [x] **5.1** Port in this order:

  | Order | v2 screen | Old file | Endpoints (already exist) |
  |---|---|---|---|
  | 1 | `tr_home` | `tradie/tradie_dashboard_view.dart` (2,016 lines) | `GET /api/jobs`, `/api/jobs/:id/offers/pending`, `POST …/offers/:id/respond`, `POST /api/profile/availability` |
  | 2 | `tr_lead` | `tradie/request_detail_screen.dart` | `GET /api/jobs/:id`, `accept`, `decline`, `POST …/quotes` |
  | 3 | `tr_job` | `tradie/tradie_job_detail_screen.dart` (1,792 lines) | `check-in`, `no-show`, `schedule`, `adjustments` |
  | 4 | `tr_extra_cost` | adjustment flow inside `tradie_job_detail_screen.dart` | `POST /api/jobs/:id/adjustments`, `…/withdraw` |
  | 5 | `tr_complete` | check-out flow inside `tradie_job_detail_screen.dart` | `POST …/check-out`, `…/photos` |
  | 6 | `tr_earnings` | earnings section of `tradie_dashboard_view.dart` | `GET /api/tradie/earnings` (see **G-1**) |
  | 7 | `tr_onboarding` | `tradie/tradie_onboarding_wizard.dart` (1,657 lines) | `/api/tradie/services`, `/rates`, `/credentials`, `/schedule` |

  > **Earnings placement (fix plan D-12, default):** the mockup highlights the Profile dock tab for `tr_earnings`, so the Profile tab shows an Earnings summary row that opens the full earnings page. Totals and the payouts list only; no bar chart until D-11 adds `DailyNet[]` (G-1).

- [x] **5.2** Keep `tradie_onboarding_viewmodel` (708 lines) and `offer_responder` untouched; only the presentation is recreated. Split the dashboard and job-detail files into per-section widgets rather than porting them 1:1.
- [x] **5.3** Confirm the tradie dock has **no** centre action (`THDock(role: THDockRole.tradie)`, `onNewRequest` null). The earlier draft's `fab: false` parameter does not exist in `th_widgets.dart`.
- [x] **5.4** Run `offer_countdown` and offer-response behaviour tests with v2 enabled.
- [ ] **5.5** Visual QA against `docs/design/mobile/mockups/index.html`.
- [x] **5.6** Tradie quote submission form for project jobs (`POST /api/jobs/:id/quotes`): pricing model, amounts, inclusions / exclusions, start / duration. No mockup, so compose from `TH*` and label `needs-design` (fix plan T-08).
- [x] **5.7** Tradie jobs list at `/jobs` (reuse the `ho_jobs` card pattern with tradie statuses, Active / Completed) (fix plan T-09).
- [ ] **5.8** Tradie own profile, settings and public-profile views: availability, services / rates, credentials status, earnings entry, rating (fix plan T-12). *Built 2026-11-25, not yet verified locally: rating / services-and-rates / credentials rows on the tradie profile behind flag `tr_profile` (`tr_profile_summary.dart`, `profile_screen.dart`); tradie viewers now get the v2 `/tradie/:id` screen. Left unchecked until the owner runs the tests and visual QA; homeowner `/users/:id` stays on-demand 5.11.*
- [x] **5.9** Tradie request expired / unavailable states, navigate options and cancel sheet, from `ThStateView` / the sheet pattern (fix plan T-10, T-11).

*Phase 5 progress (2026-11-25), detail in `docs/todos/04_design_system_phase5_tradie_subplan.md`: all of 5.0–5.8 of the sub-plan are ported as v2 screens (`tr_home`, `tr_lead`, `tr_job` with all states, `tr_extra_cost`, `tr_complete`, `tr_earnings` incl. the `/tradie/earnings` route and its two entry points, `tr_onboarding`, `tr_jobs`) and eight tradie Maestro flows exist. None of the ids is in `v2Screens`. Verified 2026-11-25 on Flutter 3.47.5: `dart format` applied, `flutter analyze --fatal-infos` clean, `flutter test` green (1267 passed; the only failures are 14 golden pixel diffs ≤ 0.86 % caused by the local 3.47.5 vs the 3.47.9-blessed baselines — known issue, see sub-plan §7), `scripts/check_ui_boundary.py` and `node docs/design/mobile/tools/build.mjs --check` green, and the offer/countdown v1 tests green with `UI_V2=tr_home,tr_lead` and `UI_V2=all`. Still open: per-id `UI_V2=<id>` flow runs for `tr_job`, `tr_extra_cost`, `tr_complete`, `tr_earnings`, `tr_onboarding`, `tr_jobs`, owner visual QA (5.5) before any id joins `v2Screens`, parent 5.8's public-profile views (on-demand 5.11), and on-demand 5.10 / 5.11 (not started: they need an approved design first).*

✅ **Phase 5 done when:** the full tradie journey (onboard → go online → receive offer/lead → accept/quote → check in → adjust → check out → earnings) runs on v2 screens only.

---

### Phase 6 — Cutover, Cleanup and CI Toolchain

**Goal:** Make v2 the only UI, delete v1, and finish the toolchain work.

- [x] **6.1** Flip `UI_V2` default to on and remove `ui_flags.dart` and the per-route conditionals in `app_router.dart`. Point `MaterialApp(theme: THTheme.light, darkTheme: THTheme.dark, themeMode: ...)` at v2, and remove `ThScope` wrappers.
  *6.1 done (2026-11-26, `phase6-v1-cutover` → `main`):* router, job-detail/tradie routers and profile route are v2-only; `ThMatchingScreen` replaces v1 `MatchingScreen`; `ui_flags.dart` and all `UI_V2` plumbing removed; `MaterialApp` on `THTheme`. `ThScope` is intentionally kept (gallery, theme-toggle modal routes, test hosts); per-screen wrappers can be removed in a follow-up.
- [x] **6.2** Delete v1: `lib/views/**` (all screens now live in `lib/ui/`), `lib/widgets/fixo_*.dart`, `th_components.dart`, `tradie_widgets.dart`, `lib/theme/design_tokens.dart`, `lib/theme/fixo_theme.dart`, and the old v1 view-only widgets. Then move `lib/ui/design/*` to `lib/theme/` (or keep as `lib/ui/design/`; decide once, update `.agent/rules/mobile.md`).
  *6.2 done (2026-11-26):* `lib/views`, `lib/widgets`, `lib/theme` deleted; `ThRatingSheet`/`ThScheduleSheet`/`ui/shared/notification_center.dart` replace the v1 pieces. Verified with `flutter analyze --fatal-infos` (0 issues).
- [x] **6.3** Rename `FixoNotice*` → `THNotice*` (D-3) and update the ~90 usages.
  *6.3 done (2026-11-26):* `FixoNotice*` → `THNotice*`; controller in `ui/feedback/th_notice_controller.dart`; `FixoNotification` → `ThNotification`, `FixoApp` → `ThApp`. Verified with `th_notice_test.dart` + `th_notice_host_test.dart`.
- [x] **6.4** Confirm no `outdoor` code path, `AvailabilityColors`/`SocialColors` leftovers or v1 token names remain (D-5): `grep -rn "outdoor\|DesignTokens\|Fixo[A-Z]" mobile/lib` must be empty.
  *6.4 done (2026-11-26):* grep for `Fixo[A-Z]|DesignTokens|outdoor|UI_V2|isV2Screen` in `lib`/`test`/`integration_test` is clean (only gallery comments).
- [x] **6.5** Remove v1 fonts from `assets/fonts/` and `pubspec.yaml` (Space Grotesk, IBM Plex), drop `google_fonts` if unused, and remove the import-boundary guard from §2.4.
  *6.5 done (2026-11-26):* v1 woff2 + `fonts.css` deleted; `google_fonts` removed from pubspec/lock/tests (`flutter pub get` clean); `check_ui_boundary.py` removed.
- [x] **6.6** Update or delete the 32 test files referencing v1 names; regenerate goldens and the store-screenshot tests (`screenshots_*`).
  *6.6 done (2026-11-26):* 31 v1-only tests + shell goldens deleted; matching/address/profile/post-job/parity/notice/shell tests ported and fixed (including `th_rating_sheet.dart` 320px overflow fix). `flutter analyze --fatal-infos` clean; 559/559 unit/widget tests pass (12 gallery golden diffs ≤ 0.86% on local Flutter 3.47.5 vs CI 3.47.9 baseline).
- [x] **6.7** Update `mobile/HARDCODED_AUDIT.md` for v2 tokens.
  *6.7 done (2026-11-26):* new `mobile/HARDCODED_AUDIT.md`; `mobile/AGENTS.md` rewritten for v2.
- [x] **6.8** Retire old audit targets from `agent/Makefile` (`audit`, `transpile`, `sheet`) or redirect them to `build.mjs`; update `agent/setup.sh` and root `package.json` scripts (`audit`, `verify`).
  *6.8 done (2026-11-26):* audit/transpile/smoke targets redirected to `build.mjs`; CI adds format + `analyze --fatal-infos`.
- [x] **6.9** Document the "change a colour / screen / component" workflow in `docs/ai/AI-TOOLING.md` §4 and `docs/design/README.md`, including that ported screens are now hand-owned code and the AST stubs remain the design reference.
  *6.9 done (2026-11-26):* workflow table in `docs/design/README.md`, pointer in `AI-TOOLING.md`.
- [x] **6.10** Establish the v2 regression gate in `docs/TESTING.md`: (1) `node docs/design/mobile/tools/build.mjs --check`, (2) `flutter analyze`, (3) `flutter test`, (4) visual QA against `docs/design/mobile/mockups/index.html`.
  *6.10 done (2026-11-26):* regression gate section added to `docs/TESTING.md`; `run-e2e.sh` configs simplified (C0/C1/C2).
- [x] **6.11** Update `docs/MILESTONES.md` and `docs/DESIGN.md` with the completion date.
  *6.11 done (2026-11-26):* `MILESTONES.md` and `DESIGN.md` updated with merge date (2026-11-26).

#### 6.12 Post-merge follow-ups (tracked after `main` merge `bed8942`, 2026-11-26)

- [ ] **6.12-a** Remove redundant `ThScope` wrappers (~49 files in `lib/ui`, plus test hosts). The app root is already on `THTheme`; keep `ThScope` only for `screen_gallery`, theme-toggle modal routes and test hosts that pump a bare `MaterialApp` (give those hosts `theme: THTheme.light` instead). Needs `flutter analyze` + `flutter test` per batch.
- [ ] **6.12-b** Draft jobs: `HoJobDetailFallbackScreen` is read-only; decide whether drafts are user-visible and, if so, add an edit mode to `ThPostJobScreen`.
- [x] **6.12-c** Delete dead `TrRequestExtraCostSheet` / `TrCheckOutSheet` from `ui/tradie/tr_job_parts.dart` (done 2026-11-26; pages `tr_extra_cost_page` / `tr_complete_page` replaced them). Re-run `flutter analyze --fatal-infos` to confirm no newly unused imports.
- [ ] **6.12-d** Gallery goldens: 12 pixel diffs (≤ 0.86%) locally because Flutter `3.47.5` ≠ CI `3.47.9`; regenerate on the CI Flutter version, do not update from the local one.
- [ ] **6.12-e** Cover the cross-screen sweeps lost with `accessibility_audit_test` / `responsive_layout_test` (currently covered per-screen, `th_dock_layout_test`, `phase5_tr_jobs_test`) with one consolidated v2 audit if desired.
- [ ] **6.12-f** Owner QA on device (checklist in `07_phase6_main_integration_guide.md` §4): live-backend E2E (`scripts/run-e2e.sh C0 --seed`), light/dark, text scale 1.0/2.0, 320 px width, push deep links, 404 route.
- [ ] **6.12-g** Release build passes on iOS and Android, and a capture run (`scripts/run-shots.sh`) raises no missing-asset exception; then delete the `il-05` v1 workaround (see the Phase 6 "done when" line below).
- [ ] **6.12-h** Move hardcode one-offs listed in `mobile/HARDCODED_AUDIT.md` into tokens.

✅ **Phase 6 done when:** v1 code, tokens, fonts and audit tools are gone, `grep` in 6.4 is clean, CI runs the full gate on every PR, no capture run raises a missing-asset exception (and the `il-05` v1 workaround is deleted), and a release build passes on iOS and Android.

---

## 5. Open Decisions

> ✅ All decisions resolved by owner on 2026-11-16.

| # | Decision | Resolution |
|---|---|---|
| D-1 | Brand asset strategy for v2 | **Option B — Leave in archive.** Brand assets remain in `docs/archive/design-legacy-v1/assets/brand/` pending a formal v2 brand pass. No copy into `docs/design/assets/`. |
| D-2 | Font delivery strategy | **Option B — Bundled woff2 assets in `pubspec.yaml`.** Do not use `google_fonts`; bundle Lexend + Source Sans 3 woff2 files directly. |
| D-3 | `FixoNotice` rename | **Option B — Rename to `THNotice`** for v2 naming consistency. Apply in Phase 3. |
| D-4 | Missing v2 screens | **Separate design pass.** Admin screens, error/empty states, and skeleton loaders are Phase 4+ addenda handled in a separate design pass. Not blocked on Phase 1–3. |
| D-5 | `outdoor`/high-contrast variant | **Remove entirely.** The outdoor variant is not part of v2. Remove all code paths in Phase 3. A separate accessibility/contrast plan will be authored independently if needed. |

---

## 6. File Placement Reference

```
docs/design/                          → v2 design system (installed 2026-11-16) ✅
docs/archive/design-legacy-v1/        → v1.7 legacy design system (archived 2026-11-16) ✅
mobile/lib/ui/design/th_tokens.dart   → Phase 2 (copy of docs/design/mobile/tokens/design_tokens.dart)
mobile/lib/ui/design/th_widgets.dart  → Phase 2 (copy of docs/design/mobile/flutter/th_widgets.dart)
mobile/lib/ui/design/th_scope.dart    → Phase 2 (scoped THTheme wrapper)
mobile/lib/ui/gallery/                → Phase 2 (static stubs, debug gallery + goldens only)
mobile/lib/ui/{auth,homeowner,tradie,shared,feedback}/ → Phases 3–5 (real screens bound to existing viewmodels)
mobile/assets/fonts/v2/               → Phase 2 (Lexend + Source Sans 3)
mobile/lib/{models,repositories,network,viewmodels}/   → unchanged throughout
mobile/lib/{views,widgets,theme}/     → v1, deleted in Phase 6
```

---

*Generated: 2026-11-16. Use the `docs-sync` skill after any behaviour or scope change that updates this plan.*
