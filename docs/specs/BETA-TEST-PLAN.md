# Fixo — Closed Beta Test Plan

**Version**: 1.0  
**Date**: 2026-09-27  
**Beta region**: Auckland, New Zealand  
**Cohort size target**: 5–10 homeowners, 5–10 tradies (plumbing, electrical, general)

---

## Goals

1. Validate the core loop works end-to-end with real users in a real environment.  
2. Measure the four success metrics under real conditions (see [Success Metrics](#success-metrics)).  
3. Identify UX friction points before wider rollout.  
4. Stress-test matching within a single geographic region.

---

## Infrastructure Checklist

| Item | Status | Notes |
|------|--------|-------|
| Firebase production project configured | ☐ | Use `fixo-prod` project; update `FIREBASE_PROJECT_ID` env var |
| FCM production credentials in place | ☐ | Download production `google-services.json` (Android) and `GoogleService-Info.plist` (iOS); **do not commit to repo** |
| PostgreSQL hosted (production) | ☐ | e.g., Neon, AWS RDS, or Azure Database for PostgreSQL |
| MinIO / S3 bucket policies set | ☐ | See [MinIO Bucket Policy](#minio--s3-bucket-policy) below |
| JWT secret rotated for production | ☐ | Replace dev secret in `appsettings.json` with secrets manager value |
| Admin seed user ready | ☐ | `AdminSeedService` runs on startup; override `AdminSeed:*` via env vars |
| CORS configured for production domain | ☐ | Update `AllowedHosts` and add CORS policy for web admin origin |
| HTTPS enforced | ☐ | Set `RequireHttpsMetadata = true` in JWT bearer options |
| Hangfire dashboard secured | ☐ | Remove dev `Authorization = []`; add auth check before exposing `/hangfire` |

---

## FCM — Production Configuration

1. Go to [Firebase Console](https://console.firebase.google.com) → `fixo-prod` project → Project Settings → Cloud Messaging.
2. Download:
   - **Android**: `google-services.json` → place in `mobile/android/app/`
   - **iOS**: `GoogleService-Info.plist` → place in `mobile/ios/Runner/`
3. Download the **service account key** (JSON) for the backend Firebase Admin SDK:
   - Project Settings → Service accounts → Generate new private key.
   - Set `FIREBASE_SERVICE_ACCOUNT_KEY_PATH` env var to the mounted path (e.g. `/run/secrets/firebase-sa.json`).
   - **Never commit this file to source control.**
4. Update `FIREBASE_PROJECT_ID` environment variable to the production project ID.
5. Verify FCM by sending a test notification via Firebase Console → Cloud Messaging → Send test message.

---

## MinIO / S3 Bucket Policy

For local dev MinIO, apply this read-only public policy to the `fixo-photos` bucket so uploaded photos are served directly:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "AWS": ["*"] },
      "Action": ["s3:GetObject"],
      "Resource": ["arn:aws:s3:::fixo-photos/*"]
    }
  ]
}
```

Apply via MinIO console (`http://localhost:9001`) or CLI:

```bash
mc alias set local http://localhost:9000 fixo fixo_dev_secret
mc anonymous set download local/fixo-photos
```

For production, use a private bucket with pre-signed URL generation (already supported by `S3BlobStorageService`).

---

## Beta Region: Auckland

- Matching radius: **25 km** (configurable via Admin → Settings).  
- Trade categories in scope for beta: **Plumbing**, **Electrical**, **General**.  
- Tradies must complete their profile (location in Auckland metro area) and be verified by admin before they appear in match results.

---

## Success Metrics

Target benchmarks for the closed beta window (2–4 weeks):

| Metric | Target | How Measured |
|--------|--------|-------------|
| Activation rate | ≥ 50% sign up → post first job within 24h | Admin → Dashboard → Metrics |
| Match-to-confirmation time | ≤ 2 hours median | Admin → Dashboard → Metrics |
| Tradie response rate | ≥ 70% of matches accepted/declined within 1h | Admin → Dashboard → Metrics |
| Review completion rate | ≥ 60% of completed jobs reviewed by both parties | Admin → Dashboard → Metrics |

---

## Onboarding Instructions for Beta Testers

### Homeowners

1. Download the Fixo app (TestFlight / Firebase App Distribution link TBA).
2. Sign up with your email; select **Homeowner** role.
3. Post a job: pick a trade category, describe the problem, set urgency, and drop a pin on your Auckland address.
4. Wait for a tradie match (typically within minutes during business hours).
5. Chat directly in the app; confirm a time.
6. After the job, rate your tradie.

**Known limitations for beta** — see [Known Limitations](#known-limitations).

### Tradies

1. Download the Fixo app.
2. Sign up with your email; select **Tradie** role.
3. Complete your profile: select your trade, set your Auckland address, leave availability on.
4. Wait for admin verification (within 24h of sign-up for beta cohort).
5. Once verified, you'll receive match notifications for jobs in your area.
6. Accept or decline requests from the request detail screen.
7. Chat and coordinate directly; mark jobs started and complete.

---

## Known Limitations

| # | Limitation | Impact | Workaround / Timeline |
|---|-----------|--------|----------------------|
| 1 | **No in-app payments** — payment is handled outside the app (cash / bank transfer) | Tradies & homeowners must agree on payment separately | V1.1 (BNZ integration) |
| 2 | **Matching is rule-based only** — no ML ranking; closest verified tradie in category wins | May not always surface the best-rated tradie | V1.1 (ranking signals) |
| 3 | **FCM requires a real device** — push notifications don't work in iOS Simulator | Beta testers need a physical device for push | Known; use in-app notification fallback |
| 4 | **Scheduling confirmation is manual** — both parties must confirm via chat; no calendar integration | Extra back-and-forth for time coordination | V1.1 (calendar sync) |
| 5 | **Job cancellation by homeowner is not yet exposed in mobile UI** — can be done via API | Homeowners can't cancel from the app screen yet | V1.1 |
| 6 | **Dispute resolution is manual** — admin resolves via dashboard; no automated flows | Admin must review and act on each flagged dispute | MVP intentional; V1.1 automation |
| 7 | **Refresh tokens are stub** — sessions expire after JWT lifetime (60 min); users must re-login | Minor friction for active users | Fix in V1.1 |
| 8 | **Admin settings changes are in-memory** — restarting the API resets locale settings to `appsettings.json` defaults | Config changes don't survive restarts | V1.1 (persist to DB) |

---

## Beta Feedback Collection

- Use a shared feedback channel (Slack / WhatsApp group) for the beta cohort.
- Bugs: report via admin dashboard Disputes (flag with reason "Bug report: …") or direct email.
- Admin monitors dashboard daily; disputes reviewed within 24h.

---

## Go / No-Go Criteria (after 2-week beta)

| Criterion | Threshold |
|-----------|-----------|
| Zero data-loss incidents | Required |
| Activation rate | ≥ 30% (relaxed for small cohort) |
| At least one complete job flow with review | Required |
| No P0/P1 security issues open | Required |
