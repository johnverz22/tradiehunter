# Phase 8: Hardening

## P8-01: Audit Log Data Model & Migration
**Platform:** Backend

**Description:**
Implement an audit log table for critical system and admin actions.

**References:**
- `Models/AuditLog.cs` (new)
- `Data/ApplicationDbContext.cs`

**Acceptance Criteria:**
- [x] Create `AuditLog` entity: `Id`, `UserId` (who did it), `Action` (string), `EntityType` (string), `EntityId` (string), `OldValues` (JSON), `NewValues` (JSON), `IpAddress` (string), `CreatedAtUtc`.
- [x] Generate and apply migration `AddAuditLogs`.

## P8-02: Report and Block User Flow
**Platform:** Backend & Mobile

**Description:**
Allow users to report abuse in chat or on profiles, and block other users.

**References:**
- `Models/UserBlock.cs` (new)
- `Controllers/ProfileController.cs`

**Acceptance Criteria:**
- [x] Create `UserBlock` entity (`BlockerId`, `BlockedId`, `CreatedAtUtc`).
- [x] Backend endpoint to block a user; ensure matching service excludes blocked users.
- [x] Backend endpoint to report a user (creates an `AccountFlag` of type `Abuse`).
- [x] Mobile UI: "Report" and "Block" options in Chat menu and Public Profile.

## P8-03: Signed URLs for Private Storage
**Platform:** Backend

**Description:**
Secure sensitive documents (credentials, receipts, dispute evidence) so they are not publicly accessible.

**References:**
- `Services/BlobStorageService.cs`

**Acceptance Criteria:**
- [x] Modify `BlobStorageService` to support private buckets.
- [x] Add method `GenerateSignedUrl(string fileKey, TimeSpan expiration)` for temporary access.
- [x] Update endpoints returning sensitive file URLs (Dispute evidence, Tradie credentials, Refund proofs) to generate and return signed URLs instead of public URLs.

## P8-04: Admin Audit Log Integration
**Platform:** Backend

**Description:**
Record admin actions in the audit log.

**References:**
- `Services/AdminService.cs`

**Acceptance Criteria:**
- [x] Intercept or explicitly log actions in Admin endpoints (verifying credentials, processing refunds, overriding statuses, suspending users).
- [x] Store old and new states in the JSON fields.

## P8-05: Expiration Background Service
**Platform:** Backend

**Description:**
Handle requests that expire due to inaction.

**References:**
- `Services/ExpirationWorker.cs` (new HostedService)

**Acceptance Criteria:**
- [x] Create background worker running periodically (e.g., every 5 mins).
- [x] Find jobs in `Requested` status older than a configured threshold (e.g., 24 hours).
- [x] Transition them to `Cancelled` with a specific reason code (e.g., `SystemExpired`).
- [x] Release any holds and notify the homeowner.

## P8-06: Email Fallback Notification Service
**Platform:** Backend

**Description:**
Send emails for critical events if push notifications are disabled or fail.

**References:**
- `Services/PushNotificationService.cs`
- `Services/EmailService.cs`

**Acceptance Criteria:**
- [x] Implement `EmailService` using a provider (e.g., SendGrid/AWS SES).
- [x] Identify critical notification types (Refund processed, Account suspended, Job cancelled).
- [x] If user has push disabled (no device tokens) or critical event occurs, dispatch an email.

## P8-07: Admin Audit Log UI
**Platform:** Web

**Description:**
Allow admins to view the audit log.

**References:**
- `src/features/admin/AuditLogs.tsx` (new)

**Acceptance Criteria:**
- [x] Create an Audit Logs page in the web admin.
- [x] Table displaying timestamp, admin/user, action, entity, and a modal to view JSON diffs.
- [x] Filtering by date, action, or user ID.

## P8-08: Key Metrics Dashboards
**Platform:** Web/Analytics

**Description:**
Provide insights into marketplace health for admins.

**References:**
- `Controllers/AdminController.cs`

**Acceptance Criteria:**
- [x] Add backend endpoint `GET /api/admin/metrics` returning aggregated data: activation rate, match-to-AwaitingPayment time, payment verification time, tradie response rate.
- [x] Display charts/summary cards on the Admin Web Dashboard.
