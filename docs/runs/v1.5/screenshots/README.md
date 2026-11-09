# Screenshots — v1.5 (V15-20 accessibility/cross-device sweep)

74 full-screen captures taken 2026-10-27 on booted iOS simulators against the
live docker-compose backend, after the V15-07–V15-19 UI slices landed.

- **Devices:** iPhone 17 Pro (homeowner/shared, logical 402×874) and
  iPhone 17 Pro Max (tradie, logical 440×956). These are the nearest available
  devices to the manifest targets 393×852 / 430×932 — recorded as a deviation.
- **Themes:** `light/` and `dark/` — simulator appearance toggled per pass via
  `xcrun simctl ui <udid> appearance light|dark`; the app follows
  `ThemeMode.system`.
- **Driver:** `mobile/integration_test/screenshots_test.dart` prints `__SHOT__`
  markers; `scripts/run-shots.sh <persona> <theme> <udid> [defines]` tails the
  run and fires `xcrun simctl io <udid> screenshot` per marker.
- **Fixtures:** `scripts/mk-shot-fixtures.sh --with-offer` seeded jobs 130
  (Requested/matching), 131 (AwaitingPayment → later Expired), 132 (Booked),
  133 (InProgress); fresh pending offers were created before each tradie pass
  (job 135 light / 136 dark, offers 138 / 139 — ~10 min lifetime). All titles
  are synthetic "Shot …" fixtures; no customer data appears.

## Deviations recorded

- Viewports are 402×874 / 440×956, not 393×852 / 430×932 (nearest booted sims).
- `homeowner/07_matching` shows the truthful 409 "cannot start matching"
  state — the fixture had already dispatched during the light pass.
- `homeowner/12_payment` shows the Expired/blocked-instructions path (window
  closed between fixture seeding and the dark pass — valid H14 variant).
- A stray "Allow widgets from Maps to use your location?" system dialog
  blanked the first dark homeowner pass (17 identical files); it was dismissed
  and the pass re-run — evidence above is from the clean re-run.
- Single-frame captures cover each recipe's default variant only; the
  multi-variant rows (slides, error states, all job statuses, wizard steps
  2–4, cancel sheet) remain expansion work, tracked in
  `docs/specs/v1.5/capture-manifest.csv`.

## Re-run

```sh
./scripts/mk-shot-fixtures.sh --with-offer   # prints SHOT_*_JOB ids
./scripts/run-shots.sh homeowner light  <udid-pro>     SHOT_MATCH_JOB=… SHOT_PAYMENT_JOB=… SHOT_BOOKED_JOB=… SHOT_INPROGRESS_JOB=…
./scripts/run-shots.sh tradie    light  <udid-promax>  … SHOT_OFFER_JOB=…
xcrun simctl ui <udid> appearance dark   # then repeat both runs with theme=dark
```

## File → route mapping

Same stems as v1.4 (`../v1.4/screenshots/README.md`): `shared/0N_*` pre-auth,
`homeowner/NN_*` /home-owner routes, `tradie/NN_*` tradie routes
(`10_onboarding_wizard`, `11_public_profile`, `12_homeowner_profile`,
`05_active_job_booked` appended after the main stop list).
