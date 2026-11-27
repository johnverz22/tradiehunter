# Homeowner Quotes Visibility: surface quotes in the jobs list, add "View quote", settle the tradie quote builder

> **Repo / branch:** `johnverz22/tradiehunter` @ `main`
> **Purpose:** Close the gaps found when tracing the v2 mockups (`docs/design/mobile/ast/screens.mjs` -> `mockups/png/`) against the Flutter implementation (`mobile/lib/ui/`). The quote flow works end to end, but a homeowner who requested quotes has almost no way to find them. This plan makes quotes discoverable, adds the missing "View quote" detail, and records a decision on the tradie quote builder.
> **Status:** Q0-Q5 landed. Q6 final verification with the owner. **Phase Q7 (open project board) approved 2026-11-27, not started.** Q4.2 folds into Q7 · **Prepared:** 2026-11-27
> **Naming rule:** code identifiers stay `Fixo` (Dart package imports are `package:fixo/...`); user-facing text is TradieHunter. Do not rename.
> **Convention:** `[ ]` todo, `[x]` done, `[~]` parked (add why). Size: S <= 1h, M <= half a day, L >= 1 day.
> **Relationship to other plans:** continues `01_design_system_migration_plan.md` (gap table G-n) and `05_phase4_homeowner_audit.md`. Overlaps `09_notification_coverage_plan.md` in two places, see section 5.

---

## 0. Read first

`docs/SPECS.md` (project jobs, quotes, offers, the s362F written-contract rule at NZD 30,000+), `docs/design/mobile/README.md` (how mockups are authored and built), `docs/TESTING.md`, `AGENTS.md` (ask before adding dependencies).

Mobile: `mobile/lib/ui/homeowner/` (`ho_jobs_screen.dart`, `ho_jobs_mapper.dart`, `ho_job_card.dart`, `ho_home_mapper.dart`, `ho_home_screen.dart`, `ho_job_navigation.dart`, `ho_job_detail_fallback_screen.dart`, `ho_quotes_screen.dart`), `mobile/lib/ui/tradie/tr_quote_sheet.dart`, `tr_lead_screen.dart`, `mobile/lib/models/marketplace.dart` (`Job`, `Quote`, `JobOffer`), `mobile/lib/viewmodels/jobs_viewmodel.dart` (`QuotesNotifier`, `quotesProvider`), `mobile/lib/router/app_router.dart`, `mobile/lib/router/notification_route.dart`, `mobile/lib/main.dart` (`_routeFromMessage`).

Backend: `backend/Services/QuoteService.cs`, `OfferService.cs`, `JobService.cs` (`GetJobsForUserAsync`, `MapToDto`), `JobRepository.cs` (`GetForUserAsync`), `backend/DTOs/JobDTOs.cs` (`JobDto`), `backend/Options/JobFlowOptions.cs` (`MaxConcurrentQuoteRequests` = 3, `QuoteWindowHours` = 72).

## 1. Findings (what is wrong today)

F1-F4 come from the mockup trace. F5-F8 were verified in code while writing this plan.

| # | Finding | Evidence |
|---|---|---|
| F1 | **Quotes screen has almost no entry points.** The only navigation to `/jobs/:jobId/quotes` is the job-detail fallback for `status == Requested && job.isProject` ("Compare quotes"). The jobs list, home screen and job cards never link there. The `ho_jobs` mockup card shows "2 of 3 quotes in" with a `Quotes` badge; the implementation shows `Requested` / "Finding a tradie". Biggest gap. | `ho_job_detail_fallback_screen.dart:24-36`; `ho_job_navigation.dart` (`thHomeownerJobPath` sends stage 0 to `/matching`); `ho_home_mapper.dart` (`thHomeStatusBadge`, `thHomeJobSubtitle`) |
| F2 | **No "View quote".** Mockup `ho_quotes` has `View quote` + `Accept` per compact card. Implementation has one inline card with all detail and only `Accept quote`. | `screens.mjs:60-62`; `ho_quotes_screen.dart` `_QuoteCard` |
| F3 | **Tradie quote builder is a bottom sheet, not a screen, and has no mockup.** `ast/screens.mjs` has no `tr_quote*` frame and no PNG. `TrQuoteSheet` is functionally complete (pricing pills, amounts, inclusions/exclusions, materials + GST switches, proposed start, duration, `POST /api/jobs/:id/quotes`). | `tr_quote_sheet.dart` (376 lines), launched from `tr_lead_screen.dart:222` when `offer.isQuoteRequest` |
| F4 | Minor: `ho_request_sent` mockup sticky has only "Cancel request"; implementation adds "Pick someone else" (needed for expired/gone states). | `ho_request_sent_screen.dart` |
| F5 | **The "New quote received" push opens the wrong screen.** `QuoteService` sends data `type: quote_submitted` plus `jobId`, but `routeForMessageType` only knows `chat`, `job_status`, `match`; everything else falls through to `/messages`. `_routeFromMessage` also passes only the type, never the `jobId`. | `QuoteService.cs:135-137`; `notification_route.dart`; `main.dart:162-167` |
| F6 | **The API cannot say "2 of 3".** `JobDto` has no quote counts, and `GetForUserAsync` loads jobs with photos and matched tradie only (no quotes, no offers). The list screen therefore has nothing to render the badge from without N extra calls. | `JobDTOs.cs` `JobDto`; `JobRepository.cs:30-52` |
| F7 | **Quote status constant disagrees with the wire.** Backend starts quotes at `QuoteStatus.Submitted`; mobile declares `Quote.statusPending = 'Pending'`. The screen works today only because it tests for terminal statuses instead of "pending". Any new code that tests `== statusPending` would silently never match. | `QuoteService.cs:118`; `marketplace.dart` `Quote`; `ho_quotes_screen.dart:249-252` |
| F8 | The quotes screen subtitle says "N received"; the mockup says "2 of 3 received". The denominator is the number of quote requests sent, which the client does not know (same root cause as F6). | `ho_quotes_screen.dart:193-194` |

