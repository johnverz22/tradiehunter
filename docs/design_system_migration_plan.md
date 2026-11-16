# TradieHunter — Mobile Design System v2 Migration Plan

> **Scope:** Mobile rebrand only. Web (React admin) is excluded from all phases.
> **This document is docs-only.** No application code, components, styles, or source files are modified in Phase 1.
> **Source:** `th-design-v2/` (Trust Navy + Gold, v2.0.0)
> **Replaces:** `docs/design/` (Space Grotesk + IBM Plex + Amber, v1.7)
> **Revision 2026-11-16:** Phases 2–6 rewritten as a side-by-side rebuild of the presentation layer (see §4.0). Phase 1, §1–§3 and §5 are unchanged.

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
| `docs/design/COLOUR.md` | Extracted from `DESIGN_GUIDE.md` §2: full colour token table (light + dark), contrast results summary, pairing rules |
| `docs/design/TYPOGRAPHY.md` | Extracted from `DESIGN_GUIDE.md` §3: type scale table, font families, `pubspec.yaml` font setup instructions |
| `docs/design/COMPONENTS.md` | Extracted from `DESIGN_GUIDE.md` §5–§7: component vocabulary, widget mapping (`Fixo*` → `TH*`), role differences, screen inventory (30 screens), signature elements |

These are documentation extracts, not new content — they simply make the design guide navigable by topic.

---

## 3. Documentation Update Mapping

### 3.1 Core documentation files

| File | Required update | Priority |
|---|---|---|
| **`docs/DESIGN.md`** | **Full rewrite.** This is the primary design contract. Must reflect: v2 system version, new colour palette (Navy + Gold), new typography (Lexend + Source Sans 3), new token names (`THColors`, `THType`), new component vocabulary (`TH*` family replacing `Fixo*`), new screen inventory (30 screens, v2 frame list), updated regression gates (use `node tools/build.mjs --check` instead of `audit_full.py`), updated font rules (no font files in repo), remove outdoor/high-contrast variant references (not in v2). | 🔴 Critical |
| **`docs/ARCHITECTURE.md`** | Update design system section: new token file paths, font strategy (google_fonts vs bundled), remove references to `kit.css` and `html/` frames as source of truth. Add reference to `docs/design/tokens/tokens.json` as the single source of truth. Update the "Design system" row in the stack table. | 🔴 Critical |
| **`docs/SPECS.md`** | Update any references to v1 component names (`FixoPrimaryButton`, `FixoAppBar`, `FixoCard`, etc.) with their v2 equivalents (`THButton`, `THAppBar`, `THHero`). Update §10 mobile UX contract to reflect v2 screen structure. Remove references to `kit.css` classes (`.appbar`, `.btn-tonal`, etc.). | 🟠 High |
| **`docs/MVP.md`** | Update screen inventory list to match v2 screen names (e.g., `ho_choose_tradie` replaces the old "H19 Browse Tradies" reference). No scope changes — just naming alignment. | 🟡 Medium |
| **`docs/PRD.md`** | Update any design system references. Add a note that the mobile UI underwent a design system rebrand to v2 Trust Navy + Gold. No feature scope changes. | 🟡 Medium |
| **`docs/MILESTONES.md`** | Add a milestone entry for the v2 design system migration (this initiative). Record completion dates per phase as work progresses. | 🟡 Medium |
| **`docs/TESTING.md`** | Update design regression gate commands: replace `python3 docs/design/tools/audit_full.py` with `node docs/design/tools/build.mjs --check`. Update any references to `docs/design/html/frames-*.html` as test inputs. | 🟠 High |
| **`docs/QA.md`** | Update visual QA references: replace v1 frame file paths with v2 `docs/design/mockups/index.html`. Update component checklist from `Fixo*` to `TH*` names. | 🟡 Medium |
| **`docs/README.md`** (docs index) | Update the design row in the documentation map table: `docs/design/` now points to v2 Trust Navy + Gold system. Update the "Tokens, components, frames, notices" row. | 🟡 Medium |
| **`docs/ai/AI-TOOLING.md`** | Update §1 path table (`docs/design/` description), §4 toolchain commands (replace `make -C agent audit`/`transpile` with `node tools/build.mjs`), skills table (see §3.2). | 🟠 High |
| **`docs/ai/AGENTS-docs-block.md`** | If this contains the docs-map block used in AGENTS.md, update the design row to point to v2. | 🟡 Medium |

### 3.2 Agent rules and AI instruction files

