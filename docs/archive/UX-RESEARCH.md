# Market Research & UX Discovery

## Target personas & mental models

**Sarah (Homeowner)** thinks of this like booking an Uber or ordering food delivery — describe the need once, get matched fast, see price/rating before committing. She does not want to browse endless trade profiles or make five phone calls. Trigger: urgency ("my toilet is leaking now") or a planned project ("3 quotes for a deck by Friday"). Expects instant confirmation of receipt, visible price ranges before committing time, and social proof before paying.

**James (Tradie)** treats this as a lead-generation and cash-flow tool, not a social app. Opens it in idle moments expecting qualified, nearby, ungated leads — not a firehose he has to filter manually. Trust threshold is payment certainty more than UI polish.

## Competitor & pattern benchmarking

- **Builderscrack** — NZ's leading home-improvement marketplace (16,500+ verified tradespeople, 750,000+ jobs facilitated). Post-a-job → multiple tradies quote → homeowner picks. Friction: "post and wait" — no instant matching, quote-chasing takes days.
- **Tradee** — Uber-style, consumer-focused (not industry-jargon-heavy), reviews tied to the individual tradesperson, requires NZ National Certificate for regulated trades (building/plumbing/electrical). In-app payment layered in later at ~6% fee. Closest analog to this product's direct-match vision.
- **Houzz (NZ)** — inspiration-to-execution: editorial content, forums, photo-led professional directory. Discovery/inspiration-led rather than task-led; useful for portfolio/trust UX but heavier than an MVP needs.

**Standard UX patterns users expect**: single "describe your job" entry point (photo + short text + category); visible price signals before contact; star rating + review count + verified badge on every tradie card; status tracker ("Requested → Matched → Scheduled → Complete → Paid"); push/SMS for anything time-sensitive.

**Friction points this product should solve**: "post and wait" job-board models leave timing uncertain; tradies drowned in irrelevant leads outside their trade/area; payment ambiguity (cash vs in-app) causes disputes; no accountability for cancellations/no-shows.

## UX design principles
1. One-tap job description, not a form — structured chips over free text wherever possible.
2. Progressive trust disclosure — enough signal (rating, price range, verified badge) to decide to engage, without forcing full profile browsing first.
3. Status-first navigation — home screen defaults to "what's happening with my active job(s)," not a browse feed.
4. Low-friction reciprocity for tradies — every homeowner action should generate a minimum-effort tradie action (accept/decline) for MVP, not a typed quote.
5. Visible accountability loop — reviews, cancellation history, response-time stats surfaced at decision points, not buried in a profile tab.
