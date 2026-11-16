# TradieHunter agent toolchain — design audit + HTML->Flutter pipeline.
# Usage: make -C agent <target>. Requires: node>=18, python3, playwright+chromium.
.PHONY: setup audit transpile check smoke flutter verify clean

DESIGN   ?= docs/design
GEN      := tools/design2flutter/output

setup:            ## install deps + run the full verification
	bash agent/setup.sh

audit:            ## run the design audit gates on $(DESIGN)
	bash agent/skills/ui-audit/scripts/audit.sh $(DESIGN)

transpile:        ## regenerate Flutter scaffolds from mockups
	node tools/design2flutter/src/index.js --design $(DESIGN) --out $(GEN)

check:            ## structural lint of generated Dart
	node tools/design2flutter/src/index.js --check $(GEN)

smoke:            ## end-to-end pipeline proof
	node tools/design2flutter/test/smoke.js

flutter:          ## dart format + analyze + test (needs Flutter SDK)
	cd mobile && dart format lib && flutter analyze && flutter test

verify: audit transpile check smoke   ## everything except flutter

clean:
	rm -rf $(GEN) /tmp/audit-*.json