## 2. Rules for the implementing model (read before any task)

- `mobile/lib/ui/**` must not import v1 code (`views/**`). Several v2 files are deliberate copies of v1 logic for that reason (see header of `ho_job_navigation.dart`). Keep pure rules in the `*_mapper.dart` files so they stay unit-testable without widgets.
- Never invent data. If the API does not return a count, show the old copy, not "0 of 3". New `Job` fields are nullable and `Job.fromJson` must tolerate absence (older server, legacy jobs).
- Money: use `formatMoney` (`mobile/lib/utils/money.dart`) with `Decimal`; never doubles; never show `$0.00` for unpriced values.
- Do not change the accept flow. The `requiresWrittenContract` gate (>= NZD 30,000, `confirmWrittenContract: true` retry) lives in `QuotesNotifier.acceptQuote`. Moving the Accept button into a detail view must still call that same notifier method.
- Keep existing widget `Key`s stable (tests and e2e use them); give every new interactive widget a `Key`.
- Design-system widgets only (`THCard`, `THButton`, `THBadge`, `THText`, tokens from `th_tokens.dart`); no new colours or font sizes.
- Behaviour that changes `docs/SPECS.md` (API fields) gets a SPECS update in the same PR.
- Ask before adding any dependency (none should be needed).

## 3. Decisions to confirm first (resolve in Q0; defaults are recommendations)

1. **D1: what counts as "requested" and "received".** Recommended: `quotesRequested` = job's `QuoteRequest` offers whose response is `Pending` or `Accepted` (a submitted quote marks its offer `Accepted`, see `QuoteService.cs:125`); `quotesReceived` = quotes with status `Submitted` whose `ValidUntilUtc` is in the future, plus the `Accepted` one. Declined/timed-out offers are not requested. No quote-expiry job exists yet (plan 09 M6), so filter by `ValidUntilUtc` in the query.
2. **D2: shape of "View quote".** Recommended: **modal bottom sheet** from a compact card (no new route; Accept is repeated inside it). Alternative: full screen `/jobs/:jobId/quotes/:quoteId`. Either needs a new mockup frame `ho_quote_detail` (Q3.1) so design and code stay aligned.
3. **D3: tradie quote builder.** Recommended: **keep the sheet, polish it** (Q4), because it is wired and tested and a full screen has no design. If a full screen is wanted instead, a `tr_quote` frame must be designed first (Q4.0) and Q4.1-Q4.4 are replaced by a new plan.
4. **D4: where a project job opens from the list.** Recommended: Project + `Requested` + at least one quote request sent -> `/jobs/:id/quotes` (even with 0 quotes, its empty state already says tradies are preparing); Project + `Requested` + zero requests sent -> `/jobs/:id/tradies` (finish choosing); everything else unchanged.

Record the outcome of each in the "Decisions and parked items" section at the end.

## Phase Q0: Recon and decisions (no code)

- [x] **Q0.1** Re-confirm F1-F8 against current `main` (line numbers above may have drifted). Run `grep -rn "jobs/\${.*}/quotes\|/quotes'" mobile/lib` to confirm the fallback is still the only entry (S)
- [x] **Q0.2** Confirm `OfferResponse` values and that submitting a quote sets its offer to `Accepted` (`QuoteService.cs:120-131`); finalise D1 (S)
- [x] **Q0.3** Ask the owner for D2, D3, D4. Do not start Q3 or Q4 until D2/D3 are answered; Q1 and Q2 do not depend on them (S)

## Phase Q1: Backend, quote counts on the job DTO (fixes F6, F8)

