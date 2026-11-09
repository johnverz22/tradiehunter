# App Screenshots — 2026-10-26

Full-screen captures from iPhone 17 Pro simulator (iOS 26.2), light theme,
driven by `mobile/integration_test/screenshots_test.dart` (prints `__SHOT__`
markers; host captures via `xcrun simctl io screenshot`).

Re-run:

```bash
cd mobile
# homeowner pass (also captures shared/): SHOT_MATCH_JOB = a Requested job id
flutter test integration_test/screenshots_test.dart --device-id <udid> \
  --dart-define FIXO_PERSONA=homeowner --dart-define SHOT_MATCH_JOB=67 \
  --dart-define FIXO_DISABLE_PUSH=true | while read -r l; do echo "$l";
  [[ "$l" == *__SHOT__* ]] && xcrun simctl io <udid> screenshot \
  "../docs/runs/v1.3/screenshots/$(echo "$l" | sed -E 's/.*__SHOT__ //').png"; done

# tradie pass: SHOT_OFFER_JOB = job with pending offer to tradie-verified
flutter test integration_test/screenshots_test.dart --device-id <udid> \
  --dart-define FIXO_PERSONA=tradie --dart-define SHOT_OFFER_JOB=68 \
  --dart-define FIXO_DISABLE_PUSH=true | <same watcher>
```

`FIXO_DISABLE_PUSH=true` suppresses the system notification-permission
dialog so it does not overlay captures.

## shared/ — pre-auth
| File | Route | Screen |
|---|---|---|
| 01_splash | `/` | Splash (boot) |
| 02_onboarding | `/onboarding` | Onboarding slide 1 |
| 03_login | `/auth` | Login |
| 04_signup | `/signup` | Signup + role pick |
| 05_verify_email | `/verify-email` | OTP entry |
| 06_role_select | `/role-select` | Google-signup role pick |

## homeowner/ — homeowner-a@fixo.test
| File | Route | Screen |
|---|---|---|
| 00_post_login | (landing) | Dashboard after login |
| 01_dashboard | `/home` | Homeowner dashboard + jobs |
| 02_jobs_list | `/jobs` | Jobs list tab |
| 03_messages | `/messages` | Messages tab |
| 04_profile | `/profile` | Profile tab |
| 05_settings | `/settings` | Settings |
| 06_post_job / 06b | `/jobs/new` | Post-a-Job form (top/bottom) |
| 07_matching | `/jobs/67/matching` | "Contacting tradies" (live dispatch fired) |
| 08_match_result | `/jobs/64/match` | Match Found card (James Ruru) |
| 09_job_detail_inprogress | `/jobs/66/detail` | Stepper In Progress + cancel warn |
| 10_job_detail_booked | `/jobs/65/detail` | Stepper Booked + 10% fee note |
| 11_chat | `/chat/66` | Chat |
| 12_payment | `/jobs/64/payment` | Bank-transfer payment instructions |
| 13_payment_status | `/jobs/64/payment/status` | Payment status |
| 14_dispute | `/jobs/64/dispute` | Open-dispute form |
| 15_tradie_profile | `/tradie/a552097b…` | Tradie public profile |
| 16_homeowner_profile | `/users/ee759288…` | Homeowner public profile |

## tradie/ — tradie-verified@fixo.test
| File | Route | Screen |
|---|---|---|
| 00_post_login | (landing) | Tradie dashboard after login |
| 01_dashboard | `/tradie` | Tradie dashboard |
| 02_jobs_list | `/jobs` | Jobs tab |
| 03_request_detail | `/tradie/requests/68` | ⚠ "Job not found" — pending-offer job isn't fetchable by a non-matched tradie (GET /api/jobs/{id} scope). Real gap, see test-run doc issue 9. |
| 04_active_job_inprogress | `/tradie/jobs/66` | In Progress + Check Out |
| 05_active_job_booked | `/tradie/jobs/65` | Booked + Check In |
| 06_chat | `/chat/66` | Chat |
| 07_messages | `/messages` | Messages tab |
| 08_profile | `/profile` | Profile tab |
| 09_settings | `/settings` | Settings |
| 10_onboarding_wizard | `/tradie/onboarding` | Tradie setup step 1/4 |
| 11_public_profile | `/tradie/a552097b…` | Self public profile |
| 12_homeowner_profile | `/users/ee759288…` | Homeowner public profile |

Fixture jobs used: 64 `AwaitingPayment`, 65 `Booked`, 66 `InProgress`,
67 `Requested` (matching shot dispatched a real offer), 68 `Requested`
with pending JobOffer to tradie-verified.
