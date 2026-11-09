# E2E Run — 2026-11-09

Full-stack end-to-end run against the live dev stack
(`docker compose`: api :5000, PostGIS, Redis, Azurite).

- Mobile: iOS 26.2 simulators — iPhone 17 Pro `9AA76BF8…` (homeowner),
  iPhone 17 Pro Max `76384481…` (tradie). Real API, no mocks.
- Admin: Playwright + Chromium against the React app, staff login.
- API: `scripts/e2e-credentials.py` contract suite.

## Results

| Suite | Result |
|---|---|
| `auth_test.dart` | 6/6 |
| `job_request_test.dart` (incl. live LINZ resolve) | 4/4 |
| `matching_test.dart` homeowner | 2/2 |
| `matching_test.dart` tradie | 2/2 |
| `payment_test.dart` | 2/2 |
| `job_lifecycle_test.dart` tradie | 2/2 |
| `job_lifecycle_test.dart` homeowner | 2/2 |
| `cancellation_test.dart` homeowner | 2/2 |
| `cancellation_test.dart` tradie | 1/1 |
| `dispute_test.dart` | 3/3 |
| `live_chat_test.dart` (two-client SignalR push + bg/reconnect) | 1/1 |
| `e2e-credentials.py` | 22/22 |
| Admin Playwright (auth, credentials, payments, refunds, disputes, users, payouts) | **28/28** |

Screenshots: `screenshots/` — 89 PNGs
(light+dark × {6 shared + 18 homeowner + 13 tradie}, 2 live-chat, 13 admin).

## Real bugs found & fixed this run

1. **`disputeStatus: 'None'` treated as an open dispute** — mobile.
   `hasOpenDispute`/`hasActiveDispute` in `homeowner_job_detail_screen.dart`
   (and the banner check in `tradie_job_detail_screen.dart`) used
   `!= null && != 'Resolved'`, so the backend default `"None"` disabled
   **Confirm Completion** on every AwaitingConfirmation job and rendered a
   bogus "active dispute" banner. Fixed to `== 'Open' || == 'UnderReview'`.
   Verified by P5-05.

2. **App-opened disputes never reached the admin queue** — backend.
   `DisputeService.OpenDisputeAsync` set `job.DisputeStatus` but not
   `IsFlagged`, and the admin queue (`GetDisputesAsync`) lists flagged jobs
   only — so staff could never see or resolve disputes opened from the app.
   Now flags the job on open (verified: `POST /api/disputes` → queue row).
   Backfilled the 6 stale open disputes in the dev DB.

3. **`scripts/seed-test-accounts.sh` aborted mid-run** — `set -u` +
   `($85.50)` in a `pass` string expanded `$8` → unbound variable; staff and
   unverified accounts never seeded. Escaped.

4. **Playwright row-checks were instant** (`isVisible()`/`count()` don't
   auto-wait) — every data-dependent test silently skipped. Converted to
   `waitFor`/`expect` waits; the masked staleness then surfaced and was
   fixed (popup-menu cancel affordance, verify/reject modal labels,
   "Mark as processed", row→link navigation, empty-state `<tr>` counted as
   a data row, strict-mode multi-match on `$` cells).

5. **Mobile test drift** — `auth_test` expected `first/last_name_field`
   (signup is now a single `full_name_field`); `matching_test` expected the
   "Awaiting payment" label (V15-06 renders "Payment due");
   `cancellation_test` expected a `Cancel job` tooltip (now an overflow
   `more_vert` popup, 'Cancel job'/'Cancel Job' item).

## Findings — recorded, not fixed

- **Dispute-resolve contract mismatch (P7 blocker).** Admin web sends
  `{outcome: FullRefund|PartialRefund|NoRefund|None}`; the API requires
  `{Action: Resolved|Escalated|CancelJob}` — every resolve attempt 400s.
  The `DisputeOutcome` enum already matches the web model, so the endpoint
  is the stale side; refund semantics (Full/Partial amounts, cancel on
  FullRefund) need a product decision before wiring. P7-10 test asserts
  the confirmation-modal gate only.
- **Admin resolve also doesn't update the `Disputes` entity** — it mutates
  `job.DisputeStatus`/`Status` only; `Disputes.Status` would stay Open.
- **Persona tests must run serially.** Parallel `flutter test` runs race on
  `parkCompetingTradies`/`restoreCompetingTradies` — a teardown can un-park
  the demo tradie mid-flight and steal offers meant for the test tradie.
- **P3-03 comment is stale** — "pending offer has no tradie UI surface"
  now passes; `screenshots/light/tradie/03_request_detail.png` shows the
  offer + countdown working.
- **Port squatting on this machine** — 5173 (OrbStack `b2c-laravel`) and
  3000 (Next.js) were taken, and the API CORS allowlist is 3000/5173 only.
  Worked around without touching other projects: `web/vite.e2e.config.ts`
  serves on :8090 with an `/api` proxy (same-origin ⇒ no CORS), driven by
  `web/playwright.local.config.ts`.
- **Playwright browser cache was incomplete** — package expected
  `chromium-1148` (cache had `-1254`); the downloader's extractor stalled
  mid-write. Extracted manually + `channel: 'chromium'` in the local config
  skips the missing `headless_shell`. `npx playwright install` should be
  re-run cleanly on a good connection.
- **`run-live-chat.sh` writes into `docs/runs/v1.5/`** (hardcoded OUT) —
  refreshed `tradie/19_chat_live_push` + `20_chat_reconnect` there; copies
  also under `screenshots/light/tradie/` here.
- **Seed-side data consumed by this run** — payment queue was drained by
  P4-07 twice; a fresh `PaymentReview` job (247, FIXO-247, $171.00) was
  re-seeded for the admin queue. Credential/payout/refund queues still have
  rows.

## Artifacts

- Mobile captures: `screenshots/{light,dark}/{shared,homeowner,tradie}/`
- Live chat: `screenshots/light/tradie/19_chat_live_push.png`,
  `20_chat_reconnect.png`
- Admin captures: `screenshots/admin/01_login…13_user_detail.png`
  (zero console errors across all pages)
- Admin shot driver: `web/e2e/admin-shots.mjs` (reusable; needs the
  `:8090` e2e server running)
- Local-only configs: `web/vite.e2e.config.ts`,
  `web/playwright.local.config.ts`

## Reproduce

```sh
docker compose up -d && bash scripts/seed-test-accounts.sh
python3 scripts/e2e-credentials.py --keep
# mobile (serial per persona)
cd mobile && flutter test integration_test/<file>.dart \
  --device-id <udid> --dart-define FIXO_PERSONA=<persona> \
  --dart-define FIXO_DISABLE_PUSH=true
# admin
cd web && npx playwright test --config playwright.local.config.ts
```
