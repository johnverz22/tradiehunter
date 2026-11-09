# v1.3 Specifications — Gap Resolution

This directory contains the detailed, phase-by-phase implementation specifications for the TradieHunter v1.3 gap resolution update. These specs are derived from `docs/MVP-SPEC-v1.3.md` and extend the existing v1.2 phases (P0–P9) with two new phases.

## Context

v1.3 resolves gaps identified in the Client Clarification Questionnaire (Oct 2026). All pre-answers were accepted as agreed. The primary additions are:

1. **Commission & payout system** — tradies get paid via weekly admin-processed payouts with commission deduction
2. **Service catalog enhancements** — licence-gating for regulated trades, insurance badges
3. **Blind two-way reviews** — competitive differentiator vs Builderscrack
4. **Tradie availability toggle** — vacation/pause mode
5. **Business rule enforcement** — job editing lockout, photo limits, scope change guidance
6. **TradieHunter rebrand** — user-facing surfaces only
7. **Compliance foundations** — data retention, legal entity config

## Implementation Phases

* **[Phase 10: Business Rules, Payouts & Rebrand](P10-business-rules-payouts-rebrand.md)** — Commission model, payout tracking, service catalog seeding, licence-gated matching, tradie availability toggle, blind reviews, job editing rules, photo limits, SLA indicators, brand config, TradieHunter rebrand.
* **[Phase 11: Compliance & Data Lifecycle](P11-compliance-data-lifecycle.md)** — Data retention policy, Hangfire purge jobs, legal entity config, Terms/Privacy surfacing.

## QA

Manual test checklists and the consolidated functional testing guide live in [`qa/`](qa/README.md). The v1.3 QA set inherits all v1.2 cases (QA-00–QA-11) and adds:

* **[QA-12](qa/QA-12-p10-business-rules-payouts-rebrand.md)** — P10: payouts, blind reviews, availability toggle, rebrand, SLA indicators, matching rules
* **[QA-13](qa/QA-13-p11-compliance-data-lifecycle.md)** — P11: data retention, purge jobs, legal config, Terms/Privacy links

See also: [QA-functional-testing-guide.md](QA-functional-testing-guide.md) — the full consolidated guide for a complete release pass.

## Development Rules

Same as v1.2 — see [v1.2 README](../v1.2/README.md#development-rules).

## Relationship to v1.2

All v1.2 phases (P0–P9) remain unchanged. v1.3 phases are additive and assume P0–P9 are complete.