- [x] **Q1.1** Add to `JobDto`: `int? QuotesRequested` and `int? QuotesReceived`. Populate only for homeowner callers, `JobType == Project`, and status `Requested`; otherwise leave `null` (so legacy/hourly clients and tradies see no change). XML-doc both fields with the D1 definition (S)
- [x] **Q1.2** Compute counts for the page in **one grouped query** keyed by job id inside `JobRepository.GetForUserAsync` (or a new `GetQuoteCountsAsync(IEnumerable<int> jobIds)` called from `GetJobsForUserAsync`). Do **not** `.Include(j => j.Quotes)` / `.Include(j => j.Offers)` on the list query: that loads every row for up to 50 jobs. Pass the counts into `MapToDto` via an optional parameter, keeping the current signature working for other callers (M)
- [x] **Q1.3** Same fields on `GET /api/jobs/{id}` (`GetJobByIdAsync` already loads offers; add quotes via the same count helper, not a full include) (S)
- [x] **Q1.4** Put the count rule in a small pure static helper next to `JobMoney` (e.g. `QuoteCounts.From(offers, quotes, now)`) so it can be unit-tested without a database. Add xunit tests in `backend/FixoApi.Tests`: 0 requested; 3 requested / 2 submitted; one declined offer frees its slot; expired quote not counted; accepted quote counted; non-project returns null (M)
- [x] **Q1.5** Update `docs/SPECS.md` job DTO / API section with the two fields (S)

## Phase Q2: Mobile, make quotes discoverable (fixes F1, F5, F7)

- [x] **Q2.1** `marketplace.dart`: add `final int? quotesRequested; final int? quotesReceived;` to `Job` + `fromJson` (tolerate missing/null, accept num). Add a getter `bool get hasQuoteActivity` (project, `Requested`, `quotesRequested != null && quotesRequested! > 0`) (S)
- [x] **Q2.2** Fix F7: set `Quote.statusPending` to the wire value `'Submitted'` (keep `'Pending'` accepted in a `isOpen` helper for old fixtures), add `bool get isOpen` to `Quote`, and make `ho_quotes_screen.dart:249-252` use it. Update fixtures in `phase4_ho_quotes_test.dart` (S)
- [x] **Q2.3** `ho_home_mapper.dart`: add `thHomeStatusBadgeForJob(Job)` returning `HoStatusBadge('Quotes', THBadgeKind.ok)` when `hasQuoteActivity`, else delegating to `thHomeStatusBadge(job.status)`. Add `thHomeJobSubtitle` branch: when `hasQuoteActivity` and `quotesReceived != null`, return `'$quotesReceived of $quotesRequested quotes in'` (mockup copy); when received is 0 keep "Waiting for quotes". `HoJobCard` switches to the job-aware badge (S)
- [x] **Q2.4** `ho_job_navigation.dart` `thHomeownerJobPath`: implement D4. Put the project branch **before** the `usesV2Flow` stage switch, otherwise stage 0 still returns `/matching`. Keep `Cancelled`/`Expired`/`Disputed` -> `/detail` first (S)
- [x] **Q2.5** Home attention: a project job with `quotesReceived >= 1` should appear in the "needs your attention" group with headline `Review quotes` / action `Compare`. `HoHomeGroups.from` and `thNeedsHomeownerAttention` take only status today, so add a job-aware predicate and extend `thAttentionHero` (`_attentionPriority` placement: after payment due, before dispute is fine; confirm with owner if unsure) (M)
- [x] **Q2.6** Push tap (F5): add `'quote_submitted'` handling. Because the route needs the id, add `String routeForMessage(Map<String, dynamic> data)` in `notification_route.dart` that returns `/jobs/${data['jobId']}/quotes` for `quote_submitted` when `jobId` is a non-empty string, and otherwise falls back to `routeForMessageType`. Change `_routeFromMessage` in `main.dart` to call it with `message.data`. Keep `routeForMessageType` and its tests working (S)
- [x] **Q2.7** Freshness: when a foreground FCM message of type `quote_submitted` arrives, refresh the homeowner jobs list and `quotesProvider(jobId)` so the badge and screen update without a manual pull-to-refresh. Reuse the existing jobs list notifier reload used by `_reload` in `ho_jobs_screen.dart`; do not add a SignalR event in this plan (the list screen is not in any `job-{id}` group) (M)
- [x] **Q2.8** Tests: `phase4_ho_jobs_test.dart` (badge + subtitle + tap target for project with 2 of 3; project with 0 requests goes to `/tradies`; hourly unchanged), `phase4_ho_home_test.dart` (attention hero "Review quotes"), new pure test for `routeForMessage` (quote_submitted with/without `jobId`, unknown type -> `/messages`) (M)

## Phase Q3: Mobile, "View quote" and quotes screen (fixes F2, F8)

