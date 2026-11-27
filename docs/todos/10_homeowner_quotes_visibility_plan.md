# Homeowner Quotes Visibility: surface quotes in the jobs list, add "View quote", settle the tradie quote builder

> **Repo / branch:** `johnverz22/tradiehunter` @ `main`
> **Purpose:** Close the gaps found when tracing the v2 mockups (`docs/design/mobile/ast/screens.mjs` -> `mockups/png/`) against the Flutter implementation (`mobile/lib/ui/`). The quote flow works end to end, but a homeowner who requested quotes has almost no way to find them. This plan makes quotes discoverable, adds the missing "View quote" detail, and records a decision on the tradie quote builder.
> **Status:** Landed except Q4.2 (parked: needs an API field) and Q6 (owner's final verification: Q6.4 manual path, Q6.5 optional) · **Prepared:** 2026-11-27
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
- [ ] **Q6.5** Optional: add this journey to the persona fabric (`docs/todos/08_e2e_persona_fabric_plan.md`, `scripts/e2e-journey.py` scenarios) so it stays covered (M)

## Phase Q7: Open project board (PROPOSAL, owner decision D5 first; nothing here is started)

**Idea (owner, 2026-11-27):** instead of the homeowner choosing up to 3 tradies before any quote exists, a Project job is posted once and appears on an "Available jobs" list for tradies who offer that service (and are in range and credentialled). Tradies submit quotes themselves. Hourly and project jobs then share the same progress-tracked screens, with the final amount settled at completion.

**Assessment (2026-11-27, from code and SPECS):**

- **It fixes the root of F1/F5/F6/F8.** The homeowner no longer needs a pre-selection step, the "2 of 3" denominator, `/tradies` routing, expiry of invited requests or "Pick someone else". Quotes just arrive and the list says "N quotes".
- **Convergence mostly exists already.** Accepting a quote books the job as a normal v2 job with the pricing model snapshotted, then it uses the same detail, payment and review screens as hourly. Only stage 0 differs (radar for hourly, quotes for projects). Unifying stage 0 into one "Finding a tradie" screen that shows either state is cheap.
- **Do not make the quote re-priceable at the end.** SPECS section 5 treats a quote as a commitment (a quote cannot rise without agreement; Fixed = agreed price + approved adjustments) and the s362F written-contract gate at NZD 30,000+ is decided at booking. "Price changes on demand" is already covered by the three models: EstimateRange and HourlyWithCap settle on final hours, and any model can change through an approved adjustment. Keep that; do not add a free re-quote at completion.
- **Keep both entry paths, keep hourly off the board.** Hourly jobs need fast acceptance (Quick match / direct request); a board slows them. For projects keep "invite a specific tradie" (it already works) beside "open to all nearby".
- **Cost is moderate, the data model is ready.** `Quote.OfferId` is already nullable and address masking before `Booked` already exists. New: an available-jobs query (EF Core spatial LINQ, rule 2), credential/licence gating, a way for a tradie to quote without an offer, and abuse controls.
- **Risks that need decisions, not code:** unlimited quotes overwhelm the homeowner (cap, see D6); no pre-booking chat (MVP) means no scope Q&A, so rely on `ScopeNotes`/`SiteVisitWelcome` and photos; photos can leak the address (strip or hide for non-invited tradies); push fan-out to every matching tradie; this is a scope change to `docs/MVP.md`, so it needs an explicit decision, not just a plan edit.

**Decisions to confirm:**

1. **D5: open board for Project jobs?** Recommended: yes, as an addition to direct invites, Project jobs only.
2. **D6: quote cap and window.** Recommended: close the job to new quotes at N received (suggest 5, config `MaxQuotesPerProject`) or after `QuoteWindowHours`, whichever first.
3. **D7: visibility to tradies.** Recommended: suburb, service, scope, budget range and timing only; exact address and photos with location context stay hidden until `Booked`; tradies only see jobs for services they offer, in radius, with the right credential, not blocked.

**Tasks (only after D5):**

- [ ] **Q7.1** Backend: `GET /api/tradie/available-jobs` (paged; Project, `Requested`, matches service + radius + licence board + not blocked, no quote yet from me; masked DTO per D7). Include `QuotesReceived` count and time left (M)
- [ ] **Q7.2** Backend: `POST /api/jobs/{id}/quotes` accepts a tradie with no pending offer when the job is open to the board; set `OfferId = null`. Enforce D6 cap and window, one quote per tradie per job, same GST rules (M)
- [ ] **Q7.3** Backend: add `OpenToBoard` (bool) on Project jobs and the post-job request; notification fan-out to matching tradies in batches through `INotificationService`, not one push per candidate in a loop (M)
- [ ] **Q7.4** Counts: `QuoteCounts` drops the denominator for open jobs (`QuotesRequested` null or equal to received); mobile copy "N quotes in" without "of M"; keep "N of M" for invite-only jobs (S)
- [ ] **Q7.5** Mobile tradie: "Available jobs" list screen and a lead detail reusing `tr_lead` + `TrQuoteSheet`; needs mockup frames first (`tr_available_jobs`), then goldens (L)
- [ ] **Q7.6** Mobile homeowner: post-project choice "Invite tradies" vs "Open to nearby tradies"; open jobs skip `/tradies` and go straight to quotes (D4 routing updated) (M)
- [ ] **Q7.7** Unify stage 0: one "Finding a tradie" screen for hourly (radar) and project (quotes) so both converge visually before booking (M)
- [ ] **Q7.8** Docs: `docs/MVP.md` scope (open board, project only), `docs/SPECS.md` section 3 and the DTO notes, plan 01 gap table, mockups (S)
- [ ] **Q7.9** Tests: query filters (service, radius, licence, blocked, already quoted), cap and window, privacy of the DTO, notification batching (M)

**What survives from Q1-Q6 if D5 = yes:** the quotes screen, View quote sheet, accept and contract gate, `quote_submitted` push routing, Q4 quote sheet polish, status-constant fix. **What changes:** the "N of M" subtitle and badge only apply to invite-only jobs, and D4 routing gains an open-board branch.

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

(Until D5 is confirmed, Phase Q7, the open project board, is out of scope.) New quote features (sorting, side-by-side comparison, counter-offers), a SignalR quote event, changing pricing models or the accept contract, redesigning `ho_request_sent`, and any admin web change.

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

## Decisions and parked items

- **D5-D7** (open project board, quote cap, tradie visibility): proposed 2026-11-27 in Phase Q7, awaiting the owner. Hourly jobs stay off the board; the quote stays binding, with changes only through approved adjustments.
- **D1** applied as recommended (see section 3).
- **D2** bottom sheet: confirmed by the owner 2026-11-27.
- **D3** keep the tradie quote sheet: confirmed by the owner 2026-11-27 (gap G-20 closed).
- **D4** applied as recommended (Q2.4).
- Parked: Q4.2 (quote validity copy, needs the API to expose the quote window, never hard-code `QuoteWindowHours`).
