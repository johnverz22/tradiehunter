# v1.4 — TradieHunter Rebrand + UI/UX/Functional Audit

**Version:** 1.4  
**Date:** 2026-10-26  
**Status:** Implemented — all v1.4 code changes complete and verified against codebase  
**Authored by:** Evidence-based audit (source code + screenshots + test run)

---

## Purpose

This specification covers two coordinated workstreams:

1. **Rebrand** — Rename the application from *TradieFixo* to *TradieHunter* across all user-facing surfaces, platform metadata, and backend configuration, without altering the visual design, brand colors, typography, or component architecture.

2. **Functional and UI/UX audit** — Document confirmed defects, suspected defects, test-infrastructure failures, and UI inconsistencies discovered by cross-referencing the application source code, screenshots, and a recorded test run.

No source code changes are made by this document. All findings are assigned unique IDs and mapped to actionable implementation tasks in `implementation-tasks.md`.

---

## Scope

| Area | In scope | Out of scope |
|---|---|---|
| Flutter mobile app | ✅ Homeowner role, Tradie role | Admin web dashboard |
| Backend (.NET 10 API) | ✅ Brand config, auth, job/booking APIs | Payment gateway, ML matching |
| React web admin | ✅ Render-probe / date-locale test only | Full admin UI audit |
| Platform metadata | ✅ iOS Info.plist, Android manifest, web manifest | Firebase config, App Store / Play Store listings |
| Test infrastructure | ✅ Integration helpers, finder accuracy | Unit test coverage expansion |

---

## Audit Sources

### Source Code
- **Mobile:** `mobile/` — Flutter/Dart, Riverpod, go_router
- **Backend:** `backend/` — .NET 10 ASP.NET Core Web API, EF Core, SignalR, Hangfire
- **Web admin:** `web/` — React (admin only)
- **Key files inspected:** `pubspec.yaml`, `main.dart`, `app_router.dart`, `fixo_buttons.dart`, `fixo_cards.dart`, `splash_screen.dart`, `login_screen.dart`, `signup_screen.dart`, `role_select_screen.dart`, `settings_screen.dart`, `homeowner_dashboard_view.dart`, `tradie_dashboard_view.dart`, `job_navigation.dart`, `locale_viewmodel.dart`, `marketplace.dart`, `ConfigController.cs`, `BrandOptions.cs`, `appsettings.json`, `SmtpEmailSender.cs`, `ProfileService.cs`, `PaymentOptions.cs`, `public_profile_screen.dart`, `e2e_helpers.dart`, integration test files

### Screenshots
- **Location:** `docs/runs/v1.3/screenshots/`
- **Total:** 38 screenshots across three subdirectories

| Subdirectory | Count | Description |
|---|---|---|
| `shared/` | 6 | Splash, onboarding, login, signup, verify-email, role-select |
| `homeowner/` | 17 | Dashboard through public tradie profile |
| `tradie/` | 15 | Post-login through homeowner-profile view |

**Coverage note:** 14 screenshots were individually inspected during the audit; the remaining 24 were reviewed for naming patterns and cross-referenced with code. Findings for unviewed individual screenshots are derived from source code inspection and noted as such. Individual screen notes may be incomplete for unviewed captures.

Screenshots individually inspected:
- `shared/01_splash.png`, `02_onboarding.png`, `03_login.png`, `04_signup.png`, `06_role_select.png`
- `homeowner/01_dashboard.png`, `04_profile.png`, `05_settings.png`, `09_job_detail_inprogress.png`, `16_homeowner_profile.png`
- `tradie/00_post_login.png`, `03_request_detail.png`, `04_active_job_inprogress.png`, `09_settings.png`

### Test Run
- **File:** `docs/test-run-2026-10-26.md`
- **Contents:** Unit test suite results (29/29 passed), integration test suite results across multiple suites (homeowner booking flow, tradie job management, cross-persona, admin API), render-probe results

---

## Application Architecture Summary