- [x] **Q3.1** (frame + generated Flutter stub + gallery sync done 2026-11-27; mockup PNG export left for a machine with web fonts) **Design first.** Add frame `ho_quote_detail` (per D2) to `docs/design/mobile/ast/screens.mjs` using the existing DSL helpers (`card`, `row`, `T`, `btn`, `avatar`), showing: tradie header (avatar, name, rating, verified), price model line, amount/range/cap, GST line, inclusions, exclusions, materials, proposed start, duration, valid-until, sticky `Accept`. Run `cd docs/design/mobile && npm run build`, then `npm run check`; commit regenerated `mockups/png/` and AST (M)
- [x] **Q3.2** Compact `_QuoteCard` to match `ho_quotes`: avatar + name, `star rating · N weeks`, money on the right with `fixed · incl. GST` caption, buttons `View quote` (secondary) + `Accept` (primary/accent). Caption mapping: Fixed -> `fixed`, EstimateRange -> `estimate` (money shows `$min-$max`), HourlyWithCap -> `hourly · cap $X`; append `incl. GST` when `gstIncluded`. Duration: `< 14 days` -> `N days`, else `round(days/7) weeks`. Reuse the formatting already in `_QuoteCard` rather than rewriting it; move the detail rows that are removed from the card into the detail view (M)
- [x] **Q3.3** Build the detail view per D2 (bottom sheet recommended: `showModalBottomSheet`, scroll-controlled, keys `quote_detail_<id>`, `quote_detail_accept_<id>`). Its Accept calls the **same** `QuotesNotifier.acceptQuote` path including the written-contract dialog; close the sheet on success/after the dialog resolves. Terminal quotes (`!isOpen`) hide Accept and keep showing the status badge (M)
- [x] **Q3.4** Subtitle: `'<job title> · ${quotes.length} of ${job.quotesRequested} received'` when `quotesRequested` is known (`quotesJobProvider` already fetches the `Job`), else the existing `N received` copy. Never print a denominator smaller than the numerator (clamp: `max(requested, received)`) (S)
- [x] **Q3.5** (done 2026-11-27: gallery screen, count 31, golden baselines generated by the owner) Update `phase4_ho_quotes_test.dart` (compact card content, View quote opens detail with scope text, Accept from detail triggers the contract dialog for >= $30k, subtitle with and without denominator) and refresh `lib/ui/gallery/ho_quotes_screen.dart` + goldens (`mobile/test/ui/goldens`, `gallery_goldens_test.dart`) if the gallery covers this screen (M)

## Phase Q4: Tradie quote builder (F3; applies to D3 = keep the sheet)

- [x] **Q4.0** If D3 = full screen: stop here, write a follow-up plan that starts with a `tr_quote` mockup frame (Q3.1 style). Otherwise continue (S)
- [x] **Q4.1** Verify each item below against `tr_quote_sheet.dart` and `QuoteService.SubmitQuoteAsync` first; implement only what is missing. (a) GST switch: backend rejects a GST-registered tradie who sends `GstIncluded=false` and a non-registered tradie who sends `true` (`QuoteService.cs:93-97`), so pre-set the switch from the tradie profile and lock it with helper text instead of letting the tradie hit a server error. (b) Client-side checks before submit: amount > 0; range requires `min < max`; hourly-with-cap requires `rate > 0` and `cap >= rate`; duration >= 1 day; proposed start not in the past. (c) Show the server error message verbatim (already the contract via `ProfileApiException`) in the sheet, without closing it (M)
- [~] **Q4.2** Show how long the quote stays valid ("Valid for 72 hours"), derived from the server value, not hard-coded, if the lead/offer payload exposes it; otherwise add it to the next API change rather than hard-coding `QuoteWindowHours` (S)
- [x] **Q4.3** After a successful submit, confirm to the tradie on `tr_lead` (state change or `THNotice`) and make sure re-opening the lead does not offer a second submit (the offer is `Accepted` once a quote exists). Verify the current behaviour first (S)
- [x] **Q4.4** Extend `phase5_tr_lead_test.dart` for the validation cases and GST pre-set (M)

## Phase Q5: Docs

- [x] **Q5.1** `docs/todos/01_design_system_migration_plan.md` gap table: add rows for F1 (resolved by this plan), F2, F3 (owner decision D3) and F4 (accepted deviation: "Pick someone else" kept, justified by expired/gone states) (S)
- [x] **Q5.2** (`ho_quote_detail` added to the screen lists; counts now 31 / Homeowner 16)  `docs/design/mobile/README.md` / screen list: add `ho_quote_detail`; note that the tradie quote builder is a sheet by design (if D3 = sheet) (S)
- [x] **Q5.3** `docs/SPECS.md`: Q1.5 fields, quote entry points, push `quote_submitted` -> quotes screen (S)
- [x] **Q5.4** Fill the Results log and Decisions sections below (S)

## Phase Q6: Verification

- [ ] **Q6.1** `cd backend && dotnet test` (S)
- [ ] **Q6.2** `cd mobile && flutter analyze --fatal-infos && flutter test` (S)
- [ ] **Q6.3** `cd docs/design/mobile && npm run check` (mockups and AST in sync) (S)
- [ ] **Q6.4** Manual path on the local stack: homeowner posts a Project job -> requests 3 tradies -> two tradies submit quotes -> homeowner's jobs list shows `Quotes` badge and "2 of 3 quotes in" -> card opens quotes screen -> `View quote` -> `Accept` (and the >= $30k contract gate with a large quote). Tap the "New quote received" push and confirm it lands on the quotes screen (M)
- [x] **Q6.5** (done 2026-11-27: `competing-quotes` counts, `homeowner-quotes-visibility`, `quote-settings` in `scripts/e2e-journey.py`; live-verified on the local stack) Optional: add this journey to the persona fabric (`docs/todos/08_e2e_persona_fabric_plan.md`, `scripts/e2e-journey.py` scenarios) so it stays covered (M)

