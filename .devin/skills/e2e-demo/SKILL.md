---
name: e2e-demo
description: Runs the scripted three-POV walkthrough of the Fixo marketplace for screen recording. Use when the user asks to run/play the e2e demo, record a demo of the product, or show homeowner/tradie/admin flows end to end.
---

# E2E demo — three-POV screen-recording run

`scripts/e2e-demo.py` plays one marketplace job through its whole life,
hands-free and paced for screen recording: the **homeowner** and **tradie** on
two iOS simulators, **admin** in a headed Chromium window, choreographed one
scene at a time. It runs on the **persona fabric** (plan 08), not the seeded
`*@fixo.test` accounts: each run provisions fresh `qa+demo<ts>-*@fixo.test`
personas through `scripts/e2e-personas.py` (real signup/OTP, approved
credential, payout bank details, one staff) and passes the manifest to every
actor (`E2E_MANIFEST`). The homeowner's job is a direct request to the manifest
tradie (same path as `e2e-journey.py`) and is recorded in the manifest's `jobs`
array as scenario `demo` (`demo-dispute` for the dispute job).

## Prereqs

- `docker compose up -d` (API + db + **MailHog**: the fabric reads OTP and
  staff-invite emails from it). The script fails fast if the API or MailHog is
  down, or the superadmin login (`FIXO_ADMIN_EMAIL`/`FIXO_ADMIN_PASSWORD`,
  default `admin@tradiehunter.nz`) fails. Local stack only: a non-localhost
  `FIXO_API_URL` is refused. No `seed-test-accounts.sh` needed.
- v2 job flow (the stack default): direct requests need a v2 job.
- Two booted iOS simulators (`xcrun simctl boot` / open in Simulator.app);
  auto-picks a "Max/Plus" device for the homeowner when two are booted.
- `web/node_modules` + Playwright Chromium installed.
- Screen-recording permission for the terminal if `--record` is used.

## Run it

```sh
python3 scripts/e2e-demo.py                 # provisions personas, 15s countdown → plays, deactivates them
python3 scripts/e2e-demo.py --record        # also screen-records the main display (screencapture)
python3 scripts/e2e-demo.py --wait-enter    # parks ready, Enter starts the show
python3 scripts/e2e-demo.py --pace 5 --say  # slower pacing, spoken scene titles
python3 scripts/e2e-demo.py --only-preflight   # checks the environment, provisions nothing
python3 scripts/e2e-demo.py --manifest PATH    # reuse a fabric run (not deactivated on exit)
python3 scripts/e2e-demo.py --keep-accounts    # keep the provisioned accounts active after the run
python3 scripts/e2e-demo.py --cleanup --manifest PATH   # deactivate that run's accounts, then exit
```

On exit a run that provisioned its own personas calls
`e2e-personas.py --cleanup <manifest>` (accounts are deactivated, rows stay).
The manifest path is printed and recorded in `timeline.md`/`timeline.json`.

Useful flags: `--theme dark`, `--homeowner-udid`/`--tradie-udid`,
`--web-port 8090`, `--window 1440x900+0+0`, `--no-arrange`,
`--build-timeout 900`, `--port 5099`.

## What it plays

admin (manifest staff persona): login → dashboard/users/jobs tour →
credential approve + reject (two pending `demo-tour-*` credentials uploaded as
the manifest tradie; the tradie stays verified) →
payment receipt verify → completed job → payout process → dispute resolve →
audit log.
homeowner: onboarding/login → post job → matching → booked → approve the
itemised amount → pay by bank transfer → (admin verifies) → review → open dispute.
tradie: login → dashboard/jobs/onboarding wizard → accept offer → check in →
live chat → check out → rate homeowner.

Anything the UI cannot do natively (photo picker, LINZ address lookup without
a key, job submission via direct request, a missing Accept surface) falls back
to the API and is listed under "API fallbacks" in the timeline — keep that
report honest, never hide it. Gaps in a manifest persona (availability, payout
bank details) are filled through the API, never SQL, and listed there too.
The admin only acts on job ids recorded in the manifest.

## Output

- `$TMPDIR/fixo-e2e-demo/<timestamp>/` — `timeline.md`/`timeline.json`
  (timestamped scenes for video chaptering), per-actor logs, `recording.mov`
  with `--record`.
- Exit code 0 = all actors finished; non-zero on any failure.

## When it misbehaves

- "need two booted iOS simulators" → boot two in Simulator.app.
- Flutter build slow → raise `--build-timeout`; first run takes minutes.
- A scene times out → per-actor logs in the run dir show where; each actor's
  last lines are echoed on failure.
- "manifest has no staff persona" → provision with `e2e-personas.py --staff 1`.
- Files: `mobile/integration_test/demo_tour_test.dart` (mobile actors, read the
  manifest via `helpers/manifest_helper.dart`),
  `mobile/integration_test/helpers/demo_helper.dart` (signal client),
  `scripts/e2e-demo/admin_pov.mjs` (browser actor), `scripts/e2e-demo.py`
  (orchestrator + signal server).
