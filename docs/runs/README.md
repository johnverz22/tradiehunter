# Test runs — evidence per spec version

Each directory holds the verification evidence for a spec version:
test-run reports, screenshot sweeps, and the issue lists that feed the
next spec.

| Directory | Contents |
|---|---|
| `v1.3/` | `test-run-2026-10-26.md` (full suite results + findings), `screenshots/` (36 full-screen captures: shared/homeowner/tradie, index in `screenshots/README.md`) — the evidence `specs/v1.4` was audited from |
| `v1.4/` | `open-issues-2026-10-26.md` — consolidated defects for the `specs/v1.4` fix pass; `test-run-2026-10-26.md` — post-fix verification (**all layers green, 25/25 integration**); `screenshots/` (36 captures incl. the new pending-offer UI); `test-logs/` (raw suite logs) |

## Convention

When a test/screenshot pass produces findings that feed a spec version:

```
runs/<version-tested>/
  test-run-<date>.md        # results, fixes applied, issues found
  screenshots/              # full-screen captures organized by role
    README.md               # file → route mapping + re-run command
    shared/  homeowner/  tradie/

runs/<version-fixing>/
  open-issues-<date>.md     # actionable defects for that spec's fix pass
```

How to run the suites: `../RUNNING-TESTS.md`.
Screenshot driver: `mobile/integration_test/screenshots_test.dart` (must
live under `integration_test/` — `flutter test` runs files elsewhere
host-side, so on-device plugin channels never connect).
