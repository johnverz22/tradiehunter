# QA-13 — P11 Compliance & Data Lifecycle

Spec: `../../v1.3/P11-compliance-data-lifecycle.md`.

Precon: QA-00 complete. These cases verify the data retention framework,
purge jobs, and legal configuration surfacing. Purge and anonymization
cases require a test dataset aged beyond the retention thresholds — use
a scratch DB or time-travel approach (temporarily reduce retention values
for testing, restore after).

---

## Retention configuration (P11-01)

- [ ] **P11-01 — RetentionPolicy config present**
  Priority: MAJOR
  1. Inspect `appsettings.json` and `appsettings.Development.json`.
  Expected: `RetentionPolicy` section present with all keys:
  `FinancialRecordsYears` (7), `ChatRetentionMonths` (24),
  `PhotoRetentionMonths` (24), `InactiveAccountMonths` (24),
  `DeviceTokenRetentionDays` (90), `AuditLogRetentionYears` (7),
  `PurgeScheduleCron` ("0 3 1 * *").

- [ ] **P11-02 — Retention options bound in DI**
  Priority: MAJOR
  1. Introduce a deliberate type mismatch in `RetentionPolicy` config;
     restart API.
  Expected: API fails fast with a clear config error, not a silent default.

---

## Purge service (P11-02 / P11-03)

- [ ] **P11-03 — Chat purge (terminal jobs, no open dispute)**
  Priority: MAJOR · Precon: a `Completed` job with chat messages >24 months old
  1. Trigger `PurgeChatMessagesAsync()` directly or via the Hangfire job.
  Expected: chat rows deleted; job NOT deleted (data model intact);
  jobs with open disputes skipped; financial records untouched.

- [ ] **P11-04 — Photo purge deletes blobs**
  Priority: MAJOR · Precon: a `Completed` job with photos >24 months old
  1. Trigger `PurgeJobPhotosAsync()`.
  Expected: blob deleted from Azure (`fixo-payments` or job photos container);
  `photos` field on the job cleared; blob key no longer accessible via SAS.

- [ ] **P11-05 — Stale device tokens purged**
  Priority: MINOR · Precon: device token with `LastSeen` >90 days ago
  1. Trigger `PurgeStaleDeviceTokensAsync()`.
  Expected: old tokens deleted; recent tokens unaffected; no push attempt
  to deleted tokens.

- [ ] **P11-06 — Inactive account anonymization**
  Priority: MAJOR · Precon: a user not logged in for >24 months, no active jobs
  1. Trigger `AnonymizeInactiveAccountsAsync()`.
  Expected: `FullName → "Deleted User"`, email → hash, phone/address → null;
  account row PRESERVED (not deleted); review history intact (stars/comment
  remain, `from_user`/`to_user` FK still valid); user cannot log in but
  row exists for audit purposes.

- [ ] **P11-07 — Financial records NEVER purged**
  Priority: BLOCKER
  1. Run all purge methods on a DB containing old `payments`, `refunds`,
     `tradie_payouts`, `payout_batches` rows.
  Expected: all financial rows survive; purge service explicitly skips
  them; no code path deletes them automatically.

- [ ] **P11-08 — Purge summary to audit log**
  Priority: MAJOR · Precon: P11-03–P11-06
  1. Check audit log after purge run.
  Expected: one structured audit entry per purge category with count of
  records affected; notification sent to superadmin.

---

## Legal config & links (P11-04 / P11-05)

- [ ] **P11-09 — Legal fields in config endpoint**
  Priority: MAJOR
  1. `GET /api/config/locale`.
  Expected: response includes `legalEntityName`, `legalEntityCountry`,
  `termsOfServiceUrl`, `privacyPolicyUrl` — all non-empty strings matching
  `appsettings.json Locale` section.

- [ ] **P11-10 — Mobile Terms & Privacy links**
  Priority: MAJOR
  1. Open registration screen in-app.
  Expected: "By signing up, you agree to our [Terms of Service] and
  [Privacy Policy]" with tappable links; links open in-app browser
  (not native browser); URLs sourced from `GET /api/config/locale`.
  2. Open settings → Legal section.
  Expected: both links present and functional.

---

## Web data retention dashboard (P11-06)

- [ ] **P11-11 — Data Retention page (Superadmin only)**
  Priority: MAJOR
  1. Open `/admin/data-retention` as Superadmin; then as Staff.
  Expected: Superadmin sees retention policy values, last purge date/summary,
  "Run Purge Now" button, "Financial records are never auto-purged" warning;
  Staff gets 403.

  _(Note: this page is a Superadmin-only view — it does not appear in the
  standard Staff nav.)_
