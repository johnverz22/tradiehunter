# Phase 11: Compliance & Data Lifecycle

This phase implements data retention policies, purge automation, and legal entity configuration required before launch. These are compliance-driven items that don't affect the core user flow but are necessary for regulatory readiness.

**Prerequisites:** Phase 10 complete (specifically P10-15 for brand/legal config).

---

## P11-01: Backend — Data Retention Configuration

**Platform:** Backend
**Description:** Add retention policy configuration for different data categories.

**References:**
- `appsettings.json`
- `Options/RetentionOptions.cs` (new)

**Acceptance Criteria:**
- [ ] Add `RetentionPolicy` section to `appsettings.json`:
  ```json
  {
    "RetentionPolicy": {
      "FinancialRecordsYears": 7,
      "ChatRetentionMonths": 24,
      "PhotoRetentionMonths": 24,
      "InactiveAccountMonths": 24,
      "DeviceTokenRetentionDays": 90,
      "AuditLogRetentionYears": 7,
      "PurgeScheduleCron": "0 3 1 * *"
    }
  }
  ```
- [ ] Create `Options/RetentionOptions.cs` with matching properties.
- [ ] Bind in DI.
- [ ] Document rationale:
  - 7 years for financial records: NZ Tax Administration Act 1994 (s 22), Companies Act 1993 (s 194).
  - 24 months for chat/photos: reasonable purpose-based retention per Privacy Act 2020 IPP 9.
  - 24 months for inactive accounts: allows re-engagement; after which anonymize or delete.

---

## P11-02: Backend — Data Purge Service

**Platform:** Backend
**Description:** Service to purge expired data according to retention policy.

**References:**
- `Services/DataRetentionService.cs` (new)

**Acceptance Criteria:**
- [ ] `PurgeChatMessagesAsync()`: Delete `messages` rows for jobs completed more than `ChatRetentionMonths` ago. Only delete if job is in a terminal state (Completed, Cancelled, Expired) and no open dispute exists.
- [ ] `PurgeJobPhotosAsync()`: Delete blob storage photos and clear `photos` field for jobs completed more than `PhotoRetentionMonths` ago. Same terminal-state guard.
- [ ] `PurgeStaleDeviceTokensAsync()`: Delete `device_tokens` where `LastSeen` is older than `DeviceTokenRetentionDays`.
- [ ] `AnonymizeInactiveAccountsAsync()`: For users who haven't logged in within `InactiveAccountMonths` and have no active jobs: anonymize PII (name → "Deleted User", email → hash, phone → null, address → null). Do NOT delete the account row (preserve review/job history integrity).
- [ ] **Financial records (`payments`, `refunds`, `tradie_payouts`, `payout_batches`) are NEVER purged by this service** — they are retained for `FinancialRecordsYears` and only purged manually by superadmin.
- [ ] Log all purge actions to audit log.

---

## P11-03: Backend — Retention Purge Hangfire Job

**Platform:** Backend
**Description:** Monthly Hangfire job to execute data purges.

**References:**
- `Jobs/DataRetentionPurgeJob.cs` (new)

**Acceptance Criteria:**
- [ ] Register Hangfire recurring job using `RetentionPolicy.PurgeScheduleCron` (default: 1st of each month at 3 AM UTC).
- [ ] Calls `DataRetentionService` methods in sequence: device tokens → chat → photos → inactive accounts.
- [ ] Emits summary to audit log: counts of records purged per category.
- [ ] Sends notification to superadmin with purge summary.

---

## P11-04: Backend — Privacy Policy & Terms Links

**Platform:** Backend
**Description:** Surface legal entity and policy links via the config endpoint.

**References:**
- `Controllers/ConfigController.cs`

**Revises:**
- `Controllers/ConfigController.cs`

**Acceptance Criteria:**
- [ ] `GET /api/config/locale` response includes:
  - `legalEntityName` (string)
  - `legalEntityCountry` (string)
  - `termsOfServiceUrl` (string)
  - `privacyPolicyUrl` (string)
- [ ] Values read from `Locale` config section (added in P10-15).

---

## P11-05: Mobile — Terms & Privacy Links

**Platform:** Mobile
**Description:** Display Terms of Service and Privacy Policy links in onboarding and settings.

**References:**
- `lib/views/onboarding/`
- `lib/views/settings_screen.dart`

**Revises:**
- Onboarding and settings screens

**Acceptance Criteria:**
- [ ] Registration screen: "By signing up, you agree to our [Terms of Service] and [Privacy Policy]" with links from config.
- [ ] Settings screen: "Legal" section with links to Terms and Privacy Policy (opens in-app browser).
- [ ] Links fetched from `GET /api/config/locale`.

---

## P11-06: Web Admin — Data Retention Dashboard

**Platform:** Web
**Description:** Admin view showing data retention status and manual purge trigger.

**References:**
- `src/features/admin/` (new page)

**Acceptance Criteria:**
- [ ] Create `DataRetention.tsx` at route `/admin/data-retention` (superadmin only).
- [ ] Display current retention policy values (from config endpoint or dedicated admin endpoint).
- [ ] Show last purge date and summary (from audit log).
- [ ] "Run Purge Now" button (superadmin only) — triggers immediate execution of the purge job.
- [ ] Warning banner: "Financial records are never auto-purged."

---

## P11-07: Documentation — Compliance Checklist

**Platform:** Documentation
**Description:** Create a compliance checklist document for pre-launch legal review.

**References:**
- `docs/COMPLIANCE-CHECKLIST.md` (new)

**Acceptance Criteria:**
- [ ] Document all pre-launch legal requirements from MVP-SPEC-v1.3 §15.
- [ ] Include per-country deployment considerations.
- [ ] Reference specific NZ legislation (FSP Act 2008, FMC Act 2013, Privacy Act 2020, Tax Administration Act 1994, AML/CFT Act 2009, Building Act 2004).
- [ ] Status column for tracking completion.

---

## Implementation Notes

- **Chat purge is soft:** Messages are deleted from the database, but if a dispute references chat history, the relevant messages should be preserved (or already captured in dispute evidence). The purge service checks for open disputes before deleting.
- **Photo purge deletes blobs:** Both the database `photos` JSON array and the actual Azure Blob files are removed. Use `BlobStorageService.DeleteAsync(fileKey)`.
- **Account anonymization preserves reviews:** The `reviews` table references `from_user` and `to_user` by ID. The review text and rating remain; only the user's profile is anonymized. This is necessary for marketplace trust integrity.
- **Timezone for purge:** Purge cron runs at 3 AM UTC (3 PM NZST / 4 PM NZDT). Low-traffic window for NZ users.
- **No purge for credentials/receipts within financial retention window:** `tradie_credentials` and `fixo-payments` blobs are retained for the full financial retention period because they are part of the audit trail.
