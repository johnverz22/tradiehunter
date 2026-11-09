# Fixo — Architecture

## Stack
- **Backend**: .NET 10 (ASP.NET Core Web API) — single source of truth for both Flutter and React clients. REST for CRUD, SignalR for real-time.
- **Mobile**: Flutter — single app, role-based UI (homeowner/tradie), primary client for the MVP. Consumes REST + SignalR + receives FCM push.
- **Web**: React — admin dashboard only for MVP. Role-gated to admin endpoints.
- **Real-time**: SignalR hubs for (1) chat messages, (2) job-status transitions, (3) match notifications. Both Flutter and React connect to the same hub endpoints.
- **Push**: Firebase Cloud Messaging — background push for match notifications, status changes, reminders. Critical for tradie response rate.
- **Database**: PostgreSQL 16 + PostGIS for geo queries (dev). EF Core with Npgsql provider; swappable to SQL Server (`Microsoft.EntityFrameworkCore.SqlServer`) for production via configuration.
- **Blob storage**: Azure Blob Storage via the Azure SDK (`Azure.Storage.Blobs`) — Azurite emulator locally, Azure Blob Storage in production. Three containers: `fixo-photos` (job photos), `fixo-credentials` (private tradie verification docs, SAS-gated reads) and `fixo-payments` (manual payment receipts, SAS-gated reads).
- **Cache / backplane**: Redis — SignalR backplane for scale-out, Hangfire job storage.
- **Scheduling**: Hangfire with Redis storage for background jobs (reminders, notifications).
- **Local dev**: Docker Compose on OrbStack.

## Feature-to-tech mapping

| Feature | Tech |
|---|---|
| Auth | ASP.NET Identity + OAuth (Google); JWT issued to Flutter & React |
| Job posting | REST endpoint; photos to Azure Blob (Azurite locally) |
| Matching | .NET service; PostGIS geo-radius query via EF Core + NetTopologySuite |
| Chat / status / notifications | SignalR hub, shared contract across Flutter & React |
| Push notifications | Firebase Cloud Messaging (FCM); server sends via Firebase Admin SDK |
| Reviews | REST CRUD, triggers SignalR notification + FCM push |
| Scheduling / reminders | Stored job datetime + Hangfire background job → FCM push |
| Admin | Role-gated React views, admin-only REST endpoints |
| Manual payments (P4) | Isolated .NET module (`IPaymentProvider` + `IPaymentService`); homeowner bank transfer + receipt upload, staff review queue, Hangfire expiry |
| Payments — gateway (V1.1) | Same module with a real `IPaymentProvider`, BNZ API integration |

## Address resolution (v1.5)

- `IAddressResolver` is the backend provider seam. `LinzAddressResolver` queries the LINZ Data Service WFS; `AddressResolution:Provider` selects the registered adapter. A future provider adds an implementation and DI registration, not provider-specific HTTP calls in Flutter. Provider retention, privacy and attribution requirements still need review when switching.
- Authenticated `GET /api/addresses/search?query=...` accepts 3–160 characters, up to 12 words, and returns `{provider, attribution, attributionUrl, items: [{id, address, suburb, city, latitude, longitude}]}`. Results are bounded to eight current addresses, with an explicit CRS84 longitude/latitude conversion contract. Errors are safe 503 responses, not fabricated results. Search is rate-limited per authenticated user (30/minute per API instance), with no-store responses, a ten-second upstream timeout and a 1MB response limit.
- LINZ uses a server-only LDS key: `AddressResolution__Linz__ApiKey`; Docker Compose maps local `.env` variable `LINZ_API_KEY` to it. Never commit or print the value. Provider and layer are configurable through `ADDRESS_RESOLUTION_PROVIDER` and `LINZ_ADDRESS_LAYER_ID`; the initial new NZ Addresses layer is configured as 123113, not deprecated 105689. Authenticated schema and representative urban/unit/rural/Māori/no-result checks passed locally; repeat when changing provider/layer or deploying. The user-approved API-only Docker DNS override uses Cloudflare/Google because the local default resolver returned SERVFAIL for LDS. Host DNS is unchanged; do not replace the provider URL with a static IP or bypass TLS.
- WFS filters use XML serialization and literal wildcard escaping. Upstream request logging is disabled because LDS puts keys in the URL path; redirects are disabled, and transport/provider exception details are not returned to clients. Deployment tracing must also redact key-bearing URLs. Search text is sent to LINZ; disclose this in the application's privacy policy.
- Flutter `AddressRepository` / `AddressSearchNotifier` consume only the application API. Typing clears resolved coordinates and hourly-rate selection immediately; debounced searches and nearby-rate requests reject stale responses. Selecting an address supplies internal coordinates without location permission or GPS assumptions. Job pricing, timestamps, posting, matching and SignalR contracts are unchanged.
- Display LINZ source and CC BY 4.0 attribution with results and the selected address. Stored LINZ-derived job coordinates retain their source's reuse obligations. The initial search is token-based and does not claim commercial-geocoder typo correction or abbreviation expansion.

## Manual payment module (P4)

Fixo has no payment gateway at this phase, so the module is built around a
manual bank transfer, but it is shaped as if a gateway existed:

