---
name: e2e-demo
description: Runs the scripted three-POV walkthrough of the Fixo marketplace for screen recording. Use when the user asks to run/play the e2e demo, record a demo of the product, or show homeowner/tradie/admin flows end to end.
---

# E2E demo — three-POV screen-recording run

`scripts/e2e-demo.py` plays one marketplace job through its whole life,
hands-free and paced for screen recording: the **homeowner** and **tradie** on
two iOS simulators, **admin** in a headed Chromium window, choreographed one
scene at a time.

## Prereqs

- `docker compose up -d` (API + db). The script fails fast if the API is down.
- Two booted iOS simulators (`xcrun simctl boot` / open in Simulator.app);
  auto-picks a "Max/Plus" device for the homeowner when two are booted.
- `web/node_modules` + Playwright Chromium installed.
- Screen-recording permission for the terminal if `--record` is used.

## Run it

```sh
python3 scripts/e2e-demo.py                 # 15s countdown → plays
python3 scripts/e2e-demo.py --record        # also screen-records the main display (screencapture)
python3 scripts/e2e-demo.py --wait-enter    # parks ready, Enter starts the show
python3 scripts/e2e-demo.py --pace 5 --say  # slower pacing, spoken scene titles
python3 scripts/e2e-demo.py --only-preflight
```

Useful flags: `--theme dark`, `--homeowner-udid`/`--tradie-udid`,
`--web-port 8090`, `--window 1440x900+0+0`, `--no-arrange`,
`--build-timeout 900`, `--port 5099`.

## What it plays

admin: login → dashboard/users/jobs tour → credential approve + reject →
payment receipt verify → completed job → payout process → dispute resolve →
audit log.
homeowner: onboarding/login → post job → matching → pay by bank transfer →
confirm completion → review → open dispute.
tradie: login → dashboard/jobs/onboarding wizard → accept offer → check in →
live chat → check out → rate homeowner.

Anything the UI cannot do natively (photo picker, LINZ address lookup without
a key, a missing Accept surface) falls back to the API and is listed under
"API fallbacks" in the timeline — keep that report honest, never hide it.

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
- Files: `mobile/integration_test/demo_tour_test.dart` (mobile actors),
  `mobile/integration_test/helpers/demo_helper.dart` (signal client),
  `scripts/e2e-demo/admin_pov.mjs` (browser actor), `scripts/e2e-demo.py`
  (orchestrator + signal server).