| Attribute | Value |
|---|---|
| Mobile framework | Flutter (Dart) |
| State management | Riverpod |
| Navigation | go_router (`AppRouter`) |
| Backend | .NET 10 ASP.NET Core Web API |
| Database | PostgreSQL + PostGIS (EF Core, NetTopologySuite) |
| Real-time | SignalR |
| Scheduled jobs | Hangfire |
| Push notifications | Firebase Cloud Messaging (FCM) |
| Local storage | `flutter_secure_storage` |
| Dart package name | `fixo` (do NOT rename) |
| Android applicationId | `nz.co.fixo.fixo` (do NOT rename) |
| iOS bundle identifier | `fixo` (do NOT rename) |
| Backend namespace | `FixoApi` (do NOT rename) |

**Brand tokens (centralized — do NOT change values):**
- Primary hue: 209 (blue)
- CTA amber: `#E38B29`
- Theme class: `FixoTheme` + `DesignTokens`

**Key shared widgets:**
`FixoWordmark`, `FixoAppBar`, `FixoGradientAppBar`, `FixoPrimaryButton`, `FixoGhostButton`, `StatusBadge`, `JobStepper`, `FixoCard`, `FixoLoading`, `FixoEmptyState`, `FixoErrorState`

---

## Limitations and Caveats

1. **Unviewed screenshots (24 of 38):** Findings for these screens are code-derived. If a screenshot reveals an additional defect not present in code, it would constitute a new finding not documented here.
2. **`docs/RUNNING-TESTS.md` is stale:** Step 3 references a Flutter 3.x command syntax that fails under the current Flutter version (test run issue 3). Do not use as setup reference without verification.
3. **`flutter_secure_storage` SwiftPM deprecation:** Generates warnings in the iOS build log (test run issue 7). Not a functional defect but should be monitored for future breakage.
4. **FCM permission noise:** Firebase permission dialogs during integration tests are logged but do not cause test failures in the current run.
5. **Admin web dashboard:** Out of scope for this mobile audit. The render-probe date-locale issue (`TH-FUNC-008`) is the only web-admin finding included.
6. **Payment, dispute, and ML matching screens** referenced in some screenshots were not audited for functional correctness (out of MVP scope per `docs/MVP-SPEC.md`).
7. **No runtime testing was performed** during this audit. All defect classifications are derived from static code analysis and test run evidence.

---

## Deliverables in This Version

| File | Purpose |
|---|---|
| `README.md` (this file) | Scope, sources, architecture summary, limitations |
| `audit-findings.md` | All consolidated issues with IDs, evidence, severity, and root-cause assessment |
| `implementation-tasks.md` | Actionable tasks mapped to findings, with acceptance criteria and regression notes |
| `acceptance-criteria.md` | Application-wide verification requirements for sign-off |

---

## Issue Summary by Category

| Category | ID Range | Count | Priority breakdown |
|---|---|---|---|
| Functional defects | TH-FUNC-001 – TH-FUNC-009 | 9 | 2× P1, 3× P2, 4× P3 |
| Test infrastructure | TH-TEST-001 – TH-TEST-002 | 2 | 1× P1, 1× P2 |
| Branding | TH-BRAND-001 – TH-BRAND-004 | 4 | 3× P1, 1× P2 |
| UI/UX | TH-UI-001 – TH-UI-003 | 3 | 0× P1, 2× P2, 1× P3 |
| **Total** | | **18** | **6× P1, 6× P2, 5× P3** |

---

## Relationship to Prior Versions

| Version | Focus |
|---|---|
| v1.1 | Initial MVP feature set |
| v1.2 | Booking and payment flow |
| v1.3 | Tradie onboarding wizard |
| **v1.4** | **Rebrand to TradieHunter + audit findings** |

This specification does not supersede v1.1–v1.3 features. It adds findings and tasks orthogonal to those workstreams, except where a v1.4 task modifies a file also touched by a prior spec (noted in individual tasks).