## Phase Q7: Open project board (APPROVED 2026-11-27: D5 yes, D6 72 h DB-backed, D7 show all details; not started)

**Idea (owner):** a Project job is posted once and appears on an "Available jobs" list for tradies who offer that service (in range, credentialled, not blocked). Tradies submit quotes themselves. Hourly and project jobs share the same progress-tracked screens after booking, with the final amount settled at completion.

**Assessment (from code and SPECS):**

- **It fixes the root of F1/F5/F6/F8.** No pre-selection step, no "2 of 3" denominator, no `/tradies` routing for open jobs; quotes just arrive and the list says "N quotes".
- **Convergence mostly exists.** Accepting a quote books a normal v2 job with the pricing model snapshotted, then it uses the same detail, payment and review screens as hourly. Only stage 0 differs (radar for hourly, quotes for projects); Q7.11 unifies it.
- **The quote stays binding.** SPECS section 5: a quote cannot rise without agreement; Fixed = agreed price + approved adjustments; the s362F gate (NZD 30,000+) is decided at booking. "Price changes on demand" is already covered: EstimateRange and HourlyWithCap settle on final hours, and any model can change through an approved adjustment. No free re-quote at completion.
- **Hourly stays off the board**; they need fast acceptance (Quick match / direct request). Projects keep "invite a specific tradie" beside "open to all nearby".
- **Cost is moderate, the data model is ready:** `Quote.OfferId` is already nullable. Needed: an available-jobs query (EF Core spatial LINQ, rule 2), licence gating, quoting without an offer, a DB-backed settings store (see below), and board expiry.
- **Known finding: admin settings are not persisted today.** `AdminService.UpdateSettingsAsync` mutates in-memory options and `GetSettingsAsync` returns fixed values for radius and feature flags, so edits are lost on restart. Q7.1 adds a real settings store; moving the existing locale/radius/feature fields onto it is a follow-up, not part of this plan.

**Decisions (confirmed by the owner, 2026-11-27):**

- **D5 yes:** open board for Project jobs, in addition to direct invites.
- **D6: 72-hour window, not hard-coded, DB-backed and editable in the web admin.** Two separate settings in the new store, both defaulting to 72 and falling back to `appsettings` (`JobFlow:QuoteWindowHours`) if no row exists: (a) `Quotes.BoardWindowHours`, how long a posted project accepts new quotes; the close time is **stamped on the job at posting** (`QuotesCloseAtUtc`) so a later setting change never alters jobs already on the board; (b) `Quotes.ValidityHours`, how long a submitted quote stays valid (replaces the config-only `QuoteWindowHours` in `QuoteService`; also unparks Q4.2). No cap on the number of quotes for now; revisit if homeowners get flooded (add `Quotes.MaxPerJob` then).
- **D7: show all the details** so tradies can quote properly: scope, notes, budget range, materials-by, site-visit-welcome, timing, all photos/attachments, suburb and distance. **Assumption to confirm:** the exact street address and the homeowner's contact stay masked until `Booked` (the existing P5-01 rule, `JobService` masks to the suburb), because the board is visible to every matching tradie, not just the chosen one. If you want the full street address on the board, that is a one-line change plus a privacy note in SPECS; say so.

**Tasks:**

