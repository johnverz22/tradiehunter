# v1.6 Implementation Tasks
**Last updated:** 2026-11-02  
**Spec:** `docs/specs/v1.6/flutter-implementation-plan.md`  
**Baseline:** `flutter analyze` 9 infos / 0 warnings / 0 errors · 511 tests pass

Tick boxes as you go. Each task references the target file and what to do.

---

## Phase A — Foundation

- [x] **A1** `mobile/lib/widgets/fixo_cards.dart` — Fix `StatusBadge` waiting pill dark mode: `brand300.withValues(alpha: 0.28)` fill + `Colors.white` text. ✅ Done.

- [x] **A2** `mobile/lib/views/homeowner/homeowner_job_detail_screen.dart` — Replace `import '../widgets/job_progress.dart'` with `import '../widgets/job_timeline.dart'` (file already uses `JobTimeline` directly; import is just stale). ✅ Already correct — file imports `job_timeline.dart`, no stale `job_progress` import present.

- [x] **A3** `mobile/lib/views/chat/chat_screen.dart` — Replace `import '../widgets/job_progress.dart'` with `import '../widgets/compact_progress_bar.dart'` (file already uses `CompactProgressBar(inline: true)`; import is just stale). ✅ Already correct — file imports `compact_progress_bar.dart`, no stale import.

- [x] **A4** `mobile/lib/views/homeowner/homeowner_job_detail_screen.dart` — Audit Navigate / Message / Call actions: confirm they use `FixoTonalButton` (not `TextButton`/`OutlinedButton`). The `_MatchedTradieCard` already does — verify nothing was missed in the detail cards. ✅ Confirmed — Navigate, Chat, Call in `_MatchedTradieCard` all use `FixoTonalButton`. Remaining `TextButton` instances are dialog actions (OK / Reassign) — correct per Material spec.

- [x] **A5** `mobile/lib/views/tradie/tradie_job_detail_screen.dart` — Audit Navigate / Message / Call: replace any `TextButton`/`OutlinedButton` with `FixoTonalButton` + correct icon (`Icons.navigation_outlined`, `Icons.chat_bubble_outline`, `Icons.phone_outlined`). ✅ Confirmed — `_NavigateButton` wraps `FixoTonalButton`; Message and Call in the homeowner contact card use `FixoTonalButton`. Remaining `TextButton` at lines 300/304 are dialog actions; `TextButton.icon` at line 605 is the "Need help?" overflow helper row — both are correct.

- [x] **A6** `mobile/lib/views/tradie/request_detail_screen.dart` — Wrap any bare `Container`/`Card` widgets in `FixoCard`. Check each visual section. ✅ Done — address card, `_ScheduleCard`, `_OfferCheckError`, `_OfferGone` all converted to `FixoCard`. Unused `isDark` params removed from `_ScheduleCard` and `_OfferGone`.

- [x] **A7** Run `flutter analyze` from `mobile/` — must be ≤ 9 infos, 0 warnings, 0 errors. ✅ 5 infos, 0 warnings, 0 errors.

---

## Phase B — Tradie flow

- [x] **B1** `mobile/lib/views/tradie/tradie_dashboard_view.dart` — Lead card reorder (V16-08): price `24sp/700` at top, countdown bar below, 1/3–2/3 Decline/Accept button split. ✅ Already implemented — `_LeadCard` has price 24/700 at top, `_LeadCountdownBar` below price, metadata row, job title+photo, then Decline(1/3)/Accept(2/3) at 56px.

- [x] **B2** `mobile/lib/views/tradie/request_detail_screen.dart` — Content reorder (V16-08): price section first, countdown timer, sticky `StickyActionBar` with Decline/Accept. ✅ Already implemented — body order: title+category chip → price block → countdown → address card → schedule → description → photos → sticky 1/3 Decline | 2/3 Accept bar.

---

## Phase C — Homeowner flow

- [ ] **C1** `mobile/lib/views/homeowner/homeowner_dashboard_view.dart` — Hero band (V16-09): navy gradient, `bpdots` texture, small-caps time label, 28sp Display first name, frosted location pill, bell + amber dot. Attention cards: `LinearGradient` brand 18% → 6% → transparent, `4×6px` dot indicators + "Step X of 4" text (no `CompactProgressBar` on cards). Empty state: illustration + "Find a tradie you can trust" + 3-stat row + full-width CTA. Implementation audit follow-up (2026-11-02): hero, time-based greeting, CSS-equivalent painted dots, rings, light/dark illustration empty state, three feature tiles, attention wash/dots/headline hierarchy, and grouped compact Booked/InProgress rows are implemented. SVG sources and 3× PNG runtime exports are bundled under the already-registered `assets/illustrations/`; regenerate with `node scripts/render-dashboard-assets.cjs` (existing web Playwright + installed Chrome). Preserves canonical detail navigation, separate chat action, Decimal prices, localized schedule and SignalR regrouping. No asset blocker remains. **Still open for data/product sign-off:** profile API has no homeowner location projection and no notification-unread provider exists; location is omitted without real data and bell has no fabricated unread dot. Empty tiles use Local tradies / Direct chat / Hourly pricing rather than unsupported speed/verification guarantees or fixed-job-price copy. `dashboard_redesign_test.dart` and `homeowner_jobs_ui_test.dart` cover both themes, narrow/large-text layouts, assets, routes and state updates; these do not establish device/frame sign-off.

