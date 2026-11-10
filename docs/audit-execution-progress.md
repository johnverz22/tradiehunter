# Audit Execution Progress — 2026-11-09

Tracking execution of the audit at `~/Downloads/TradieHunter UI Audit and Screen Prompts.md`.
Nothing is committed. Resume with the uncommitted diff plus this file.

## Verification snapshot (this session)

- `flutter analyze`: clean (6 pre-existing infos, 0 warnings/errors).
- `flutter test` mobile: **0 failures (607/607 passing)** across the entire test suite
  (baseline measured on detached worktree: 69 failures; all 69 fixed, 0 introduced).
- `npx tsc -b` (web): clean. `npx oxlint`: 2 pre-existing warnings.
- All 19 `scripts/web/render-probe.py` fixtures pass.
- Not run: Playwright e2e, backend, any device/simulator re-capture — **nothing is
  visually verified** yet.

## Done

### Harness & shared formatting
- `run-shots.sh` passes `SHOT_THEME`; `screenshots_test.dart` forces the theme via
  SharedPreferences and fails if the rendered brightness doesn't match (fixes
  dark-captures-in-light-folder, audit issue #1).
- `mobile/lib/utils/money.dart`: `formatMoney`/`formatMoneyOrDash`/`formatRate`
  (Decimal-safe, en-NZ grouping). Adopted in payment, match result, homeowner/tradie
  job detail, tradie dashboard, request detail, jobs list, job summary, payment status.
- `web/src/utils/format.ts`: `formatDate`, `formatDateTime`, `formatMoney`,
  `formatAge`, `formatHours` (en-NZ, Pacific/Auckland). Payouts + dashboard use it.

### Bugs (audit execution order step 2)
- **M12** match result: headline moved into normal flow — card can no longer cover it;
  `_avatarOverlap` reserves space; hidden `0.0 km` distance; `View profile` action.
  Widget tests assert headline-bottom ≤ card-top at 1.0/1.3/2.0 scale.
- **M14** payment: bank details absent → primary CTA "Refresh payment details",
  upload withheld with hint; present → "Upload bank receipt" + per-row copy +
  `Copy all`; "$X NZD" strings removed; "View payment status" now only in app bar.
- **A2** dashboard: "Pending Verifications" card now uses `useCredentialQueue`
  (same query as the Credentials page) — it previously showed `todaySignups`.
  Missing timing metrics show "—" + tooltip. Lower table renamed "Unverified tradies",
  links to `/credentials`. NZ dates in tables.
- **A8** payouts: Process disabled + tooltip when `!hasBankDetails`; "Show missing
  bank details only" filter toggle; `createdAgo` now delegates to `formatAge`.

### Auth (M1–M5) — done, including fixing its own failing tests
- Onboarding: onSurface headline (was link-blue), 48dp Skip, larger dot indicator,
  "Step N of 3" semantics, "Get started".
- Login: proper title + subtitle, `floatingLabelBehavior: always` on both fields,
  48dp Forgot password/Create account targets.
- Signup: live `PasswordRules` checklist wired (widget existed unused in
  `auth_controls.dart`), Terms/Privacy tappable **only when locale config supplies
  the URL**, role toggle overflow at 2× text fixed (real bug), tabs got button
  semantics.
- OTP: "Use a different email" button under the address; muted resend styling.
- Role select: removed untrue "switch later in settings" claim (no such feature);
  helper under disabled Continue.
- `auth_ui_test.dart`: stale expectations updated to current design (single
  `full_name_field`), `localeConfigProvider` stubbed in harness — **all 17 tests pass
  (was 8 failing)**.

### Core loops & detail screens (M6, M8, M9, M13) — done, all suites passing
- **M6** Homeowner dashboard & booked jobs (`modern_job_card.dart`, `homeowner_job_summary.dart`, `job_progress_dots.dart`):
  - Removed border on attention card wash per token design.
  - Replaced ad-hoc TextButton with `FixoTonalButton` for "Open chat", disabled when `matchedTradieId == null`.
  - `JobProgressDots` renders `'Step $step of 4'` for non-terminal statuses.
  - `dashboard_redesign_test.dart` and `homeowner_jobs_ui_test.dart` — **all tests passing**.
- **M8 & M9** Messages & Chat (`chat_widgets.dart`, `chat_screen.dart`):
  - `_UnreadBadge` renders unread count (or '99+').
  - Own-message previews prefixed with `'You: '`.
  - ChatComposer send button wrapped in `Tooltip('Send message')` with Key.
  - Chat date separator and status pill wrapped in Flexible + FittedBox to prevent 2.0x scale overflows at 320px width.
  - `chat_screens_test.dart` — **all 24 tests passing**.