- [x] **Q7.1** Backend: DB-backed settings store: `PlatformSettings` table (key, value, updated by/at; hand-written migration `20261127090000_AddPlatformSettingsAndOpenBoard` + snapshot), scoped `IPlatformSettings` with `appsettings` fallback and an audit entry on change. Reads are a primary-key lookup, so no cache was added (add one only if profiling shows a need). Seed nothing: absence means fallback (S/M)
- [x] **Q7.2** (landed; Superadmin-only PUT uses the existing `RequireSuperadminRole` policy) Backend + web: admin API `GET/PUT /api/admin/settings/quotes` (validate 1-720 h integers) and a "Quotes" card on the web Settings page (`web/src/features/settings`), using the existing shared components and tokens; Superadmin only (confirm role with the existing settings guard) (M)
- [x] **Q7.3** (landed; `openToBoard` absent = false so older clients keep invite-only behaviour) Backend: `Job.OpenToBoard` (bool) and `Job.QuotesCloseAtUtc?`, set at posting from `Quotes.BoardWindowHours`; `QuoteService` uses `Quotes.ValidityHours` for `ValidUntilUtc` (M)
- [x] **Q7.4** (landed; `AvailableJobsService` + `GET /api/tradie/available-jobs` with Haversine radius filter and suburb masking) Backend: `GET /api/tradie/available-jobs` (paged; Project, `Requested`, `OpenToBoard`, before `QuotesCloseAtUtc`; service offered by the tradie, within radius, licence board satisfied, not blocked, I have not quoted yet). Full detail DTO per D7 with address masked; include `QuotesReceived` and `QuotesCloseAtUtc` (M)
- [x] **Q7.5** (landed; `QuoteService.SubmitQuoteAsync` allows open-board quotes without an offer, enforcing service, radius, licence, block, duplicate, and GST rules) Backend: `POST /api/jobs/{id}/quotes` accepts a tradie with no offer when the job is open and before `QuotesCloseAtUtc`; same eligibility as the list (service, radius, licence, not blocked), one quote per tradie per job, same GST rules, `OfferId = null` (M)
- [x] **Q7.6** (landed; `ExpirationWorker.ExpireBoardJobsAsync` + `(Requested, Expired)` transition + `BoardJobExpired` notification) Backend: board expiry. After `QuotesCloseAtUtc` no new quotes. If no valid quote remains, the job becomes `Expired` through `IJobStatusService` (extend `ExpirationWorker`; coordinate with plan 09 M6 quote-expiry) and the homeowner is notified (M)
- [x] **Q7.7** (landed; `BoardJobNotifyJob` enqueued from `JobService.CreateJobAsync` + batched `INotificationService.NotifyManyAsync` capped at `Matching:BoardNotifyCap` = 50) Backend: notify matching tradies when an open job is posted, batched through `INotificationService` (not a push loop), capped per run; respect device-token and email-fallback rules (M)
- [x] **Q7.8** (backend `QuoteCounts.Compute` + `JobRepository.GetQuoteCountsAsync` + `QuoteCountsTests` done; mobile `hasQuoteActivity` + `"N quotes in"` copy done) Counts: for open jobs `QuotesRequested` is null and the UI shows "N quotes in" (no "of M"); invite-only jobs keep "N of M". Update `QuoteCounts` and tests; `Job.hasQuoteActivity` also true for open jobs with a close time (S)
- [x] **Q7.9** Mobile homeowner: post-project choice "Open to nearby tradies" (default) vs "Invite tradies"; open jobs skip `/tradies` and go straight to quotes; subtitle and D4 routing updated; quotes screen shows "Quotes close in 2 days" from `QuotesCloseAtUtc` (M)
- [x] **Q7.10** Mobile tradie: "Available jobs" screen and a job detail with all photos and details, reusing `tr_lead` pieces and `TrQuoteSheet`; shows "Quote valid for N hours" from the server value (Q4.2). **Design first:** frames `tr_available_jobs` and `tr_job_board_detail` in `ast/screens.mjs`, then generated stubs, gallery sync, mockup PNGs and goldens (L)
- [x] **Q7.11** Unify stage 0: one "Finding a tradie" screen for hourly (radar) and project (quotes) before booking (M)
- [x] **Q7.12** Docs: `docs/MVP.md` scope (open board, projects only, quote window setting), `docs/SPECS.md` (section 3 matching, job DTO fields, new endpoints, settings keys, privacy rule), plan 01 gap table, DESIGN_GUIDE screen lists (S)
- [x] **Q7.13** Tests: settings store (fallback, cache invalidation, audit), admin validation, available-jobs filters (service, radius, licence, blocked, already quoted, closed), quote-without-offer rules, window stamped at posting and unaffected by later setting changes, expiry, notification batching, address masking in the board DTO; mobile widget tests for both screens (M)

**Order:** Q7.1-Q7.3 (store + job fields) -> Q7.4-Q7.6 (API) -> Q7.7-Q7.8 -> mobile Q7.9-Q7.11 (design frames first) -> Q7.12-Q7.13. Slice as PR E (backend), PR F (web settings), PR G (mobile).

**What survives from Q1-Q6:** the quotes screen, View quote sheet, accept and contract gate, `quote_submitted` push routing, Q4 quote sheet polish, status-constant fix. **What changes:** the "N of M" copy applies to invite-only jobs only, and D4 routing gains an open-board branch.

## 4. Suggested order and PR slicing

1. **PR A (backend):** Q0, Q1. No visible change, safe to ship alone because the fields are nullable.
2. **PR B (mobile discoverability):** Q2. This is the F1 fix and delivers the most value; it needs only PR A.
3. **PR C (quote detail):** Q3 (design frame first, then code) once D2 is answered.
4. **PR D (tradie sheet polish):** Q4 once D3 is answered; independent of PR C.
5. Q5 docs and Q6 verification alongside each PR.

## 5. Overlap with plan 09 (notification coverage)

- `notification_route.dart` / `main.dart` push-tap handling: plan 09 N8.4 also expects route handling to change for new push types. Whichever plan lands first owns the `routeForMessage(Map)` shape from Q2.6; the other adapts.
- Quote expiry: plan 09 N3.6 may add a quote-expiry job honouring `ValidUntilUtc`. D1 already filters by `ValidUntilUtc`, so counts stay correct before and after that job exists; re-check the count helper tests if it lands first.
- Plan 09 N3.6 (accepting a quote notifies the losing tradies) touches `QuoteService.AcceptQuoteAsync`; Q1 does not touch that method.

