# Fixo v1.2 Specifications

This directory contains the detailed, phase-by-phase implementation specifications for the Fixo v1.2 MVP update. These specs are derived from `docs/MVP-SPEC-v1.2.md` and broken down into actionable development tasks across the Backend (.NET), Mobile (Flutter), and Web (React Admin) platforms.

## Implementation Phases

*   **[Phase 0: Foundation](P0-foundation.md)** - Configuration, Roles, and State Machine updates.
*   **[Phase 1: Registration, OTP, & Verification](P1-registration-otp-verification.md)** - Email verification, Tradie profile setup, and Admin credential queue.
*   **[Phase 2: Job Request Revision](P2-job-request-revision.md)** - Rates, hours, scheduled start time, and reference codes.
*   **[Phase 3: Matching with Offers & Timeouts](P3-matching-offers-timeouts.md)** - Sequential offers, timeouts, and broadened matching.
*   **[Phase 4: Manual Payment & Admin Queue](P4-manual-payment-admin-queue.md)** - Manual receipt upload, IPaymentProvider abstraction, and Admin verification.
*   **[Phase 5: Booked to Completed Lifecycle](P5-booked-to-completed.md)** - Check-in/check-out, reminders, and auto-completion.
*   **[Phase 6: Cancellations & Refunds](P6-cancellations-refunds.md)** - Role-based cancellation flows, refund calculations, and Admin processing.
*   **[Phase 7: Disputes, No-shows & Flags](P7-disputes-noshows-flags.md)** - Evidence upload, admin dispute resolution, and account flagging.
*   **[Phase 8: Hardening](P8-hardening.md)** - Abuse reporting, secure buckets, compliance, and fallback communications.
*   **[Phase 9: Auth & Mobile Security Hardening](P9-auth-security-hardening.md)** - Privilege escalation fix, httpOnly cookie auth for web admin (RFC 10017 BCP), refresh token rotation, Android cleartext traffic, login lockout, JWT algorithm pinning (RFC 8725), mobile access-token-in-memory pattern (RFC 8252), and TokenValidationParameters hardening. Audit conducted 2026-09-28.

## Development Rules

1.  **Money**: Always use `decimal`, never `float`.
2.  **Time**: Store UTC in the database, localize on the client.
3.  **Database**: Use EF Core spatial LINQ (NetTopologySuite), never raw PostGIS SQL.
4.  **State Transitions**: All job status changes must go through the central `IJobStatusService`.
5.  **Environment**: Run backend `dotnet` commands inside the Docker container (`api`).
