# QA-00 — Environment setup

Seed once per full run. All later files assume these accounts exist.

v1.3 adds P10/P11 requirements to environment setup: the locale config
endpoint must now return brand, commission, and legal-entity fields.

- [ ] **ENV-01 — Stack boots**
  Priority: BLOCKER · Precon: clean checkout
  1. `docker compose up` (OrbStack).
  2. Check api, postgres+PostGIS, Azurite (:10000), redis, Hangfire.
  Expected: all healthy, no crash-loops, `/hangfire` reachable (auth-gated,
  see QA-10).

- [ ] **ENV-02 — Config present (v1.3 shape)**
  Priority: BLOCKER · Precon: ENV-01
  1. `GET /api/config/locale`.
  2. Inspect all sections:
     - `PaymentInstructions` (AccountName, AccountNumber,
       ReferenceFormat `FIXO-{JobId}`, WindowHours, PaymentsContainer)
     - `OfferTimeoutMinutes`, `AutoCompleteWindowHours`
     - **v1.3** `commissionPercent` (default 12.5)
     - **v1.3** `brand` object: `appName` ("TradieFixo"),
       `supportEmail`, `supportHoursDisplay`
     - **v1.3** `locale` additions: `legalEntityName`,
       `legalEntityCountry`, `termsOfServiceUrl`, `privacyPolicyUrl`,
       `pilotRegion`, `maxSearchRadiusKm`, `defaultSearchRadiusKm`,
       `materialsDisclaimer`
  Expected: all keys present, typed. No hardcoded bank details or brand
  strings anywhere in UI.

- [ ] **ENV-03 — MailHog receives mail**
  Priority: BLOCKER · Precon: ENV-01
  1. Register a throwaway user.
  2. Open MailHog/Papercut inbox.
  Expected: OTP email arrives within ~30s. Push notification titles read
  "TradieFixo: …" (not "Fixo: …").

- [ ] **ENV-04 — Test accounts seeded**
  Priority: BLOCKER · Precon: ENV-01–03
  1. Create: HOMEOWNER-A (verified), HOMEOWNER-B (unverified),
     TRADIE-VERIFIED (≥1 approved credential + schedule + rates + bank
     details), TRADIE-UNVERIFIED, TRADIE-2 (verified, for sequential
     offers), TRADIE-PAUSED (verified but `IsAvailable=false`),
     STAFF, SUPERADMIN.
  2. Log in once as each; note which JWT belongs to whom (never paste
     tokens into bug reports).
  Expected: all 8 log in; TRADIE-VERIFIED shows no pending banner;
  TRADIE-UNVERIFIED shows the amber banner; TRADIE-PAUSED shows the
  amber "you're paused" banner on their dashboard.

- [ ] **ENV-05 — Commission config reachable**
  Priority: MAJOR · Precon: ENV-02
  1. Read `commissionPercent` from `GET /api/config/locale`.
  2. Confirm it matches `appsettings.json PayoutOptions:CommissionPercent`.
  Expected: value consistent; default 12.5.
