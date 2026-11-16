# TradieHunter — Mobile Design System v2 Migration Plan

> **Scope:** Mobile rebrand only. Web (React admin) is excluded from all phases.
> **This document is docs-only.** No application code, components, styles, or source files are modified in Phase 1.
> **Source:** `th-design-v2/` (Trust Navy + Gold, v2.0.0)
> **Replaces:** `docs/design/` (Space Grotesk + IBM Plex + Amber, v1.7)

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

### Phase 1 — Documentation Restructuring (This phase — docs only)

**Goal:** Archive legacy design, install v2 design system docs, update all cross-references. No app code changes.

> [!NOTE]
> **Steps 1.1–1.4 completed 2026-11-16.** Files are in place. Steps 1.5–1.28 are deferred — owner has paused here pending a separate app-migration plan.

- [x] **1.1** Create `docs/archive/design-legacy-v1/` directory structure
- [x] **1.2** Move all files from `docs/design/` into `docs/archive/design-legacy-v1/` (preserving subdirectory layout)
- [x] **1.3** Create `docs/archive/design-legacy-v1/ARCHIVE-NOTICE.md` (date, reason, pointer to v2)
- [x] **1.4** Copy `th-design-v2/` contents into `docs/design/` following the structure in §2.2
- [ ] **1.5** Create `docs/design/COLOUR.md` (extract from DESIGN_GUIDE.md §2)
- [ ] **1.6** Create `docs/design/TYPOGRAPHY.md` (extract from DESIGN_GUIDE.md §3)
- [ ] **1.7** Create `docs/design/COMPONENTS.md` (extract from DESIGN_GUIDE.md §5–§7)
- [ ] **1.8** Add `docs/design/assets/ASSETS-NOTICE.md` documenting asset strategy decision (see §2.3) — *D-1 resolved: skip; brand assets stay in archive*
- [ ] **1.9** Rewrite `docs/DESIGN.md` per §3.1
- [ ] **1.10** Update `docs/ARCHITECTURE.md` per §3.1
- [ ] **1.11** Update `docs/SPECS.md` per §3.1
- [ ] **1.12** Update `docs/MVP.md` per §3.1
- [ ] **1.13** Update `docs/PRD.md` per §3.1
- [ ] **1.14** Update `docs/MILESTONES.md` per §3.1
- [ ] **1.15** Update `docs/TESTING.md` per §3.1
- [ ] **1.16** Update `docs/QA.md` per §3.1
- [ ] **1.17** Update `docs/README.md` per §3.1
- [ ] **1.18** Update `docs/ai/AI-TOOLING.md` per §3.1
- [ ] **1.19** Update `docs/ai/AGENTS-docs-block.md` per §3.1
- [ ] **1.20** Update `.agent/rules/mobile.md` per §3.2
- [ ] **1.21** Update `AGENTS.md` (root) per §3.2
- [ ] **1.22** Update `GEMINI.md` per §3.2
- [ ] **1.23** Update `CLAUDE.md` per §3.2 (canonical — regenerate cursorrules/windsurfrules from it)
- [ ] **1.24** Regenerate `.cursorrules` and `.windsurfrules` from updated `CLAUDE.md`
- [ ] **1.25** Update `.agent/rules/ai-tools.md` per §3.2
- [ ] **1.26** Check `.agent/rules/backend.md` and `.agent/rules/frontend.md` for stray mobile design refs
- [ ] **1.27** Verify `docs/design/tools/build.mjs` runs correctly from its new location (`node docs/design/tools/build.mjs --check`)
- [ ] **1.28** Commit with message: `docs: archive v1.7 design system, install v2 Trust Navy + Gold`

✅ **Phase 1 done when:** `node docs/design/tools/build.mjs --check` passes, no doc or rule file references old v1 paths, and `docs/archive/design-legacy-v1/` contains the complete v1 set.

---

### Phase 2 — Design Token Implementation

**Goal:** Replace `mobile/lib/theme/design_tokens.dart` with the v2 token file. Update `fixo_theme.dart` to wire `THTheme`. No screen-level widget changes yet.

