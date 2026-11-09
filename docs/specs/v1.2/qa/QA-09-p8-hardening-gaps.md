# QA-09 — P8 Hardening gaps (assert current status)

Spec: `../P8-hardening.md`. All P8 checkboxes are `[ ]` in the spec — this
file asserts what is true TODAY so gaps are accepted explicitly, never
passed silently.

- [ ] **P8-01 — AuditLog table ABSENT**
  Priority: MAJOR (gap)
  1. Look for an `AuditLogs` table / `AddAuditLogs` migration.
  Expected TODAY: absent — admin verify/refund/suspend leaves no structured
  audit row. Record as known gap if release requires it.

- [ ] **P8-02 — Report & block ABSENT**
  Priority: MAJOR (gap)
  1. Look for `UserBlock` entity, block/report endpoints, chat
     "Report/Block" menu.
  Expected TODAY: absent — matching does NOT exclude blocked users; no
  `Abuse`-from-chat flag path.

- [ ] **P8-03 — Signed/SAS URLs PRESENT (partial P8)**
  Priority: BLOCKER
  1. Open a credential, a receipt, dispute evidence, and a refund proof URL.
  Expected: 15-min SAS via `GetReadSasUriAsync`, no anonymous container
  read. ANY public or proxy URL that bypasses expiry is a bug.

- [ ] **P8-04 — Admin audit integration ABSENT**
  Priority: MAJOR (gap)
  1. Verify a credential, process a refund, suspend a user; inspect logs/DB.
  Expected TODAY: no old/new JSON audit capture.

- [ ] **P8-05 — Expiration worker ABSENT**
  Priority: MAJOR (gap)
  1. Leave a job `Requested` 24h+ with no offers.
  Expected TODAY: NO automatic `Cancelled` — stale `Requested` jobs persist.

- [ ] **P8-06 — Email fallback ABSENT**
  Priority: MAJOR (gap)
  1. Remove device tokens (push disabled); trigger refund-processed /
     cancel / suspension.
  Expected TODAY: NO fallback email — user gets nothing.

- [ ] **P8-07 — Audit log UI ABSENT**
  Priority: MINOR (gap)
  1. Look for an Audit Logs page in admin nav.
  Expected TODAY: absent.

- [ ] **P8-08 — Metrics dashboard ABSENT**
  Priority: MINOR (gap)
  1. `GET /api/admin/metrics`; look for dashboard charts.
  Expected TODAY: absent — no activation-rate / match-to-payment /
  verification-time / response-rate aggregates.
