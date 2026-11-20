#!/usr/bin/env python3
"""Static check of the screenshot capture names (fix plan P-05).

The capture drivers cannot be run without a simulator, so this keeps the names
consistent without one. It compares four things:

  1. section 7.3 of docs/todos/02_design_system_fix_plan.md   (the plan)
  2. docs/design/mobile/tools/capture-manifest.json            (the manifest)
  3. the `__SHOT__` / skip names in the integration_test drivers
  4. docs/design/mobile/tools/shot-map.json                    (mockup id -> names)

Fails (exit 1) when:
  * the manifest's `required` names differ from the plan's section 7.3;
  * a driver mentions a name that is neither required nor an `extra`;
  * a required name is neither mentioned by a driver nor listed as `pending`
    (with the reason), or a `pending` name is mentioned after all (stale);
  * shot-map.json uses a name that is not required, extra or legacy;
  * a committed capture under docs/runs/v2/screenshots*/<theme>/ has a name
    that is not required or extra (a stale v1-era image, P4-03).

Usage: scripts/check-capture-names.py [--list]
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLAN = ROOT / "docs/todos/02_design_system_fix_plan.md"
MANIFEST = ROOT / "docs/design/mobile/tools/capture-manifest.json"
SHOT_MAP = ROOT / "docs/design/mobile/tools/shot-map.json"
DRIVERS = [
    ROOT / "mobile/integration_test/screenshots_test.dart",
    ROOT / "mobile/integration_test/screenshots_variants_test.dart",
]
PERSONAS = ("homeowner", "tradie")


def split_top_level(text: str) -> list[str]:
    """Split on commas that are not inside braces."""
    parts, depth, cur = [], 0, ""
    for ch in text:
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur.strip())
            cur = ""
        else:
            cur += ch
    if cur.strip():
        parts.append(cur.strip())
    return parts


def expand_braces(item: str) -> list[str]:
    m = re.search(r"\{([^{}]*)\}", item)
    if not m:
        return [item]
    out: list[str] = []
    for alt in m.group(1).split(","):
        out += expand_braces(item[: m.start()] + alt.strip() + item[m.end():])
    return out


def plan_names() -> set[str]:
    """Names listed in section 7.3: lines like  `homeowner/`: 01_home, ..."""
    names: set[str] = set()
    for line in PLAN.read_text().splitlines():
        m = re.match(r"^`(homeowner|tradie|shared)/`:\s*(.+?)\.?\s*$", line)
        if not m:
            continue
        for item in split_top_level(m.group(2)):
            for name in expand_braces(item):
                names.add(f"{m.group(1)}/{name}")
    return names


def driver_names() -> dict[str, set[str]]:
    """Capture names mentioned as string literals, by driver file name."""
    literal = re.compile(r"'((?:shared|homeowner|tradie|\$_persona)/[A-Za-z0-9_]+)'")
    found: dict[str, set[str]] = {}
    for path in DRIVERS:
        names: set[str] = set()
        for raw in literal.findall(path.read_text()):
            if raw.startswith("$_persona/"):
                names |= {f"{p}/{raw.split('/', 1)[1]}" for p in PERSONAS}
            else:
                names.add(raw)
        found[path.name] = names
    return found


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", action="store_true", help="print the pending names")
    args = ap.parse_args()

    manifest = json.loads(MANIFEST.read_text())
    required = set(manifest["required"])
    extra = set(manifest["extra"])
    legacy = set(manifest["legacy"])
    pending = manifest["pending"]  # name -> reason
    plan = plan_names()
    drivers = driver_names()
    mentioned = set().union(*drivers.values())
    errors: list[str] = []

    if not plan:
        errors.append(f"no capture names parsed from {PLAN.name} section 7.3")
    for name in sorted(plan - required):
        errors.append(f"in plan 7.3 but not in manifest.required: {name}")
    for name in sorted(required - plan):
        errors.append(f"in manifest.required but not in plan 7.3: {name}")

    for name in sorted(mentioned - required - extra):
        where = ", ".join(f for f, ns in drivers.items() if name in ns)
        errors.append(f"driver name not in manifest (required/extra): {name} ({where})")
    for name in sorted(required - mentioned):
        if name not in pending:
            errors.append(f"required capture never taken or skipped by a driver: {name}")
    for name in sorted(set(pending) & mentioned):
        errors.append(f"listed as pending but a driver mentions it: {name}")
    for name in sorted(set(pending) - required):
        errors.append(f"pending name is not a required name: {name}")

    shot_map = json.loads(SHOT_MAP.read_text())
    known = required | extra | legacy
    for mockup_id, names in shot_map.items():
        if mockup_id.startswith("_"):
            continue
        for name in names:
            if name not in known:
                errors.append(f"shot-map.json '{mockup_id}' uses unknown name: {name}")

    for run_dir in sorted((ROOT / "docs/runs/v2").glob("screenshots*")):
        for png in sorted(run_dir.glob("*/*/*.png")):
            if png.relative_to(run_dir).parts[0] == "compare":
                continue  # generated side-by-side output, not a capture
            theme_dir = run_dir / png.relative_to(run_dir).parts[0]
            name = png.relative_to(theme_dir).with_suffix("").as_posix()
            if name not in required | extra:
                errors.append(f"stray capture not in manifest: {png.relative_to(ROOT)}")

    if args.list:
        for name, reason in sorted(pending.items()):
            print(f"pending  {name}: {reason}")

    print(
        f"required {len(required)} | extra {len(extra)} | pending {len(pending)} | "
        f"mentioned by drivers {len(mentioned)}"
    )
    if errors:
        print(f"FAIL: {len(errors)} problem(s)", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1
    print("OK: plan 7.3, manifest, drivers and shot-map agree")
    return 0


if __name__ == "__main__":
    sys.exit(main())