- [ ] **2.1** Back up `mobile/lib/theme/design_tokens.dart` (git branch)
- [ ] **2.2** Copy `docs/design/tokens/design_tokens.dart` to `mobile/lib/theme/design_tokens.dart`
- [ ] **2.3** Add `Lexend` and `Source Sans 3` to `pubspec.yaml` (via `google_fonts` or bundled assets)
- [ ] **2.4** Update `mobile/lib/theme/fixo_theme.dart` to call `THTheme.light` and `THTheme.dark`
- [ ] **2.5** Wire `MaterialApp(theme: THTheme.light, darkTheme: THTheme.dark, themeMode: ThemeMode.system)`
- [ ] **2.6** Copy `docs/design/flutter/th_widgets.dart` to `mobile/lib/theme/th_widgets.dart` (or `mobile/lib/widgets/`)
- [ ] **2.7** Run `flutter analyze` and resolve any token name conflicts (e.g., `FixoDurations` vs `THDurations.fast/base/slow`)
- [ ] **2.8** Run `dart format .`
- [ ] **2.9** Run existing widget and unit tests — fix any failures caused by token renames
- [ ] **2.10** Update `mobile/HARDCODED_AUDIT.md` to reflect v2 token names
- [ ] **2.11** Add a debug gallery route (`/debug/screen-gallery`) exposing `thScreenBuilders` for all 30 screens

> [!WARNING]
> `THColors` **adds** fields in v2 (`surfaceAlt`, tints, hero gradient colours, `glass`, `heroGlow`) and **removes** none of the existing fields. The old `outdoor` variant from v1 is not present in v2. Any code that references `DesignTokens.paperDark` etc. will need mapping to the new `THColors` extension accessed via `context.th.<name>`.

✅ **Phase 2 done when:** App compiles with `flutter analyze` clean, both light and dark themes render via `THTheme`, and the debug screen gallery shows all 30 v2 screens.

---

### Phase 3 — Component Library Migration

**Goal:** Replace `Fixo*` widgets with their `TH*` equivalents across all screen files. Run the v2 audit gate.

- [ ] **3.1** Audit all `mobile/lib/views/` files for `Fixo*` widget usage — produce a replacement checklist
- [ ] **3.2** Migrate each widget family:

  | Old widget | New widget | Notes |
  |---|---|---|
  | `FixoPrimaryButton` (gold CTA) | `THButton(kind: ButtonKind.accent)` | One per screen only |
  | `FixoPrimaryButton` (navy) | `THButton(kind: ButtonKind.primary)` | Secondary filled actions |
  | `FixoGhostButton` | `THButton(kind: ButtonKind.ghost)` | |
  | `FixoAppBar` | `THAppBar` | |
  | `FixoCard` | `THCard` | |
  | `THHeroBand` | `THHero` | Hero card with gradient |
  | `THStatusStrip` / `StatusBadge` | `THBadge` or `THProgress` | |
  | `StickyActionBar` | `THSticky` | |
  | `FixoNotice.*` | stays — confirm compatibility | |
  | `CustomBottomNavBar` + FAB | `THDock` | HO gets FAB with `THHuntGlyph`; tradie does not |

- [ ] **3.3** Replace all `Space.*` token refs where values have changed (new additions: `s8` 40, `s9` 48)
- [ ] **3.4** Replace all `Radii.*` token refs (control is now 16 vs 14 in v1; hero 28 is new)
- [ ] **3.5** Replace all `Sizes.*` token refs (button now 54 vs 56; `dock` 68, `fab` 56, `stickyClearance` 96, `dockClearance` 120 are new)
- [ ] **3.6** Replace typography: all `DesignTokens.fontSize*` with `THType.*`, all `FW.*` remain compatible
- [ ] **3.7** Remove all `outdoor` theme code paths (not in v2)
- [ ] **3.8** Run `node docs/design/tools/build.mjs --check` (the v2 CI gate)
- [ ] **3.9** Run `python3 docs/design/tools/audit_full.py` on any remaining HTML artefacts (if applicable)
- [ ] **3.10** Run full test suite (`flutter test`, `dart analyze`)
- [ ] **3.11** Visual QA: compare each screen against `docs/design/mockups/index.html` (light + dark)
- [ ] **3.12** Update `mobile/HARDCODED_AUDIT.md` with v2 audit results

✅ **Phase 3 done when:** `flutter analyze` clean, `build.mjs --check` passes, no `Fixo*` widget usages remain except `FixoNotice`, visual QA passes for all 30 screens in both themes.

---

### Phase 4 — Screen Migration (Homeowner Flows)

**Goal:** Port all homeowner screens to use generated v2 screen ASTs as layout reference, binding real data.