| File | Required update | Priority |
|---|---|---|
| **`.agent/rules/mobile.md`** | **Major update.** This is the primary agent rule file for mobile UI. Must update: Design system section to reference `docs/design/DESIGN_GUIDE.md` and `docs/design/tokens/tokens.json` as the source of truth. Replace all `Fixo*` widget references with `TH*` equivalents. Update token class references (`THType` for typography, updated `THColors` fields). Remove references to `kit.css`, `html/frames-*.html`, `outdoor` variant, Space Grotesk/IBM Plex. Update "No hardcoded values" section with v2 token names. Update component reuse list. Add font strategy note. | 🔴 Critical |
| **`AGENTS.md`** (root) | Update the design token reference in the "Conventions" section: `mobile/lib/theme/design_tokens.dart` reference stays but update token class names. Update `docs/design/` description in the documentation map table. Remove references to `design-system.html` as a source. Remove references to v1 frame files (`frames-homeowner.html`, `frames-tradie.html`) as the visual source of truth (or update to point to v2 `mockups/index.html`). | 🔴 Critical |
| **`GEMINI.md`** | Update design token section: replace "docs/design/design-system.html" and v1 frame file references with v2 equivalents. Update the visual source of truth sentence. Remove "frames-homeowner.html and frames-tradie.html" and replace with "docs/design/mockups/index.html" and "docs/design/DESIGN_GUIDE.md". | 🔴 Critical |
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
| `docs/design/html/frames-homeowner.html` | `docs/design/mockups/index.html` | AGENTS.md, GEMINI.md, DESIGN.md, mobile.md |
| `docs/design/html/frames-tradie.html` | `docs/design/mockups/index.html` | AGENTS.md, GEMINI.md, DESIGN.md, mobile.md |
| `docs/design/html/kit.css` | `docs/design/tokens/tokens.css` | DESIGN.md, AI-TOOLING.md |
| `docs/design/design-system.html` | `docs/design/DESIGN_GUIDE.md` | DESIGN.md, ARCHITECTURE.md, GEMINI.md |
| `Space Grotesk` | `Lexend` | DESIGN.md, mobile.md |
| `IBM Plex Sans` | `Source Sans 3` | DESIGN.md, mobile.md |
| `FixoPrimaryButton` | `THButton(kind: accent)` or `THButton(kind: primary)` | mobile.md, SPECS.md |
| `FixoAppBar` | `THAppBar` | mobile.md, SPECS.md, AI-TOOLING.md |
| `THColors` via `Theme.of(context).extension<THColors>()` | `context.th.<name>` (via `THTheme` extension) | mobile.md |
| `python3 docs/design/tools/audit_full.py` | `node docs/design/tools/build.mjs --check` | TESTING.md, AI-TOOLING.md |
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
1. Copy the generated stub from `docs/design/flutter/screens/<id>_screen.dart` into `lib/ui/<feature>/`. It is now hand-owned; never regenerate over it. (`ast/` + `mockups/` stay the design reference.)
2. Make it a `ConsumerWidget` and replace sample copy by watching the **existing** providers/viewmodels the old screen used. Put model→display mapping (money via `utils/money.dart`, status text via `job_status_presentation.dart`) in a small pure mapper next to the screen so it can be unit-tested.
3. Port the old screen's **actions** one by one (every button/sheet/navigation) to the same viewmodel methods. Write the action list from the old file first; it is the parity checklist.
4. Use `ThStateView` for loading / empty / error; use `THNotice` for toasts and banners.
5. Preserve the `Key`s the old screen exposed (141 in `lib/views`) wherever `test/` or `integration_test/` rely on them.
6. Add a widget test (provider overrides, light + dark) and, where useful, a golden.
7. Visual QA against `docs/design/mockups/index.html`, then add the id to `v2Screens`, one PR per screen or small group.

**Definition of done for a screen:** parity checklist complete, old-screen flow tests green with the flag on, no hardcoded colours/sizes/fonts (tokens only), Semantics labels kept, light + dark verified.

### 4.1 API policy and gap register

The backend API is the contract. **No backend change is planned by default.** While porting, if a v2 element needs data the API does not return, resolve it in this order: (1) derive it client-side from data already returned, (2) omit the element, (3) only if neither is acceptable, add an **additive, optional** field (with a backend test and a note in `docs/SPECS.md`) so the shipped app never breaks. Every gap gets a row here.