- [x] **C2** `mobile/lib/views/homeowner/homeowner_job_detail_screen.dart` — Verify 3-card layout (Status / People / Details) matches V16-11 spec. Confirm cards are `FixoCard`-wrapped and sticky action bar is used. ✅ Done — 3-card layout confirmed: Status card (`FixoCard`) integrates `JobTimeline` (which encapsulates `StatusBadge`, `CompactProgressBar`, step progression and collapsible timeline) + contextual banner; People card (`_MatchedTradieCard` in `FixoCard`); Details card (`FixoCard`). Sticky action bar with state-based logic in place.

- [x] **C3** `mobile/lib/views/tradie/tradie_job_detail_screen.dart` — Implement 3-card layout (V16-11): Status card, People card (homeowner identity), Details card ("You earn" label on price). ✅ Done — 3-card layout confirmed: Status card (`FixoCard`) integrates `JobTimeline` (encapsulating `StatusBadge`, `CompactProgressBar`, step progression and collapsible timeline) + contextual banners; People card (`_ContactCard`); Details card has "You earn" net amount. All `FixoCard`-wrapped.

- [x] **C4** `mobile/lib/views/jobs/match_result_screen.dart` — Tradie hero first (V16-10): avatar + name + trade + rating at top, price card below, remove duplicate heading. ✅ Done — moved "Match Found!" into app bar title; body leads with tradie `TradieCard`, followed by price `FixoCard`; no duplicate heading.

---

## Phase D — Secondary screens

- [x] **D1** `mobile/lib/views/chat/chat_screen.dart` — Status area (V16-12): confirm single `CompactProgressBar(inline: true)` strip exists below the `FixoAppBar`; remove any legacy 4-row stepper if still present. ✅ Done — confirmed single `CompactProgressBar(status: status, inline: true)` strip in header area; legacy stepper absent.

- [x] **D2** `mobile/lib/views/chat/messages_list_screen.dart` — Row height (V16-12): `ConversationTile` height 72px, avatar 40px, unread indicator dot. ✅ Done — `ConversationTile` enforced minHeight 72px, avatar 40px, unread badge dot present; dark mode action chips updated for AA contrast compliance.

- [x] **D3** `mobile/lib/views/jobs/post_job_screen.dart` — Improvements (V16-13): character counters on title/description fields, live estimate card ("Estimated: $X–$Y"), post button disabled with helper text until required fields filled. ✅ Done — `_hideCounterUntilThreshold` suppresses counter until 80% threshold; live estimate card updates in real-time; submit button disabled with helper text indicating first missing field.

- [x] **D4** All widget/screen files — Dark mode border audit (V16-17): grep `BorderSide(color:` for hardcoded light-grey values (`Colors.white12`, `Color(0xFFE0E0E0)`, etc.) and replace with `THColors` `line` token access. Verify ≥ 4.5:1 contrast for all pill text. ✅ Done — audited and verified across codebase: all borders mapped to centralized tokens (`borderCard`, `borderControl`, `borderWidthFor`); `surfaceStatus` dark contrast verified ≥ 4.5:1 (10.45:1).

---

## Phase E — iPad layout

- [x] **E1** `mobile/lib/views/main_layout.dart` + jobs/messages screens — `LayoutBuilder` master-detail panel split at 744pt. `ResponsiveContainer` max-width 640px wrapper for forms/lists (V16-18). ✅ Done — `ResponsiveContainer` added to `fixo_states.dart` and implemented on `post_job_screen.dart`; `MasterDetailLayout` splits at 744pt (`kBreakpointMasterDetail`) across jobs and messages; left navigation rail active at ≥1024pt (`kBreakpointLeftRail`).

---

## Final gate

- [x] **Z1** `flutter analyze` — ≤ 9 infos, 0 warnings, 0 errors. ✅ 5 infos, 0 warnings, 0 errors.
- [x] **Z2** `flutter test` — all 511+ tests pass (new tests for changed widgets bring count up). ✅ 594/594 tests passed (0 failures) after the 2026-11-02 implementation-audit fixes. Ten new dashboard regression checks cover assets, gradient decoration, typography token, narrow/large text, light/dark themes and chat/detail gates. All four reported sub-12sp overrides and the 11sp caption compatibility token are now at least 12sp; source scan finds no remaining literal font sizes below 12 in `mobile/lib/`. `flutter analyze` remains at 5 existing infos, 0 warnings, 0 errors.
- [ ] **Z3** Screenshot smoke check: ≥ 10 screens in both light + dark themes match hi-fi frames in `docs/design/v1.6/html/`. 📸 Captured 2026-11-02 — 37 screens × 2 themes (6 shared + 18 homeowner + 13 tradie each) in `docs/runs/v1.6/screenshots/{light,dark}/` via `scripts/run-shots.sh` on iPhone 17 Pro sim against live API (fixture jobs 201–206). Visual frame-match review pending sign-off. These captures predate the dashboard/typography audit fixes above; recapture affected screens in both themes before review. Widget tests and isolated hero previews do not satisfy this gate. C1 location/unread data gaps and truthful empty-state copy deviations also need product disposition before declaring exact frame compliance.
