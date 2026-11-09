# Open Issues — fix pass handoff

Extracted from `docs/test-run-2026-10-26.md` for external implementation.
Each entry: severity, location, symptom, root cause, and suggested fix
direction. Issue numbers match the test-run report.

---

## A. Product defects (blocking user-visible behaviour)

### A1. Pending offers are invisible to tradies (issue #9) — **critical**

The sequential matching flow is functionally dead for tradies: an offer is
created and expires without the tradie ever seeing it in-app.

Three compounding gaps:

1. **List query** — `JobRepository.GetForUserAsync`
   (`backend/Services/JobRepository.cs:32`) returns only jobs where
   `MatchedTradieId == userId`. A `Pending` offer's job never appears in the
   tradie's list, so `_IncomingRequestsSection` on the dashboard is
   permanently empty.
2. **Push/in-app event** — the tradie dashboard subscribes to
   `onNewJobMatch`, which `MatchingService` never emits. Sequential dispatch
   emits `OfferLifecycleEvent` to the tradie's user group; only
   `request_detail_screen` listens for it.
3. **Detail endpoint** — `GET /api/jobs/{id}` refuses a tradie holding only a
   pending offer (job's `MatchedTradieId` is still null), so
   `/tradie/requests/:requestId` renders "Job not found" even from a
   deep link or notification tap.

Confirmed by: `tradie/03_request_detail.png` ("Job not found" while a live
offer existed), and failing tests `matching_test.dart` tradie P3-03/P3-04,
which create a real pending offer and assert a UI surface — currently red by
design, with `reason:` strings naming this defect.

Suggested direction:
- Add a pending-offers surface: either include `Pending`-offer jobs in
  `GetForUserAsync` for tradies, or a dedicated `GET /api/jobs/offers/pending`
  list endpoint feeding the dashboard's incoming-requests section.
- Subscribe the dashboard to `onOfferLifecycle` (or emit `NewJobMatch` on
  offer creation).
- Widen `GET /api/jobs/{id}` to authorize a tradie with a `Pending` offer on
  that job so request detail can render offer context (expiry countdown is
  already available via `GET /jobs/{id}/offers/pending`).

### A2. Dispute evidence upload hits a non-existent endpoint (issue #18)

`mobile/lib/repositories/jobs_repository.dart:435` posts to
`/api/disputes/{id}/evidence`, but `DisputesController` only exposes
`POST /api/disputes/{id}/evidence/text` (line 49) and
`/api/disputes/{id}/evidence/files` (line 59). Result: 404, logged as
"[Jobs] uploadDisputeEvidence failed" — and `submitDispute` still reports
success, so evidence **silently drops** while the user sees
"Dispute submitted successfully".

Fix: split the repo call into the two real endpoints (files → `evidence/files`
multipart, text notes → `evidence/text`), and surface the failure — don't
claim success when the evidence leg fails.

### A3. `context.pop()` crash on dispute-submit via deep link (issue #19)

`mobile/lib/views/jobs/dispute_screen.dart:118` calls `context.pop()` after a
successful submit. Reached via `go('/jobs/:id/dispute')` (deep link,
notification, `openHomeownerJob`-style routing) there is nothing to pop →
`GoError: There is nothing to pop`. Works only when pushed.

Fix: replace `context.pop()` with `context.go('/jobs/$jobId/detail')` (or
`canPop` guard then fallback route).

### A4. MatchingScreen never re-reads offer state on entry (issue #20)

`mobile/lib/views/jobs/matching_screen.dart` starts at phase `starting`
('Finding tradies near you…') and only advances on SignalR
`OfferLifecycleEvent`s. If the offer was dispatched before the screen
subscribes (notification → open job → matching screen, app restart
mid-matching), it sits on 'Finding tradies' until the next lifecycle event —
potentially the expiry. The screen already calls `triggerMatch` on entry
(which 409s harmlessly when matching already ran); it should also fetch the
job's current offer state (`GET /jobs/{id}/matches` or the pending-offer
endpoint) and seed `MatchingProgressState` from it.

### A5. Homeowner `Requested`-job tap goes to chat, not matching (issue #10)

`openHomeownerJob` (`mobile/lib/views/widgets/job_navigation.dart`) routes
every status except AwaitingPayment/PaymentReview to `/chat/:id`. A homeowner
who leaves the post-job flow mid-matching has **no in-app path back** to
`/jobs/:id/matching` — the matching screen exists only as a post-job
continuation. Decide the intended navigation (Requested + in-flight offer →
matching screen, or a job-detail screen that surfaces offer progress) and
wire it.

### A6. `ProfileService` runtime auto-seed vs `SeedNZServices` migration race (issue #1)

