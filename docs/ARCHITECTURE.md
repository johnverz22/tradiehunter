# TradieHunter — Architecture

> Stack, topology and the seams that keep it swappable. Behaviour lives in [SPECS.md](SPECS.md). Code identifiers still use the old codename `Fixo` (see [README](README.md#naming-tradiehunter-vs-fixo)).

## Stack

| Layer | Technology |
|---|---|
| Backend | .NET 10, ASP.NET Core Web API, EF Core, ASP.NET Identity + JWT (project `FixoApi`) |
| Real-time | SignalR hubs: chat, job-status transitions, offer/match notifications. One hub contract shared by Flutter and React; Redis backplane |
| Mobile | Flutter / Dart, Riverpod, go_router, Dio, `flutter_secure_storage`. One app, role-based views. Runs on the host, not in Docker |
| Web admin | React 19, TypeScript, Vite, TanStack Query, react-router-dom v7, Tailwind CSS v4. Admin only, cookie auth |
| Database | PostgreSQL 16 + PostGIS (dev), EF Core Npgsql + NetTopologySuite; SQL Server swappable |
| Cache / jobs | Redis 7 (SignalR backplane, Hangfire storage) |
| Blob storage | Azure Blob (`Azure.Storage.Blobs`); Azurite locally |
| Push | Firebase Cloud Messaging via the Admin SDK |
| Email | MailKit SMTP, Razor templates; MailHog/Mailpit locally |
| Infra / CI | Docker Compose (OrbStack); GitHub Actions `.github/workflows/ci.yml` |

## Feature → technology

| Feature | Tech |
|---|---|
| Auth | Identity + Google OAuth; JWT + hashed refresh tokens (mobile); `AdminCookie` (web) |
| Job posting | REST; photos to Azure Blob; address via `IAddressResolver` (LINZ) |
| Matching / offers | `MatchingService` (spatial LINQ), `SendOfferJob`, `OfferTimeoutJob` |
| Status, chat, notifications | SignalR + FCM, all status changes through `IJobStatusService` |
| Payments | `IPaymentProvider` / `IPaymentService`; `ManualReceiptProvider` is the only implementation |
| Payouts | `PayoutService`, weekly `PayoutBatchJob` |
| Scheduling | Hangfire |
| Admin | Role-gated React views over admin-only REST endpoints |

## Seams

- **Payments:** `IPaymentProvider` (`CreatePayment`, `GetStatus`, `Refund`, webhook handling for future providers). A gateway means a new implementation and one DI registration; the job state machine and `IPaymentService` do not change. `provider` and `provider_reference` are stored from day one.
- **Address:** `IAddressResolver`; `AddressResolution:Provider` selects the adapter. Flutter never calls LINZ.
- **Blob:** only `IBlobStorageService` (`AzureBlobStorageService`) touches storage; environments differ by the `AzureBlob` config only. Private documents are read through short-lived service-SAS URLs. Locally `ExternalServiceUrl` rewrites SAS hosts so phones can reach Azurite; in production omit it and supply the key through Key Vault / `AzureBlob__AccountKey`.
- **Database provider:** swap the NuGet package and connection string, re-run migrations. Never write raw PostGIS SQL.
- **Locale / brand:** `Locale` and `Brand` config drive currency, phone format, timezone, legal entity and every user-facing brand string, served to clients by `GET /api/config/locale`.

## Background jobs (Hangfire, Redis)

`SendOfferJob`, `OfferTimeoutJob`, `PaymentSlaJob`, `PaymentExpiryJob` (legacy flow cancels; v2 reminds and flags), `AutoCompleteJob` (legacy) / auto-approve (v2), `PayoutBatchJob`, `RevealReviewsJob`, adjustment expiry + reminders, reminder jobs, `EmailBounceReportJob`. Dashboard at `/hangfire`, Superadmin only.

## Local topology

```
Docker Compose
  postgres(+PostGIS)   azurite (Blob :10000)   redis   mailhog
          └──────────────┬───────────────┘
                 .NET API (REST + SignalR + Hangfire + FCM)
                         │
                  React admin (web, :3000)

Host: Flutter app (simulators/devices) ──► API (:5000)
```

Containers are named `api`, `db`, `redis`, `azurite`, `web`. Run `dotnet` inside the API container: `docker compose run --rm --entrypoint /bin/bash api -c "dotnet <command>"`.

## Why this stack

.NET + EF Core suits a transactional marketplace and has a mature auth story. One Flutter app with role-based views avoids two mobile codebases. Web is admin-only to avoid duplicate UIs. SignalR is the single real-time layer. PostGIS is free, Docker-friendly and handles geo natively. FCM keeps tradies reachable when the app is backgrounded, which drives response rate.