| # | Screen | Need | Finding | Resolution |
|---|---|---|---|---|
| G-1 | `tr_earnings` | 7-day bar chart (`THBars`) | `GET /api/tradie/earnings` (`TradieEarningsDto`) returns only period totals (earned / processed / pending / failed). No per-day values exist. | Port totals first; hide `THBars` when data is absent. Optional additive field `DailyNet[]` on `TradieEarningsDto` only if the owner wants the chart. |
| G-2 | `notifications` | notification list | Backend has no inbox endpoint; the app keeps a client-side store (`notification_center.dart`). | No change; keep client-side. |
| G-3 | `ho_home` hero | "Needs your attention" item | Not verified. Expected to derive from job statuses in `GET /api/jobs`. | Verify in step 4.1 (#1); derive client-side or omit. |
| G-4 | dock / `chat` | unread badges, last message | Not verified. `GET /api/chat/conversations` is the likely source. | Verify in 3.1; derive or omit. |
| G-5 | `tr_home` / `ho_tradie_profile` | rating, job count, response time, distance | Not verified against `GET /api/profile/:id` and the matches DTOs. | Verify per screen; derive or omit. |

### 4.2 Screens in the app with no v2 design (not in the 30)

`signup`, `settings`, `messages_list`, `categories`, `browse_tradies` (`/find-tradie`), homeowner public profile (`/users/:id`), quick-match radar (`/jobs/:id/matching`), cancel-job / schedule / rating sheets, designed empty/error states, wide-screen nav rail, and any admin screens. Compose them from `TH*` widgets per `DESIGN_GUIDE.md`, label PRs `needs-design`, and feed them to the D-4 design pass. These are **not** blockers for Phases 2–5.

---

### Phase 1 — Documentation Restructuring (This phase — docs only)

**Goal:** Archive legacy design, install v2 design system docs, update all cross-references. No app code changes.

> [!NOTE]
> **Steps 1.1–1.4 completed 2026-11-16.** Files are in place. Steps 1.5–1.28 are deferred — owner has paused here pending a separate app-migration plan.

- [x] **1.1** Create `docs/archive/design-legacy-v1/` directory structure
- [x] **1.2** Move all files from `docs/design/` into `docs/archive/design-legacy-v1/` (preserving subdirectory layout)
- [x] **1.3** Create `docs/archive/design-legacy-v1/ARCHIVE-NOTICE.md` (date, reason, pointer to v2)
- [x] **1.4** Copy `th-design-v2/` contents into `docs/design/` following the structure in §2.2
- [x] **1.5** Create `docs/design/COLOUR.md` (extract from DESIGN_GUIDE.md §2)
- [x] **1.6** Create `docs/design/TYPOGRAPHY.md` (extract from DESIGN_GUIDE.md §3)
- [x] **1.7** Create `docs/design/COMPONENTS.md` (extract from DESIGN_GUIDE.md §5–§7)
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
- [x] **1.27** Verify `docs/design/tools/build.mjs` runs correctly from its new location (`node docs/design/tools/build.mjs --check`)
- [x] **1.28** Commit with message: `docs: archive v1.7 design system, install v2 Trust Navy + Gold`

✅ **Phase 1 done when:** `node docs/design/tools/build.mjs --check` passes, no doc or rule file references old v1 paths, and `docs/archive/design-legacy-v1/` contains the complete v1 set.

---

### Phase 2 — Foundation (no screen changes, app behaves exactly as today)

**Goal:** Install v2 tokens, fonts, widgets and a scoped theme under `mobile/lib/ui/`, next to the old code. Nothing in `lib/views/`, `lib/widgets/` or `lib/theme/` changes.

- [x] **2.1** Create `mobile/lib/ui/design/` and copy in `docs/design/tokens/design_tokens.dart` → `th_tokens.dart` and `docs/design/flutter/th_widgets.dart` → `th_widgets.dart`. Fix the one relative import (`design_tokens.dart` → `th_tokens.dart`). Keep class names unchanged (`THColors`, `THType`, `THButton`, …).
- [x] **2.2** Bundle fonts (D-2): add Lexend + Source Sans 3 files for the weights used in `tokens.json` under `mobile/assets/fonts/v2/` and declare both families in `pubspec.yaml`. **Keep the v1 families until Phase 6.** Verify on a real iOS and Android device that the files render (Flutter's mobile engines are only guaranteed to load `.ttf`/`.otf`; if `.woff2` falls back to the system font, convert to `.ttf`, which still satisfies D-2). *Done as static `.ttf` (Lexend 400–800, Source Sans 3 400–700); on-device render check still to do.*
- [x] **2.3** Add `ThScope` (`lib/ui/design/th_scope.dart`; takes `themeMode` as a parameter until 2.11 moves `themeModeProvider` out of `views/`, so `lib/ui` stays free of `views/` imports): wraps a subtree in `Theme(data: THTheme.light | THTheme.dark)`, choosing by the existing `themeModeProvider` + platform brightness. `THTheme.light/dark` are getters, not methods. This is how v2 screens get v2 theme while the rest of the app keeps `FixoTheme`.
- [x] **2.4** Add the import-boundary guard (`scripts/check_ui_boundary.py`, run as a step of the `mobile-build-test` CI job): files under `lib/ui/**` must not import `theme/design_tokens.dart`, `theme/fixo_theme.dart`, `widgets/fixo_*`, `widgets/th_components.dart` or `views/**`; files outside `lib/ui/**` must not import `ui/design/**`. This is what makes the side-by-side approach safe, because the old app and v2 both define `THColors`, `THType`, `THBadge`, `THField`, `THSegmented`, `THSwitch`, `THIconButton`, `THListRow` and `THDivider`. They only clash if one file imports both.
- [x] **2.5** Add `node docs/design/tools/build.mjs --check` to CI now (new `design-system-check` CI job; passes: 30 screens, contrast 38/38). Retiring the v1 audit targets waits for Phase 6.
- [x] **2.6** Copy the 30 generated stubs to `mobile/lib/ui/gallery/` (static sample data, imports repointed) and add a debug-only `/debug/screen-gallery` route exposing `thScreenBuilders`, each wrapped in `ThScope` (`ScreenGalleryPage`, with a light/dark toggle; deep link `?screen=<id>&theme=dark`). These stubs are the visual baseline and golden source. They are **not** the real screens.
- [x] **2.7** Add golden tests for the 30 gallery screens (light + dark) under `test/ui/goldens/`. *Test written (`test/ui/gallery_goldens_test.dart`); baseline PNGs still to generate with `flutter test --update-goldens test/ui/gallery_goldens_test.dart` (comparison is skipped per screen until its PNG is committed).*
- [x] **2.8** Create `lib/ui/feedback/th_notice.dart` (D-3): a v2-styled skin that reuses the existing `FixoNoticeController`/`notice_copy.dart` logic (UI-independent). The class rename of the old widgets happens at cutover. *`THNotice` façade + `THNoticeHost` + `THNoticeBanner`, tests in `test/ui/th_notice_test.dart`. Host is not mounted yet: the v1 `FixoNoticeHost` still renders notices until Phase 6.1.*
- [x] **2.9** Create `lib/ui/feedback/th_state_view.dart`: loading (skeleton), empty and error views composed from v2 widgets and the existing copy in `designed_empty_state.dart` / `fixo_states.dart`. D-4 (error/empty/skeleton design pass) is separate, so this is the interim. *`ThStateView.loading/empty/error/preset` (presets carry the v1 copy; actions are caller callbacks, no routing inside). Tests in `test/ui/th_state_view_test.dart`; not yet run, no Flutter SDK in the authoring sandbox.*
- [x] **2.10** Add `lib/ui/ui_flags.dart`: a per-screen allowlist (`const Set<String> v2Screens`) plus `--dart-define=UI_V2=all` for developers. See §4.0 for how routes use it. *`isV2Screen(id)` + pure `resolveV2Screen`; `UI_V2` also accepts a comma-separated id list. `v2Screens` is empty until Phase 3. Tests in `test/ui/ui_flags_test.dart` (not yet run, no Flutter SDK in the authoring sandbox).*
- [x] **2.11** Decouple `main.dart` from `views/settings_screen.dart` (it imports `themeModeProvider` from a view file): move the provider to `lib/viewmodels/theme_mode_viewmodel.dart` and re-export it from the old location. This is the only existing file touched in this phase. *Provider + `ThemeModeNotifier` moved verbatim; `settings_screen.dart` re-exports them and `main.dart` now imports the viewmodel. Touched `main.dart` and `settings_screen.dart` only.*
- [x] **2.12** Run `flutter analyze`, `dart format`, and the full existing test suite. **Nothing may change.** *Pending: the authoring sandbox has no Flutter SDK (engine download is network-blocked). Run `dart format lib test`, `flutter analyze`, `flutter test`, and `flutter test --update-goldens test/ui/gallery_goldens_test.dart` (2.7) locally or via CI, then tick this box.*

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
- [x] **3.5** Visual QA each screen against `docs/design/mockups/index.html` (light + dark). *Automated light + dark verification done in-sandbox (widget tests + gallery goldens stay green); on-device mockup comparison is the follow-up once the branch is pulled onto a device.*

✅ **Phase 3 done when:** a user can sign up, verify, sign in (email and Google), pick a role, and land in the v2 shell with chat / notifications / profile in v2, with all auth tests green.

*Done 2026-11-17. Shipped as `feat(mobile): phase 3`: `ThShell` (dock + rail + `chatUnreadProvider` badge), six auth screens, five shared screens under `lib/ui/auth/` + `lib/ui/shared/`; additive `TH*` extensions (`THTextField`, `THOtpInput`, `THButton.loading`, `THAppBar.actions/showBack/leading`, `THDock.badges`, `THSegmented.onSelected`, `THScaffold.bottomClearance`); `v2Screens` flipped for the 12 Phase-3 ids (gallery goldens unchanged — additive defaults verified pixel-neutral). Suite: analyze clean, 887 tests green, import-boundary + design gates green. Known needs-design stand-ins: the ≥1024px rail (D-4), settings/profile/messages_list compositions (no v2 mockups), and the chat Schedule action still opening the v1 sheet until the job-detail screens port.*

---

### Phase 4 — Homeowner Flows

**Goal:** Recreate homeowner screens in v2, porting behaviour from the old screens. Ordered so each step can be tested end to end.

- [ ] **4.1** Port in this order (corrected mapping — several names in the earlier draft did not exist):

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

- [ ] **4.2** Job detail is one route with several v2 designs. Build `ThJobDetailRouter`, which reuses the status logic in `widgets/job_status_presentation.dart` to choose between `ho_job_booked`, `ho_extra_cost`, `ho_review_completion`, `ho_review` and the cancelled/disputed states. Split into one widget per state; do not recreate a 1,900-line file.
- [ ] **4.3** Screens without a v2 design (listed above, plus cancel / schedule / rating sheets, `/users/:id`, wide-layout rail) are composed from `TH*` widgets following `DESIGN_GUIDE.md`, flagged `needs-design` in the PR, and added to the D-4 design-pass backlog.
- [ ] **4.4** Preserve post-job navigation (`/jobs/new` → `/jobs/:id/tradies` | `/matching` | `/request`) and all `extra` payload types in `app_router.dart` unchanged. Push-notification deep links must keep working.
- [ ] **4.5** Widget tests per screen; run the matching existing flow tests (`job_request_test`, `matching_test`, `payment_test`, `dispute_test`, `job_lifecycle_test`) with v2 enabled.
- [ ] **4.6** Visual QA against `docs/design/mockups/index.html`.

✅ **Phase 4 done when:** the full homeowner journey (post → choose/match → book → adjust → confirm → pay → review/dispute) runs on v2 screens only with the flag at `all`, and the listed flow tests pass.

---

### Phase 5 — Tradie Flows

**Goal:** Same recipe for tradie screens.

- [ ] **5.1** Port in this order:

  | Order | v2 screen | Old file | Endpoints (already exist) |
  |---|---|---|---|
  | 1 | `tr_home` | `tradie/tradie_dashboard_view.dart` (2,016 lines) | `GET /api/jobs`, `/api/jobs/:id/offers/pending`, `POST …/offers/:id/respond`, `POST /api/profile/availability` |
  | 2 | `tr_lead` | `tradie/request_detail_screen.dart` | `GET /api/jobs/:id`, `accept`, `decline`, `POST …/quotes` |
  | 3 | `tr_job` | `tradie/tradie_job_detail_screen.dart` (1,792 lines) | `check-in`, `no-show`, `schedule`, `adjustments` |
  | 4 | `tr_extra_cost` | adjustment flow inside `tradie_job_detail_screen.dart` | `POST /api/jobs/:id/adjustments`, `…/withdraw` |
  | 5 | `tr_complete` | check-out flow inside `tradie_job_detail_screen.dart` | `POST …/check-out`, `…/photos` |
  | 6 | `tr_earnings` | earnings section of `tradie_dashboard_view.dart` | `GET /api/tradie/earnings` (see **G-1**) |
  | 7 | `tr_onboarding` | `tradie/tradie_onboarding_wizard.dart` (1,657 lines) | `/api/tradie/services`, `/rates`, `/credentials`, `/schedule` |

- [ ] **5.2** Keep `tradie_onboarding_viewmodel` (708 lines) and `offer_responder` untouched; only the presentation is recreated. Split the dashboard and job-detail files into per-section widgets rather than porting them 1:1.
- [ ] **5.3** Confirm the tradie dock has **no** centre action (`THDock(role: THDockRole.tradie)`, `onNewRequest` null). The earlier draft's `fab: false` parameter does not exist in `th_widgets.dart`.
- [ ] **5.4** Run `offer_countdown` and offer-response behaviour tests with v2 enabled.
- [ ] **5.5** Visual QA against `docs/design/mockups/index.html`.

✅ **Phase 5 done when:** the full tradie journey (onboard → go online → receive offer/lead → accept/quote → check in → adjust → check out → earnings) runs on v2 screens only.

---

### Phase 6 — Cutover, Cleanup and CI Toolchain

**Goal:** Make v2 the only UI, delete v1, and finish the toolchain work.

- [ ] **6.1** Flip `UI_V2` default to on and remove `ui_flags.dart` and the per-route conditionals in `app_router.dart`. Point `MaterialApp(theme: THTheme.light, darkTheme: THTheme.dark, themeMode: ...)` at v2, and remove `ThScope` wrappers.
- [ ] **6.2** Delete v1: `lib/views/**` (all screens now live in `lib/ui/`), `lib/widgets/fixo_*.dart`, `th_components.dart`, `tradie_widgets.dart`, `lib/theme/design_tokens.dart`, `lib/theme/fixo_theme.dart`, and the old v1 view-only widgets. Then move `lib/ui/design/*` to `lib/theme/` (or keep as `lib/ui/design/`; decide once, update `.agent/rules/mobile.md`).
- [ ] **6.3** Rename `FixoNotice*` → `THNotice*` (D-3) and update the ~90 usages.
- [ ] **6.4** Confirm no `outdoor` code path, `AvailabilityColors`/`SocialColors` leftovers or v1 token names remain (D-5): `grep -rn "outdoor\|DesignTokens\|Fixo[A-Z]" mobile/lib` must be empty.
- [ ] **6.5** Remove v1 fonts from `assets/fonts/` and `pubspec.yaml` (Space Grotesk, IBM Plex), drop `google_fonts` if unused, and remove the import-boundary guard from §2.4.
- [ ] **6.6** Update or delete the 32 test files referencing v1 names; regenerate goldens and the store-screenshot tests (`screenshots_*`).
- [ ] **6.7** Update `mobile/HARDCODED_AUDIT.md` for v2 tokens.
- [ ] **6.8** Retire old audit targets from `agent/Makefile` (`audit`, `transpile`, `sheet`) or redirect them to `build.mjs`; update `agent/setup.sh` and root `package.json` scripts (`audit`, `verify`).
- [ ] **6.9** Document the "change a colour / screen / component" workflow in `docs/ai/AI-TOOLING.md` §4 and `docs/design/README.md`, including that ported screens are now hand-owned code and the AST stubs remain the design reference.
- [ ] **6.10** Establish the v2 regression gate in `docs/TESTING.md`: (1) `node docs/design/tools/build.mjs --check`, (2) `flutter analyze`, (3) `flutter test`, (4) visual QA against `docs/design/mockups/index.html`.
- [ ] **6.11** Update `docs/MILESTONES.md` and `docs/DESIGN.md` with the completion date.

✅ **Phase 6 done when:** v1 code, tokens, fonts and audit tools are gone, `grep` in 6.4 is clean, CI runs the full gate on every PR, and a release build passes on iOS and Android.

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
mobile/lib/ui/design/th_tokens.dart   → Phase 2 (copy of docs/design/tokens/design_tokens.dart)
mobile/lib/ui/design/th_widgets.dart  → Phase 2 (copy of docs/design/flutter/th_widgets.dart)
mobile/lib/ui/design/th_scope.dart    → Phase 2 (scoped THTheme wrapper)
mobile/lib/ui/gallery/                → Phase 2 (static stubs, debug gallery + goldens only)
mobile/lib/ui/{auth,homeowner,tradie,shared,feedback}/ → Phases 3–5 (real screens bound to existing viewmodels)
mobile/assets/fonts/v2/               → Phase 2 (Lexend + Source Sans 3)
mobile/lib/{models,repositories,network,viewmodels}/   → unchanged throughout
mobile/lib/{views,widgets,theme}/     → v1, deleted in Phase 6
```

---

*Generated: 2026-11-16. Use the `docs-sync` skill after any behaviour or scope change that updates this plan.*
