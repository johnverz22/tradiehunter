# QA-09 — P8 Hardening gaps (assert current status)

Spec: `../../v1.2/P8-hardening.md`. Inherited from v1.2.

**v1.3 note:** P8-01 (audit log) and P8-07/P8-08 are now RESOLVED in v1.3 —
the audit log table, Audit Logs admin page, and metrics dashboard were
delivered. Update the expected outcome for those items accordingly.

All P8 checkboxes were `[ ]` in the v1.2 spec — this file asserts what
is true so gaps are accepted explicitly, never passed silently.

- [ ] **P8-01 — AuditLog table PRESENT (v1.3 resolved)**
  Priority: MAJOR
  1. Look for `AuditLogs` table / `AddAuditLogs` migration.
  2. Perform admin verify/refund/suspend; inspect audit rows.
  Expected (v1.3): table present; admin actions write structured audit rows.
  If still absent, record as regression.

- [ ] **P8-02 — Report & block ABSENT**
  Priority: MAJOR (gap)
  1. Look for `UserBlock` entity, block/report endpoints, chat
     "Report/Block" menu.
  Expected TODAY: absent — matching does NOT exclude blocked users; no
  `Abuse`-from-chat flag path. Accepted known gap.

- [ ] **P8-03 — Signed/SAS URLs PRESENT**
  Priority: BLOCKER
  1. Open a credential, a receipt, dispute evidence, and a refund proof URL.
  Expected: 15-min SAS via `GetReadSasUriAsync`, no anonymous container
  read. ANY public or proxy URL that bypasses expiry is a bug.

- [ ] **P8-04 — Admin audit integration PRESENT (v1.3 resolved)**
  Priority: MAJOR
  1. Verify a credential, process a refund, suspend a user; inspect logs/DB.
  Expected (v1.3): old/new JSON audit rows written. If absent, regression.

- [ ] **P8-05 — Expiration worker ABSENT**
  Priority: MAJOR (gap)
  1. Leave a job `Requested` 24h+ with no offers.
  Expected TODAY: NO automatic `Cancelled` — stale `Requested` jobs persist.
  Accepted known gap.

- [ ] **P8-06 — Email fallback ABSENT**
  Priority: MAJOR (gap)
  1. Remove device tokens (push disabled); trigger refund-processed /
     cancel / suspension.
  Expected TODAY: NO fallback email — user gets nothing. Accepted known gap.

- [ ] **P8-07 — Audit log UI PRESENT (v1.3 resolved)**
  Priority: MINOR
  1. Look for an Audit Logs page in admin nav.
  Expected (v1.3): present at `/audit-logs`. If absent, regression.

- [ ] **P8-08 — Metrics dashboard PRESENT (v1.3 resolved)**
  Priority: MINOR
  1. `GET /api/admin/metrics`; open dashboard charts.
  Expected (v1.3): activation-rate / match-to-payment / verification-time /
  response-rate aggregates present. If absent, regression.