- **M13** Homeowner job detail (`homeowner_job_detail_screen.dart`, `status_strip.dart`):
  - Wrapped `Total` label in `Expanded` and price in `Flexible(child: FittedBox(...))` using `DesignTokens.fontSizeAmount`.
  - Action button unified to `'Open Chat'`.
  - Added `FixoPillChip` for `'Verified'` when `isVerified == true`.
  - Responsive `View profile` wraps under name on large text scale (≥ 1.3x).
  - Added 'Job Description' section header matching tradie detail card structure.
  - `StatusStrip` upgraded: renders status pill row with `StatusBadge` + ref code, plus `CompactProgressBar` with chevron and expandable step list; wrapped in `Flexible` + `FittedBox` for 320px/2.0x scale.
  - `homeowner_job_detail_test.dart` (25/25) and `theme_test.dart` (65/65) — **all tests passing**.
- **Accessibility & Responsive**:
  - `offer_countdown.dart` wraps labels in `Flexible` + `FittedBox` preventing 320px/2.0x overflows.
  - `accessibility_audit_test.dart` (66/66) and `responsive_layout_test.dart` (4/4) — **all tests passing**.

### Other mobile
- **M7** tradie job filters → single horizontally scrollable row (plain
  `SingleChildScrollView`+`Row` — a lazy `ListView` breaks tap-by-text).
- **M17** "Request for a job" → "Request this tradie".
- **M18** settings Region shows `regionLabel()` = "New Zealand (NZD)" (new helper in
  `locale_viewmodel.dart`, unit-tested); nav clearance under version caption.

### Other admin
- **A1** login: show/hide password (`Show`/`Hide` + `aria-controls`, avoids
  `getByLabel` collision), `autoFocus` email, Caps Lock hint, aria-describedby.
  New probe fixture `scripts/web/fixtures/auth/login.json`.
- **A4** payments queue: real empty state with icon + payout/refund links;
  zero-count/zero-sum chips hidden.
- **A7** user detail: `No reviews yet` instead of `0.0` when reviewCount = 0.

## Remaining

- **Mobile:** M10 (post-a-job restructure — big), M11 (matching copy/cancel), M15 (payment timeline),
  M16 (dispute form), M19 (dashboard stat tiles), M20 (request detail), M21 (tradie job detail),
  M22 (onboarding wizard).
- **Admin:** A3 (credentials review UX), A5 (refund queue), A6 (dispute detail),
  A7 remainder (kebab menus, danger zone), A9 (audit log names/dates/diffs),
  A10 (settings selects + sticky save).
- **Harness:** realistic seed data, non-happy-path captures, full-page admin shots.

## Pre-existing failures: 100% resolved (0 remain of 69)

All test suites clean:
`homeowner_job_detail_test`, `theme_test`, `chat_screens_test`, `dashboard_redesign_test`,
`job_status_presentation_test`, `accessibility_audit`, `offer_response_test`,
`responsive_layout`, `homeowner_jobs_ui_test`.

## Stale audit findings (don't re-do)

- M6 "literal Homeowner greeting" — name comes from fixture account data, not code.
- M9 quick-reply chips — already scrollable with ShaderMask fade.
- Duplicate role selection — real flow never shows both; only Google sign-in reaches
  `/role-select`. The harness visits both screens, hence the screenshot.

## Decisions / flags needing product sign-off (unchanged)

- M3 Role Select removal: NOT applied (no real-flow duplicate; kept route for Google).
- Forgot password: no backend endpoint; stub retained.
- A6 dispute outcome labels (Action vs outcome contract mismatch): not wired.
- Delete account / Privacy in settings (M18): not added, flagged only.
- Global heading colour (brand navy/blue300) is a theme design decision; I overrode
  it on auth screens only.
- `docs/MVP-SPEC.md` does not exist — versioned specs: `docs/MVP-SPEC-v1.3.md` is latest.

## How to continue

1. Pick next item from Remaining (M10, M11, M15, M16, or Tradie screens M19–M21).
2. Mobile: tokens only (`design_tokens.dart`), both themes, run
   `flutter analyze` + relevant `flutter test` files; keep failure count = 0.
3. Web: shared `utils/format.ts`, `npx tsc -b`, extend/run render-probe fixtures
   (`scripts/web/fixtures/<feature>/*.json`; add `"page"` key so they self-register).
4. Re-capture: `./scripts/run-shots.sh <persona> <light|dark> <udid> [defs]` after
   `./scripts/mk-shot-fixtures.sh --with-offer` against `docker compose up` stack.
