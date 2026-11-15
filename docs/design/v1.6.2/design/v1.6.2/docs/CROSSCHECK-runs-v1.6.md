# Run screenshots (docs/runs/v1.6) vs mockups (docs/design/v1.6)

Method: ~20 design/run pairs viewed side by side at contact-sheet size (`docs/evidence/pair0..5.png`), light theme; code read in `mobile/lib/widgets/fixo_buttons.dart`, `fixo_cards.dart`, `tradie_widgets.dart`, `theme/design_tokens.dart`. These are visual comparisons, not measurements. Run data is test fixtures ("Shot PROG 1794…", "Tradie Verified"), so content differences are marked **data**.
Not verified: dark theme, any screen not listed, the canPop explanation in D-01 (read from code, not tested).

| # | Screen | Design (frame) | Run | Type | Likely cause | Fix |
|---|---|---|---|---|---|---|
| D-01 | All pushed screens | 56dp bar, 20/600 title, 24px chevron ink on gutter | `FixoAppBar` preferredSize 72 (80 with subtitle), title 28/700 (24 if >18 chars), `arrow_back_ios_new` 18; back shown only if `Navigator.canPop()`. Job detail in-progress has no back, booked has | UI | `Sizes.appBar=56` exists but is unused; routes opened with `context.go` have nothing to pop | Use `Sizes.appBar`, add `fallbackLocation` for back, 24px glyph |
| D-02 | Home H07 | "GOOD MORNING / Sarah" + location pill | "KIA ORA / Homeowner", no pill | UI+data | greeting and location not bound | bind name/suburb, hide pill when absent |
| D-03 | Tradie T19/T20 | first Accept amber, rest navy; filters Today/Upcoming/Unpaid/Done as equal columns | every Accept amber; overdue cards amber outlines + amber Check in; "Awaiting payment" label, "Done" clipped | UI | one-amber rule not enforced per list | index-based CTA style; equal-width filter row |
| D-04 | Request T21 | map header, price chip, scrim back | no map; fixture string "v1.4 screenshot fixture." visible | UI+data | map header not implemented | implement `maphead`; strip fixture text |
| D-05 | Chat H13/T23 | paper-plane send, chip row fades out | right-arrow send; chips cut with no fade | UI | `Icons.arrow_forward`; plain clipped row | paper-plane icon; `ShaderMask` fade (recipe in skill) |
| D-06 | Job detail H12/T22 | Navigate/Message/Call tile row; booked shows "You earn" | homeowner: Message only; tradie: Message/Call, Navigate lower | UI | tile row not shared | one `ActionTileRow` |
| D-07 | Payment H14 / status H15 | 3 numbered steps, "I've paid — submit receipt"; status CTA "View job" | "bank details unavailable" + Refresh; "Back to job" | data/unverifiable | backend state in the run | re-run with bank details seeded |
| D-08 | Dispute H16 | filled form, photo tiles, "What happens next", Cancel | radio card list, one large photo tile, no next-steps | UI | different layout | follow H16 |
| D-09 | Profile H18/T24 | editable form, member-since | read-only greyed inputs, edit+gear buttons | UI | edit mode split | decide, then align frame or screen |
| D-10 | Sign-up S06 | phone field, terms | password checklist; terms text cut ("…our Terms and") | UI | `Text` truncated in `Row` | wrap in `Expanded`/`Text.rich` |
| D-11 | Onboarding S02 | dots centred above full-width Next, Skip below | dots left, Skip top-right | UI | layout | match HANDOFF |
| D-12 | Messages H18 | 72px rows, time, unread dot | identical "Tradie / No messages yet" | data | fixtures | seed conversations |
| D-13 | Nav | active tab has pill behind icon | bold + filled icon | UI | `NavigationBar` default indicator | style indicator |

Systemic pattern: the mockup is authored in CSS with sizes the Flutter widgets re-derive instead of reading from tokens (D-01), and status/trust labels and scroll rows have no shared widget (D-03, D-05). The skills in `skills/` target exactly these.
