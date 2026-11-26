#!/usr/bin/env bash
# audit.sh: the v2 design gate (tokens, screens, WCAG contrast, stale outputs).
# Stable entry point for the ui-audit skill; delegates to build.mjs.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
node "$ROOT/docs/design/mobile/tools/build.mjs" --check
