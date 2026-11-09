# Fixo — MVP Scoping & UX Blueprint

> Development brand: **Fixo**. White-label ready — brand identity is driven by `--hue` CSS variable (default 209, blueprint blue).

## Feature prioritization (tiered)

### Tier 1 — Core Loop (Must ship first)
| Feature | Note |
|---|---|
| Registration/login (email + Google) | ASP.NET Identity + OAuth; JWT for Flutter & React |
| Job posting (category, description, photo, urgency, location) | Photos via S3-compatible storage (MinIO locally) |
| Rule-based matching (trade + radius + availability) | No ML in MVP; PostGIS geo queries |
| Match notification → accept/decline | SignalR push to tradie; minimum-effort response |
| In-app chat (SignalR) | Shared hub for Flutter & React |
| Job status stepper (Requested → Matched → Confirmed → Complete) | State machine drives UX; transitions via SignalR |
| Firebase Cloud Messaging | Background push for match notifications, reminders |

### Tier 2 — Trust & Quality (Ship for demo quality)
| Feature | Note |
|---|---|
| Tradie profile (rating, badge, review count, trade, distance) | Trust signal for homeowners |
| Post-job rating & review | Closes the accountability loop |
| Scheduling + Hangfire reminders | Formalizes time coordination beyond chat |

### Tier 3 — Operational (Ship before real users)
| Feature | Note |
|---|---|
| Admin dashboard (React, admin-only web app) | User list, job list, disputes, verify/deactivate |

### Should-Have (V1.1)
- Secure in-app payments (BNZ API integration) — isolated payments module
- Transparent pricing engine (rate cards by skill/location)
- Job board / browse-and-apply view
- Favorites and repeat-tradie booking
- Calendar sync (Google/Outlook)
- Automated cancellation/refund rules engine

### Could-Have
- Facebook/Apple login (additional OAuth providers)
- Portfolio/photo galleries (Houzz-style)
- ML-based match ranking

### Won't-Have (MVP)
- Cash pool / advanced reconciliation
- Automated dispute resolution (handle manually via admin dashboard)
- Loyalty/referral system

## Platform strategy

| Platform | Role | Notes |
|----------|------|-------|
| **Flutter (mobile)** | Primary client — homeowner & tradie | Single app, role-based views post-login |
| **React (web)** | Admin dashboard only | Role-gated, admin-only endpoints |
| **.NET API** | Shared backend | REST + SignalR, consumed by both clients |

## Core MVP user flow (Homeowner — mobile)
1. **Splash/Onboarding** — Fixo branding, value prop, sign-up prompt
2. **Auth** — sign up via email/Google → JWT issued → role selected
3. **Post a need** — category, description, photo, urgency, location → `POST /api/jobs`
4. **Matching** — backend queries available tradies within radius → FCM push + SignalR notification to eligible tradies
5. **Confirmation ("Aha!" moment)** — tradie accepts → chat opens → time confirmed → both get status-update push
6. **Job day** — FCM push reminder
7. **Completion** — homeowner marks complete → rating modal → `POST` review

The "Aha!" moment is step 5: the gap between posting a need and getting a confirmed, named, rated human committed to a time — should take minutes, not days.

## Screen architecture

### Mobile (Flutter) — homeowner & tradie
| Screen | Role | Key components |
|---|---|---|
| Splash / Onboarding | All | Fixo branding, value prop slides |
| Auth | All | Email/Google login, role selector |
| Home (Homeowner) | Homeowner | Active jobs list, "Post a Job" FAB, status cards |
| Post a Job | Homeowner | Category picker, description, photo upload, urgency toggle, location |
| Matching / Waiting | Homeowner | Loading state while matching runs |
| Match Result | Homeowner | Tradie card (rating, badge, distance), request button |
| Home (Tradie) | Tradie | Incoming requests queue, active jobs, summary stats |
| Incoming Request | Tradie | Job card detail, accept/decline, distance/urgency |
| Chat + Job Status | Homeowner, Tradie | SignalR message thread + status stepper |
| Profile | Homeowner, Tradie | Rating, reviews, verification badge, edit details |
| Rating/Review | Homeowner, Tradie | Star input, comment field (modal or screen) |

### Web (React) — admin only
| Screen | Key components |
|---|---|
| Admin Login | Email login, admin role check |
| Admin Dashboard | User list, job list + status, flagged disputes, verify/deactivate |

## Technical decisions

| Decision | Choice | Rationale |
|----------|--------|----------|
| Database | PostgreSQL + PostGIS (dev), SQL Server option for prod | EF Core provider swap; PostGIS free & Docker-friendly |
| Photo storage | S3-compatible (MinIO locally, cloud S3/Azure Blob in prod) | Decoupled from DB; standard S3 SDK |
| Push notifications | Firebase Cloud Messaging | Background push critical for tradie response rate |
| Locale | Configuration-driven (currency, phone format, address) | Defaults to NZ (NZD, +64) but swappable per deployment |
| Real-time | SignalR (single hub for chat, status, match notifications) | Shared by Flutter & React; avoids dual real-time systems |

## Success metrics
- **Activation rate** — % of homeowners posting a job within 24h of signup
- **Match-to-confirmation time** — median time from job posted to SignalR-confirmed schedule
- **Tradie response rate** — % of pushed match notifications accepted/declined within X minutes
- **Review completion rate** — % of completed jobs rated by both parties
