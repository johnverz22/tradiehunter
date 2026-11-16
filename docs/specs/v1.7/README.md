# v1.7 Specifications — Job Flow Revision

This directory contains the v1.7 specification and implementation tasks for the TradieHunter **Phase 12 job-flow revision**: flexible timing, pay-on-completion, on-demand price adjustments, tradie browse, and project-based jobs.

## Status

**Approved for build — implementation not started.** Owner sign-off received 2026-11-16 for the scope flag in the specification (it changes decisions recorded in `docs/MVP-SPEC-v1.3.md`: **A5** hourly-only, **B1** materials off-platform, and the **P4** upfront-payment model). All eight open decisions (**D1–D8**) were resolved by the owner on 2026-11-16 — see [Decisions](#decisions). Implementation is tracked task-by-task in [tasks.md](tasks.md) and starts on the owner's go signal. In-app card payments / BNZ integration remain out of scope; payment stays manual bank-transfer + receipt + admin verification.

## Contents

* **[specification.md](specification.md)** — the full Phase 12 plan: requested changes, NZ-market research, gap analysis against the current implementation, target flow (screens, statuses, money model), workstreams A–F with acceptance criteria, resolved decisions (D1–D8) and risks.
* **[tasks.md](tasks.md)** — the P12-01…P12-28 implementation tasks with priorities, dependencies, dependency graph, build order and per-task checklists.

## What changes (summary)

1. **Timeframe becomes optional** for homeowners (timing preference: Flexible / ASAP / Pick a date / Date range).
2. **Total price is determined at job completion**, not at request. The tradie's rate is still shown up front. Payment moves to the end of the flow.
3. **On-demand price adjustments** during the job (materials, extra work, travel), each needing the homeowner's explicit, recorded approval before it can be billed.
4. **Tradie selection leaves the Post Job screen** — a dedicated tradie-list screen (design frame H19) with profiles, or Quick match as fallback. Also fixes the latent bug where the homeowner's chosen tradie was ignored (spec §3, row 4b).
5. **Project-based jobs** on the same Post Job screen: quotes from up to 3 tradies concurrently, with large-job (NZD 30k+) written-contract guardrails. Milestone payments are deferred (D2 — not in Phase 12).
6. **GST-inclusive consumer pricing** — tradies carry an `IsGstRegistered` profile flag; all homeowner-facing prices are final, labelled "Incl. GST" or "No GST charged" (D8, NZ Fair Trading Act).

## Build order

From [specification.md](specification.md) §12:

1. **P12-01 → P12-03** — data model & null-safe schedule (foundation, no UX change).
2. **P12-10 → P12-16** — pay-at-completion, behind the `JobFlow:Version` feature flag (highest risk; built and tested first end-to-end).
3. **P12-04 → P12-09** — Post Job simplification, tradie list, profile, direct request.
4. **P12-17 → P12-20** — price adjustments.
5. **P12-21 → P12-25** — project jobs (**P12-26** milestones deferred — D2 resolved, not in Phase 12).
6. **P12-27 → P12-28** — rollout & quality throughout; flip the flag after QA.

## Decisions

All eight open decisions (D1–D8) were resolved by the owner on 2026-11-16; resolutions and rationale live in [specification.md](specification.md) §11, with the working outcomes summarised at the bottom of [tasks.md](tasks.md). In brief: **D1** pay-at-end with platform safeguards, no deposits · **D2** milestone payments deferred (P12-26 not in Phase 12) · **D3** request + optional message only, no pre-booking chat · **D4** non-monetary cancellation consequences only · **D5** commission on labour only by default (toggle retained) · **D6** pre-approved materials allowance cut · **D7** single pending hourly request with urgency-aware expiry · **D8** GST-inclusive consumer pricing with an `IsGstRegistered` profile flag and "Incl. GST" / "No GST charged" labels. Risks R1–R2 remain tracked (feature-flag rollout; legal review before projects go live).

## QA

A `QA-14-p12-*.md` checklist will be added under `qa/` as part of P12-28, inheriting all v1.2/v1.3 cases (current set: QA-00–QA-13).

## Relationship to earlier versions

All v1.2–v1.6 work remains in force. This spec supersedes the specific v1.3 decisions named above (with sign-off recorded); the v1.6 design system and frame files — including **H19 Browse Tradies** (`docs/design/v1.6/html/frames-homeowner.html`) — remain the visual source of truth for v1.7 UI work per `AGENTS.md`.