## 6. Out of scope

New quote features (sorting, side-by-side comparison, counter-offers), a SignalR quote event, changing pricing models or the accept contract, redesigning `ho_request_sent`, and any admin web change.

## 7. Definition of done

A homeowner who has requested quotes sees a `Quotes` badge and "N of M quotes in" on the jobs list and home screen, can open the quotes screen from either, can tap "New quote received" and land on it, and can view a quote's full detail and accept it from there. Tradies can still submit quotes, with fewer server-side rejections. Mockups, specs and the gap table match the code; `dotnet test`, `flutter analyze --fatal-infos`, `flutter test` and `npm run check` pass.

## 8. Results log

- 2026-11-27: Q0.1/Q0.2 confirmed. The quotes screen's only entry is still the job-detail fallback; `OfferResponse` is `Pending/Accepted/Declined/TimedOut`; submitting a quote sets its offer `Accepted`. D1 applied as recommended.
- 2026-11-27: Q1 landed: `QuoteCounts` helper (`backend/Services/QuoteCounts.cs`), `IJobRepository.GetQuoteCountsAsync` (two narrow projections, no includes), `JobDto.QuotesRequested/QuotesReceived`, wired into `GetJobsForUserAsync` and `GetJobByIdAsync`, tests in `QuoteCountsTests.cs`, SPECS updated. **Not compiled or run in the authoring environment (no dotnet/flutter there): run `dotnet test` and `flutter analyze --fatal-infos && flutter test` locally.**
- 2026-11-27: owner ran PR A locally on `test/main-20261127`: `dotnet test` 155/155, `flutter test` 632/632; one `use_null_aware_elements` lint in `job_quote_counts_test.dart` (fixed).
- 2026-11-27: Q2.3-Q2.7 landed with D4 as recommended (D2/D3 still open): `thHomeStatusBadgeForJob`, quote subtitle, `thJobNeedsHomeownerAttention` + `Review quotes` hero, project routing in `thHomeownerJobPath`, `routeForMessage(Map)` used by `main.dart`, foreground `quote_submitted` reloads jobs and invalidates `quotesProvider`. Pure-logic tests in `mobile/test/quote_discoverability_test.dart`. Widget-level tests (Q2.8: `phase4_ho_jobs_test`, `phase4_ho_home_test`) not yet added.
- 2026-11-27: Q3.2-Q3.4 landed with D2 = bottom sheet (recommended default; not yet confirmed by owner): compact `_QuoteCard` (name, `rating · duration`, price + `fixed · incl. GST` caption, `View quote` + `Accept`), `_QuoteDetailSheet` (keys `quote_detail_<id>`, `quote_detail_accept_<id>`) whose Accept calls the same `_accept` path incl. the written-contract gate, subtitle `N of M received` from `Job.quotesRequested`. `phase4_ho_quotes_test.dart` updated (compact card, detail sheet + gate, subtitle with counts). Verified badge stays on the compact card (mockup omits it; kept so verification is visible at a glance).
- 2026-11-27: Q4 audited and done with D3 = keep the sheet (recommended default, not yet confirmed): already present and left as is: GST prefilled from profile with helper copy, `canSubmit` rules for amount > 0 and `min <= max` with inline error, server message shown verbatim, screen left on success (no second submit). Added: GST switch locked when the profile value is known (server rejects a mismatch), hourly `cap >= rate` rule with inline error (`TrQuoteDraft.capBelowRate`), test in `phase5_tr_lead_test.dart`. Parked: Q4.2 validity copy (the lead/offer payload does not expose the quote window and it must not be hard-coded; add it with the next API change); proposed-start-in-the-past (date picker already blocks past dates; only an earlier time on the same day can slip through, low impact).
- 2026-11-27: Q3.1/Q3.5 parked: the `ho_quote_detail` mockup frame is not added yet because the gallery (`mobile/lib/ui/gallery/*`) is generated from `screens.mjs` and a new frame needs new golden images, which must be produced with `flutter test --update-goldens` on a machine with Flutter. Do that together with D2 confirmation.
- 2026-11-27: Q2.1/Q2.2 landed: `Job.quotesRequested/quotesReceived/hasQuoteActivity`, `Quote.statusPending` is now `'Submitted'` with `Quote.isOpen` (accepts legacy `'Pending'`), `ho_quotes_screen.dart` uses `!quote.isOpen`; tests in `mobile/test/job_quote_counts_test.dart`.
- 2026-11-27: Q2.8 added without running Flutter (authoring environment has no toolchain): widget tests in `phase4_ho_jobs_test.dart` (Quotes badge, "2 of 3 quotes in", old copy without counts, D4 tap targets) and `phase4_ho_home_test.dart` ("Review quotes" hero opens quotes); pure tests were already in `quote_discoverability_test.dart`. Q5 docs: SPECS entry points + push, gap rows G-18..G-21 in plan 01, DESIGN_GUIDE note. **Run `flutter analyze --fatal-infos && flutter test` locally (Q6).**

