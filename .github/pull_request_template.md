## Summary

## Verification

- [ ] Focused Flutter tests
- [ ] `flutter analyze --fatal-infos`
- [ ] UI import-boundary and design-system checks
- [ ] Visual QA in light and dark themes at 200% text scale, if this PR enables or changes a v2 screen

## Router and payload contract

- [ ] `app_router.dart` changes are limited to screen builders / `_pick(...)` unless the owner has explicitly approved a route, payload, or notification destination change.
- [ ] Existing route paths, `extra` payload types, and push-notification destinations remain covered by route-contract tests.

## Design follow-up

- [ ] Add the `needs-design` label when this PR composes a screen or sheet that has no v2 design.
- [ ] Record any remaining design work in the D-4 backlog.
