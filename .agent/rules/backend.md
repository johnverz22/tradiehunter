# Backend Rules (.NET 10)

Architectural standards and implementation rules for the Fixo .NET backend.

## Architectural Pattern: Clean Architecture / N-Tier

The backend follows Clean Architecture / N-Tier separation to guarantee decoupled domain logic, testability, and infrastructure swappability.

| Layer | Component | Responsibilities | Dependencies & Constraints |
| :--- | :--- | :--- | :--- |
| **API Layer** | Presentation / Web API | HTTP routing, controller endpoints, request/response DTO contracts, input validation (`FluentValidation`), SignalR Hubs, and auth filters. | Depends on **Service Layer** interfaces. **PROHIBITED**: Direct EF Core `DbContext` access, raw SQL/spatial queries, or embedded business logic. |
| **Service Layer** | Application / Domain | Core business logic (trade matching engine, job status state machine transitions, dispatch rules, rating calculations). | Pure business logic and domain entities. Depends on **Repository & Infrastructure interfaces**. Completely decoupled from ASP.NET Core Web runtime. |
| **Infrastructure Layer** | Data Access & External Services | EF Core persistence (`DbContext`), repository implementations, spatial queries (PostGIS), Redis cache/backplane, MinIO (S3) blob client, Firebase Admin SDK (FCM), and Hangfire job workers. | Implements interfaces declared by the Service/Domain layer. Depends on external SDKs (`Npgsql`, `NetTopologySuite`, `AWSSDK.S3`, `StackExchange.Redis`, `FirebaseAdmin`). |

## Architecture & Code Rules

1. **Controller Purity**:
   - Controllers must be thin: parse input, invoke service interfaces, map results to DTOs, and return standard HTTP action results.
   - Do not invoke database contexts or execute queries directly in controllers.
2. **Interface-Driven Design & Dependency Injection**:
   - Every service and repository must be backed by an interface (e.g., `IJobService`, `ITradieRepository`, `IBlobStorageService`).
   - Register all dependencies with standard ASP.NET Core DI (`IServiceCollection`) with appropriate lifetimes (`Scoped` for DbContext/services, `Singleton` for Redis/S3 clients).
3. **Centralized Error Handling**:
   - Use reusable global exception middleware (RFC 7807 Problem Details).
   - Never catch exceptions in controllers merely to re-wrap them in generic 500 error objects. Let known domain exceptions map to appropriate HTTP status codes (e.g., `NotFoundException` -> 404, `ValidationException` -> 400).
4. **State Transitions & Real-Time Sync**:
   - Every job status change must pass through the domain service and immediately broadcast via SignalR hubs so mobile and web clients remain synchronized. Never alter status via isolated REST updates without hub event dispatch.
5. **Modular Boundaries**:
   - Keep the future payments module isolated behind dedicated interfaces/modules. Do not tightly couple core matching or job services to payment provider logic.

## Data, Storage & Precision Rules

- **Database & Spatial Queries**:
  - PostgreSQL + PostGIS in local development via `Npgsql.EntityFrameworkCore.PostgreSQL`.
  - Must use EF Core spatial LINQ with `NetTopologySuite` for geographic queries (e.g., radius matching). **NEVER** write raw vendor-specific PostGIS SQL, preserving production compatibility with SQL Server.
- **Financial Precision**:
  - Money and pricing values must always use `decimal` in C# and numeric/decimal in the database. Never use `float` or `double`.
- **Temporal Precision**:
  - All timestamps stored as UTC in the database (`DateTime` with `DateTimeKind.Utc`). Timezone localization occurs strictly at the client level based on configuration.
- **Locale & Configuration**:
  - Currency symbols, phone number formatting, and regional settings must be configuration-driven (see `Locale` in `docs/ARCHITECTURE.md`).
- **Blob Storage**:
  - Use the AWS SDK S3 client targeting S3-compatible APIs (MinIO locally, AWS S3/Azure Blob in production).
- **Background Jobs**:
  - Use Hangfire backed by Redis storage for scheduled reminders, time-based quote expirations, and background cleanups. Do not use inline `Task.Delay` or unmanaged threads.
- **Authentication**:
  - ASP.NET Identity issuing JWTs consumed by both Flutter mobile and React web clients.
- **Local Dev Runtime**:
  - Runs in Docker via `docker compose up`. API container exposes port `5000`. Adhere strictly to `docs/MVP-SPEC.md` Tier 1/2/3 scope.

## Tooling & Command Execution
- **Dotnet CLI Execution:** The `dotnet` CLI tool is **NOT** installed on the host machine (macOS). Local dev runs on OrbStack / Docker Compose. You must ALWAYS execute `dotnet` commands (e.g., `dotnet add package`, `dotnet ef migrations add`, `dotnet test`) inside the API container using `docker compose run`.
  - To run dotnet commands reliably without interfering with the `watch` entrypoint, use the following pattern: `docker compose run --rm --entrypoint /bin/bash api -c "dotnet <command>"` (Note: you need to use `BypassSandbox: true` when running `docker compose`).
  - NEVER try `dotnet` directly on the host, `cd backend && dotnet ...`, or `docker compose exec` against a stopped container. If the `api` service image is stale, rebuild it first (`docker compose build api`).