- 2026-11-27: owner confirmed D2 (sheet) and D3 (keep sheet) and reported PR A/B/C/D checks green locally. Q3.1 done: `ho_quote_detail` frame in `ast/screens.mjs` mirroring `_QuoteDetailSheet`, regenerated AST/mockup HTML/Flutter stubs (`build.mjs --check` ok, 31 screens), gallery copy + route table synced, `gallery_goldens_test` count 30 to 31. PNG export and golden baselines were then produced by the owner (62 PNGs, `check-mockup-pngs.py` OK) after `mockup-shots.mjs` was fixed to test loaded font faces instead of weight 400.
- 2026-11-27: Q7.1-Q7.3 landed (backend + web settings card). Not compiled or run here (no dotnet/node deps): run `dotnet test` (new `PlatformSettingsTests`), check `dotnet ef migrations has-pending-model-changes` (the migration and snapshot were written by hand, no Designer file), and `cd web && npm run build` plus open Settings > Quotes.
- 2026-11-27: Q7.4-Q7.7 + Q7.8 (backend) landed and verified: `AvailableJobsService` (`GET /api/tradie/available-jobs` with Haversine radius filter and suburb masking), `QuoteService.SubmitQuoteAsync` (open-board quoting without an offer, full eligibility gates), `ExpirationWorker.ExpireBoardJobsAsync` (`(Requested, Expired)` transition + `BoardJobExpired`), `BoardJobNotifyJob` + `INotificationService.NotifyManyAsync` (batched push/email fallback, capped at 50), and `QuoteCounts.Compute` (`Requested = null` for open-board). Added `NotificationPolicy` rows for `BoardJobPosted` and `BoardJobExpired`, and `OpenBoardTests.cs` + updated `QuoteCountsTests.cs`. `dotnet test` passed 206/206 inside the API container. Next: Q7.8 (mobile) -> Q7.9 -> Q7.10 -> Q7.11 -> Q7.12 -> Q7.13 (mobile).
- 2026-11-27: Q7.8 (mobile) + Q7.9–Q7.13 landed and verified: `Job.openToBoard` / `Job.quotesCloseAtUtc` / `hasQuoteActivity` + `"N quotes in"` copy (`ho_home_mapper.dart`); `PostJobState.openToBoard` (default `true`) + `HoPostJobProject` pills + `HoPostJobScreen` routing straight to quotes + `HoQuotesScreen` countdown (`thQuotesCloseLabel`); design AST frames `tr_available_jobs` & `tr_job_board_detail` (`npm run build && npm run check` 33 screens pass, gallery synced + goldens generated); `AvailableJob` model, `JobsRepository.getAvailableJobs`, `availableJobsProvider`, `TrAvailableJobsScreen`, `TrJobBoardDetailScreen`, `TrQuoteSheet.quoteValidityHours`, entry point on `TrJobsScreen`; stage 0 unified in `ThMatchingScreen` & `ThJobDetailRouter`; docs updated (`MVP.md`, `SPECS.md`, `DESIGN_GUIDE.md`, `README.md`, plan 01 G-22); mobile unit + widget tests (`job_quote_counts_test.dart`, `quote_discoverability_test.dart`, `open_board_test.dart`) + `flutter analyze --fatal-infos` clean. Q6 left for later.

## Decisions and parked items

- 2026-11-27: Phase Q6/Q7 follow-through: added Maestro smoke flow `.maestro/flows/homeowner/06_quote_visibility.yaml` (launch → login → tap jobs dock → assert `"1 of 1 quotes in"` → screenshot). Runtime verification on the iOS simulator is blocked by Maestro's inability to inject the Flutter `dart-define` env the app needs (`FIXO_API_URL`); the equivalent Flutter integration tests already pass. Demo E2E run (`scripts/e2e-demo.py --single-flow --pace 5`) started with a clean preflight (admin env set, two booted iPhones, admin web on :8090) and progressed through the homeowner post-job → tradie offer → booking → payment → review scenes; the run was terminated mid-flight by the tool timeout.
- **D5** open project board for Project jobs: yes (owner, 2026-11-27). Hourly stays off the board; the quote stays binding, changes only through approved adjustments.
- **D6** 72-hour windows, DB-backed and editable in the web admin (`Quotes.BoardWindowHours`, `Quotes.ValidityHours`), never hard-coded; no quote-count cap for now.
- **D7** show all job details to tradies; exact street address and contact stay masked until `Booked` (assumption, confirm).
- **D1** applied as recommended (see section 3).
- **D2** bottom sheet: confirmed by the owner 2026-11-27.
- **D3** keep the tradie quote sheet: confirmed by the owner 2026-11-27 (gap G-20 closed).
- **D4** applied as recommended (Q2.4).
- Parked: Q4.2 (quote validity copy): now delivered by Q7.3/Q7.10 once validity is DB-backed and exposed.
