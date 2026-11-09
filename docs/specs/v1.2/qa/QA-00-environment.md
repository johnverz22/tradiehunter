# QA-00 — Environment setup

Seed once per full run. All later files assume these accounts exist.

- [ ] **ENV-01 — Stack boots**
  Priority: BLOCKER · Precon: clean checkout
  1. `docker compose up` (OrbStack).
  2. Check api, postgres+PostGIS, Azurite (:10000), redis, Hangfire.
  Expected: all healthy, no crash-loops, `/hangfire` reachable (auth-gated, see QA-10).

- [ ] **ENV-02 — Config present**
  Priority: BLOCKER · Precon: ENV-01
  1. `GET /api/config/locale`.
  2. Inspect `PaymentInstructions` (AccountName, AccountNumber,
     ReferenceFormat `FIXO-{JobId}`, WindowHours, PaymentsContainer),
     `OfferTimeoutMinutes`, `AutoCompleteWindowHours`.
  Expected: all keys present, typed. No hardcoded bank details anywhere in UI.

- [ ] **ENV-03 — MailHog receives mail**
  Priority: BLOCKER · Precon: ENV-01
  1. Register a throwaway user.
  2. Open MailHog/Papercut inbox.
  Expected: OTP email arrives within ~30s.

- [ ] **ENV-04 — Test accounts seeded**
  Priority: BLOCKER · Precon: ENV-01–03
  1. Create: HOMEOWNER-A (verified), HOMEOWNER-B (unverified),
     TRADIE-VERIFIED (≥1 approved credential + schedule + rates),
     TRADIE-UNVERIFIED, TRADIE-2 (verified, for sequential offers),
     STAFF, SUPERADMIN.
  2. Log in once as each; note which JWT belongs to whom (never paste
     tokens into bug reports).
  Expected: all 7 log in; TRADIE-VERIFIED shows no pending banner,
  TRADIE-UNVERIFIED shows the amber banner.
