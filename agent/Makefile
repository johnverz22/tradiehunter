# TradieHunter agent toolchain: design gate + Flutter checks.
# Usage: make -C agent <target>. Requires node>=18 (and the Flutter SDK for `flutter`).
.PHONY: setup audit build flutter verify

setup:            ## run the design gate
	bash agent/setup.sh

audit:            ## tokens, screens, WCAG contrast, stale-output check
	node docs/design/mobile/tools/build.mjs --check

build:            ## regenerate tokens + screen stubs from tokens.json / mockups
	node docs/design/mobile/tools/build.mjs

flutter:          ## dart format + analyze + test (needs Flutter SDK)
	cd mobile && dart format lib test integration_test && flutter analyze --fatal-infos && flutter test

verify: audit     ## everything except flutter
