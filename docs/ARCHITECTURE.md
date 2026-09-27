# Fixo — Architecture

## Stack
- **Backend**: .NET 10 (ASP.NET Core Web API) — single source of truth for both Flutter and React clients. REST for CRUD, SignalR for real-time.
- **Mobile**: Flutter — single app, role-based UI (homeowner/tradie), primary client for the MVP. Consumes REST + SignalR + receives FCM push.
- **Web**: React — admin dashboard only for MVP. Role-gated to admin endpoints.
- **Real-time**: SignalR hubs for (1) chat messages, (2) job-status transitions, (3) match notifications. Both Flutter and React connect to the same hub endpoints.
- **Push**: Firebase Cloud Messaging — background push for match notifications, status changes, reminders. Critical for tradie response rate.
- **Database**: PostgreSQL 16 + PostGIS for geo queries (dev). EF Core with Npgsql provider; swappable to SQL Server (`Microsoft.EntityFrameworkCore.SqlServer`) for production via configuration.
- **Blob storage**: S3-compatible — MinIO locally, swappable to AWS S3 or Azure Blob Storage in production.
- **Cache / backplane**: Redis — SignalR backplane for scale-out, Hangfire job storage.
- **Scheduling**: Hangfire with Redis storage for background jobs (reminders, notifications).
- **Local dev**: Docker Compose on OrbStack.

## Feature-to-tech mapping

| Feature | Tech |
|---|---|
| Auth | ASP.NET Identity + OAuth (Google); JWT issued to Flutter & React |
| Job posting | REST endpoint; photos to S3-compatible storage (MinIO locally) |
| Matching | .NET service; PostGIS geo-radius query via EF Core + NetTopologySuite |
| Chat / status / notifications | SignalR hub, shared contract across Flutter & React |
| Push notifications | Firebase Cloud Messaging (FCM); server sends via Firebase Admin SDK |
| Reviews | REST CRUD, triggers SignalR notification + FCM push |
| Scheduling / reminders | Stored job datetime + Hangfire background job → FCM push |
| Admin | Role-gated React views, admin-only REST endpoints |
| Payments (V1.1) | Isolated .NET module, BNZ API integration, kept separate from core API |

## Database provider swap strategy

The API uses EF Core with `Npgsql.EntityFrameworkCore.PostgreSQL` + `NetTopologySuite` for spatial queries in development. To switch to SQL Server in production:

1. Swap the NuGet package to `Microsoft.EntityFrameworkCore.SqlServer` + `NetTopologySuite`
2. Change the connection string in configuration
3. Re-run migrations (`dotnet ef migrations add` / `dotnet ef database update`)

**Important**: Avoid raw PostGIS SQL. Use EF Core's spatial LINQ methods (e.g., `point.Distance(other)`) which translate correctly to both PostGIS and SQL Server spatial functions via NetTopologySuite.

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
│  │ postgres │  │  minio   │  │  redis   │  │
│  │ +PostGIS │  │ (S3 API) │  │          │  │
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