- [ ] **4.1** Map v2 screen IDs to current view files:

  | v2 screen | Current file | v1 frame |
  |---|---|---|
  | `splash` | `SplashScreen` | S01 |
  | `onboarding` | `OnboardingScreen` | S02–S04 |
  | `sign_in` | `SignInScreen` | S05 |
  | `verify_otp` | `VerifyOtpScreen` | S07 |
  | `role_select` | `RoleSelectScreen` | S08 |
  | `ho_home` | `HomeownerHomeScreen` | H07 |
  | `ho_post_project` | `PostJobScreen` | H09 |
  | `ho_post_quick` | `PostJobQuickScreen` | H09 quick |
  | `ho_quotes` | `QuotesScreen` | H11 |
  | `ho_choose_tradie` | `ChooseTradieScreen` | H19 |
  | `ho_tradie_profile` | `TradieProfileScreen` | H17 |
  | `ho_request_sent` | `RequestSentScreen` | — |
  | `ho_job_booked` | `JobDetailScreen` | H12 |
  | `ho_extra_cost` | `ExtraCostScreen` | — |
  | `ho_review_completion` | `ReviewCompletionScreen` | — |
  | `ho_payment` | `PaymentScreen` | H14 |
  | `ho_payment_status` | `PaymentStatusScreen` | H15 |
  | `ho_review` | `ReviewScreen` | — |
  | `ho_dispute` | `DisputeScreen` | H16 |
  | `ho_jobs` | `JobsScreen` | — |

- [ ] **4.2** For each screen: use `thScreenBuilders['<id>']!(context)` as the layout baseline; bind real ViewModel data; replace sample copy; keep widget tree structure
- [ ] **4.3** Run widget tests for each migrated screen
- [ ] **4.4** Visual QA against `docs/design/mockups/index.html`

✅ **Phase 4 done when:** All 20 homeowner screens migrated, widget tests pass.

---

### Phase 5 — Screen Migration (Tradie Flows)

**Goal:** Port all tradie screens to v2 layout, bind real data.

- [ ] **5.1** Map v2 tradie screen IDs to current view files:

  | v2 screen | Current file |
  |---|---|
  | `tr_home` | `TradieHomeScreen` |
  | `tr_lead` | `LeadDetailScreen` |
  | `tr_job` | `TradieJobScreen` |
  | `tr_extra_cost` | `TradieExtraCostScreen` |
  | `tr_complete` | `TradieCompleteScreen` |
  | `tr_earnings` | `TradieEarningsScreen` |
  | `tr_onboarding` | `TradieOnboardingScreen` |

- [ ] **5.2** Same bind-and-test process as Phase 4
- [ ] **5.3** Map shared screens:

  | v2 screen | Shared by |
  |---|---|
  | `chat` | HO + Tradie |
  | `notifications` | HO + Tradie |
  | `profile` | HO + Tradie |

- [ ] **5.4** Confirm tradie dock has **no FAB** (`THDock` with `fab: false`)
- [ ] **5.5** Visual QA against `docs/design/mockups/index.html`

✅ **Phase 5 done when:** All 10 tradie + shared screens migrated, widget tests pass.

---

### Phase 6 — AST Workflow Integration + CI Gate

**Goal:** Wire the v2 build pipeline into the project's CI/toolchain so it stays in sync.

- [ ] **6.1** Confirm `node docs/design/tools/build.mjs` is runnable from repo root (update `package.json` or `agent/Makefile` if needed)
- [ ] **6.2** Add `build.mjs --check` to CI pipeline (runs contrast gate + stale-output check)
- [ ] **6.3** Retire old audit targets from `agent/Makefile` (`audit`, `transpile`, `sheet`) or redirect them
- [ ] **6.4** Update `agent/setup.sh` for v2 dependencies (Node 18+ remains; Python audit deps may no longer be needed)
- [ ] **6.5** Document the new "change a colour/screen/component" workflow in `docs/ai/AI-TOOLING.md` §4 and in the `docs/design/README.md`
- [ ] **6.6** Establish the v2 regression gate checklist in `docs/TESTING.md`:
  1. `node docs/design/tools/build.mjs --check` — contrast, stale outputs, unknown nodes
  2. `flutter analyze` — static analysis
  3. `flutter test` — unit + widget tests
  4. Visual QA against `docs/design/mockups/index.html`

✅ **Phase 6 done when:** CI runs `build.mjs --check` on every PR, the v1 audit tools are retired, and the new workflow is documented.

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
docs/design/                         → v2 design system (installed 2026-11-16) ✅
docs/archive/design-legacy-v1/       → v1.7 legacy design system (archived 2026-11-16) ✅
mobile/lib/theme/design_tokens.dart  → Phase 2 target (replace with docs/design/tokens/design_tokens.dart)
mobile/lib/theme/th_widgets.dart     → Phase 2 target (copy from docs/design/flutter/th_widgets.dart)
mobile/lib/views/design_v2/          → Phase 2 target for generated screen stubs (debug only)
```

---

*Generated: 2026-11-16. Use the `docs-sync` skill after any behaviour or scope change that updates this plan.*
