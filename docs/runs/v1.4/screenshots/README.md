# Screenshots — v1.4 (post-fix verification)

36 full-screen captures, iPhone 17 Pro (homeowner/shared) + iPhone 17 Pro Max
(tradie), light theme, taken **after the v1.4 open-issues fix pass** — same run
as `../test-run-2026-10-26.md`. Driven by
`mobile/integration_test/screenshots_test.dart` (prints `__SHOT__` markers;
host captures `xcrun simctl io <udid> screenshot` per marker).

Fixture jobs created by `scripts/mk-shot-fixtures.sh`:
- 119 `Requested` (matching screen), 120 `AwaitingPayment` (match result /
  payment / status / dispute), 121 `Booked`, 122 `InProgress`
- 123–126 same states for the tradie pass, 127 pending offer → tradie-verified

## shared/ (captured on the homeowner pass)

| File | Route / screen |
|---|---|
| `01_splash.png` | `/` splash |
| `02_onboarding.png` | `/onboarding` |
| `03_login.png` | `/auth` |
| `04_signup.png` | `/signup` |
| `05_verify_email.png` | `/verify-email` OTP |
| `06_role_select.png` | `/role-select` |

## homeowner/ (iPhone 17 Pro)

| File | Route / screen |
|---|---|
| `00_post_login.png` | landing after login |
| `01_dashboard.png` | `/home` |
| `02_jobs_list.png` | `/jobs` |
| `03_messages.png` | `/messages` |
| `04_profile.png` | `/profile` |
| `05_settings.png` | `/settings` |
| `06_post_job.png` | `/jobs/new` (top) |
| `06b_post_job_bottom.png` | `/jobs/new` (scrolled) |
| `07_matching.png` | `/jobs/119/matching` — **"Contacting Tradie 1…" live state** |
| `08_match_result.png` | `/jobs/120/match` — Tradie Verified card |
| `09_job_detail_inprogress.png` | `/jobs/122/detail` |
| `10_job_detail_booked.png` | `/jobs/121/detail` |
| `11_chat.png` | `/chat/122` |
| `12_payment.png` | `/jobs/120/payment` |
| `13_payment_status.png` | `/jobs/120/payment/status` |
| `14_dispute.png` | `/jobs/120/dispute` |
| `15_tradie_profile.png` | `/tradie/:id` public profile |
| `16_homeowner_profile.png` | `/users/:id` public profile |

## tradie/ (iPhone 17 Pro Max)

| File | Route / screen |
|---|---|
| `00_post_login.png` | landing after login |
| `01_dashboard.png` | `/tradie` — **"Incoming Requests (2 New)" pending-offer surface** |
| `02_jobs_list.png` | `/jobs` |
| `03_request_detail.png` | `/tradie/requests/127` — **pending offer w/ countdown + Accept Job** (was "Job not found" in v1.3) |
| `04_active_job_inprogress.png` | `/tradie/jobs/126` (Check Out) |
| `05_active_job_booked.png` | `/tradie/jobs/125` (Check In) |
| `06_chat.png` | `/chat/126` |
| `07_messages.png` | `/messages` |
| `08_profile.png` | `/profile` |
| `09_settings.png` | `/settings` |
| `10_onboarding_wizard.png` | `/tradie/onboarding` step 1 |
| `11_public_profile.png` | `/tradie/:id` public profile |
| `12_homeowner_profile.png` | `/users/:id` public profile |

## Re-run

```bash
# 1. fixtures — prints the SHOT_*_JOB ids to pass below
./scripts/mk-shot-fixtures.sh [--with-offer]   # --with-offer for tradie pass

# 2. homeowner + shared
flutter test integration_test/screenshots_test.dart --device-id <udid> \
  --dart-define FIXO_PERSONA=homeowner --dart-define FIXO_DISABLE_PUSH=true \
  --dart-define SHOT_MATCH_JOB=<id> --dart-define SHOT_PAYMENT_JOB=<id> \
  --dart-define SHOT_BOOKED_JOB=<id> --dart-define SHOT_INPROGRESS_JOB=<id>

# 3. tradie
flutter test integration_test/screenshots_test.dart --device-id <udid> \
  --dart-define FIXO_PERSONA=tradie --dart-define FIXO_DISABLE_PUSH=true \
  --dart-define SHOT_OFFER_JOB=<id> --dart-define SHOT_BOOKED_JOB=<id> \
  --dart-define SHOT_INPROGRESS_JOB=<id>
```

Pipe stdout through a watcher that fires `xcrun simctl io <udid> screenshot
<out>/<name>.png` on each `__SHOT__ <name>` line (see git history /
`docs/RUNNING-TESTS.md` for the full pipeline).