`backend/…/ProfileService.cs:302` auto-seeds service rows
("Plumber"/"Electrician"/…) at runtime; the `SeedNZServices` EF migration
inserts the canonical set with the same primary keys. Any DB that already
hit the runtime seeder fails the migration (`duplicate key PK_Services`).
Fix: make the runtime seeder match the canonical migration set (same keys /
upsert semantics), or drop it entirely now that the migration owns the data.

---

## B. Product defects (non-blocking)

### B1. Offer-expiry cancellation is aggressive for QA (issue #16)

A `Requested` job whose offer window lapses moves to the next candidate;
with none left it becomes `Cancelled`/`no_tradie_found`. Correct product
behaviour, but fixtures and manual QA sessions self-destruct if nobody
answers within `Matching:OfferWindowMinutes` (~10 min). Consider a dev-only
longer window or a visible "matching expired" state rather than hard-cancel
— product call.

### B2. render-probe batches fixture fails 3 assertions (issue #2)

`PayoutBatches`/`format.ts` uses `toLocaleDateString(undefined, …)` → renders
`Sep 21, 2026` under Node SSR instead of the NZ `21 Sept` format expected by
the fixture (money is `en-NZ`-pinned, dates aren't — violates the
config-driven-locale rule). Plus a stale `50%` progress expectation with no
matching fixture row. Pin the date formatter locale like the money formatter.

### B3. `ListTile` inside `DecoratedBox` — hidden ink splash (debug assert)

Homeowner public-profile screen wraps a `ListTile` in a `DecoratedBox` with a
background → framework assertion "ListTile background color or ink splashes
may be invisible" (fires during tests). Wrap in `Material` so the splash has
an ink surface.

---

## C. Test-harness / tooling leftovers

### C1. `payment_status_screen` has no test Key (issue #21)

Only copy-based finders exist ('Payment status' / 'Under review'). Add
`Key('payment_status_screen')` to the Scaffold for a stable assertion.

### C2. `seed-test-accounts.sh` still incomplete (issues #4, #15)

- `staff@fixo.test`: invited but the script only reads `RegistrationToken`
  from the DB — if empty it skips, leaving the account unusable. Should
  complete set-password via the MailHog/DB token deterministically.
- `tradie-verified@fixo.test`: needs `EmailVerified=true`, a `TradieProfiles`
  row, a `TradieRates` row (service 1 @ 85.50), **and an approved `License`
  `TradieCredentials` row** — service 1 is licence-gated
  (`RequiresLicence=true`), so without the credential the tradie is excluded
  from matching even when verified+available.
- The demo `tradie@fixo.nz` profile outranks the test tradie in matching
  (distance 0 + existing ratings). Tests work around it via
  `FixtureHelper.parkCompetingTradies()`; a seed-level fix would rank or
  isolate the test tradie deterministically.

### C3. Minor warnings

- `flutter_secure_storage` lacks SwiftPM support (build warning every run).
- ~10 info-level analyzer issues in `mobile/`.
- FCM: `apns-token-not-set` log on simulator post-login registration —
  expected on sims; consider gating with `FIXO_DISABLE_PUSH` in
  `AuthNotifier` too for cleaner test logs.

---

## Already fixed this round (for reference — no action needed)

Backend:
- `Program.cs` — dev admin cookie `__Host-`/`Secure` rejected over http →
  every admin mutation 401-looped. Dev cookie now non-prefixed +
  `SameAsRequest`.
- `AdminController.CurrentUserId` — JWT `sub`-only lookup 500'd every
  cookie-authed admin POST. `NameIdentifier` fallback added.
- 6 pending EF migrations applied; stale auto-seeded service rows remapped.
- `tradie-verified` `EmailVerified=false` → 403 login, fixed in DB.

Mobile:
- `tradie_widgets.dart:96` const-eval error (computed `brand500` in const
  constructor) — blocked all iOS builds.
- `main.dart` — `await requestPermission()` blocked `runApp` behind the iOS
  dialog; now `unawaited` + `FIXO_DISABLE_PUSH` dart-define gate.
  `Firebase.initializeApp`/`GoogleSignIn.initialize`/`getInitialMessage`
  bounded so per-test `main()` re-runs can't hang.
- Test harness — 71× `pumpAndSettle` → bounded `pumpFor`; `gotoLogin()`
  converges to `/auth` from any boot state (incl. leftover non-shell routes);
  all suites self-seed via `FixtureHelper`.

Web tests:
- `auth.setup.ts` `__dirname` under ESM; `credentials.spec.ts` modal button
  labels + disabled-state assertion.