- `IPaymentProvider` (`Services/Payment/`) is the seam. `ManualReceiptProvider`
  is the only implementation; `ProcessRefundAsync` throws because a manual
  transfer can only be reversed by a human. Dropping in a PSP means swapping
  one DI registration — nothing in `IPaymentService` or the job state machine
  changes.
- `IPaymentService` owns the whole flow: issuing instructions, hashing and
  storing the receipt, duplicate detection, the staff queue, and driving job
  transitions through `IJobStatusService` (so every change lands in history and
  reaches both clients over SignalR).
- One `Payment` row per job, reused across re-uploads. A SHA-256 of the receipt
  bytes is unique-indexed, so one bank confirmation cannot back two payments.
- Transfer details come from the `PaymentInstructions` config section, never
  hardcoded, so a white-label partner can point transfers at their own account.
- The job state machine owns the edges: `AwaitingPayment` (money owed) →
  `PaymentReview` (receipt with staff) → `Booked` (verified), with rejection
  returning to `AwaitingPayment`.
- `PaymentExpiryJob` (Hangfire) expires a job whose payment never lands,
  releasing the tradie. It re-reads `Job.PaymentDueAtUtc` rather than trusting
  its own fire time, so a rejection that restarts the window reschedules rather
  than expiring early.

## Database provider swap strategy

The API uses EF Core with `Npgsql.EntityFrameworkCore.PostgreSQL` + `NetTopologySuite` for spatial queries in development. To switch to SQL Server in production:

1. Swap the NuGet package to `Microsoft.EntityFrameworkCore.SqlServer` + `NetTopologySuite`
2. Change the connection string in configuration
3. Re-run migrations (`dotnet ef migrations add` / `dotnet ef database update`)

**Important**: Avoid raw PostGIS SQL. Use EF Core's spatial LINQ methods (e.g., `point.Distance(other)`) which translate correctly to both PostGIS and SQL Server spatial functions via NetTopologySuite.

## Blob storage environments

The API talks to blob storage only through `IBlobStorageService` (`AzureBlobStorageService`), so no code changes when moving between environments — only the `AzureBlob` config section:

```json
{
  "AzureBlob": {
    "ServiceUrl": "http://azurite:10000",
    "ExternalServiceUrl": "http://localhost:10000",
    "AccountName": "devstoreaccount1",
    "AccountKey": "<key>",
    "PhotosContainer": "fixo-photos",
    "CredentialsContainer": "fixo-credentials",
    "PaymentsContainer": "fixo-payments"
  }
}
```

- **Local dev**: Azurite blob service (`docker-compose.yml`, port 10000, well-known `devstoreaccount1` key). Containers are created lazily on first upload. `ExternalServiceUrl` is the host-reachable base rewritten into SAS download URLs (container DNS `azurite:10000` isn't dialable from phones/browsers).
- **Production**: point `ServiceUrl` at `https://<account>.blob.core.windows.net`, supply the account key via secrets (Key Vault / env `AzureBlob__AccountKey`), and omit `ExternalServiceUrl`. Private docs (tradie credentials, payment receipts) are never publicly readable — access is via short-lived service-SAS URLs from `GetReadSasUriAsync`, which Azurite also honors.

## Locale configuration

Locale settings are configuration-driven (not hardcoded to NZ):

```json
{
  "Locale": {
    "DefaultCurrency": "NZD",
    "CurrencySymbol": "$",
    "PhoneCountryCode": "+64",
    "DefaultTimezone": "Pacific/Auckland",
    "DistanceUnit": "km"
  }
}
```

Clients read locale config from `GET /api/config/locale`. All server-side money uses `decimal`. All timestamps stored as UTC; clients localize using the configured timezone.

## Container architecture (local dev)

```
┌─────────────────────────────────────────────┐
│  Docker Compose (OrbStack)                  │
│                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │ postgres │  │ azurite  │  │  redis   │  │
│  │ +PostGIS │  │ (Azure   │  │          │  │
│  │          │  │  Blob)   │  │          │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  │
│       │             │             │         │
│  ┌────┴─────────────┴─────────────┴─────┐  │
│  │           .NET API (api)             │  │
│  │  REST + SignalR + Hangfire + FCM     │  │
│  └────┬─────────────────────────┬───────┘  │
│       │                         │          │
│  ┌────┴─────┐                   │          │
│  │ React    │                   │          │
│  │ (admin)  │                   │          │
│  └──────────┘                   │          │
└─────────────────────────────────┼──────────┘
                                  │
                          ┌───────┴────────┐
                          │ Flutter (host) │
                          │ (mobile app)   │
                          └────────────────┘
```

Flutter runs on the host machine (needs device emulator/simulator), not in a container.

## Why this stack for this product
- .NET/EF Core suits a transactional marketplace (users, jobs, reviews, payments) and has a mature auth story.
- One Flutter app with role-based views avoids duplicating mobile UI across separate homeowner/tradie apps.
- React web is scoped to admin only for MVP — avoids building duplicate homeowner/tradie UIs on web.
- SignalR as the single real-time layer avoids running two real-time systems side by side.
- PostgreSQL + PostGIS is free, Docker-friendly, and handles geo queries natively; EF Core provider swap to SQL Server keeps production options open.
- Firebase Cloud Messaging ensures tradies receive notifications even when the app is backgrounded — critical for response rate.
