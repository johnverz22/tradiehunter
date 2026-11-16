#!/usr/bin/env python3
"""Import-boundary guard for the v1 -> v2 UI migration (plan task 2.4).

v1 and v2 both define THColors, THType, THBadge, THField, ... so they only stay
safe side by side if no file imports both. Rules:
  * mobile/lib/ui/**  must not import theme/design_tokens.dart, theme/fixo_theme.dart,
    widgets/fixo_*, widgets/th_components.dart, or views/**
  * files outside mobile/lib/ui/**  must not import ui/design/**
Remove this guard in Phase 6.5. Usage: python3 scripts/check_ui_boundary.py [mobile_dir]
"""
import os, re, sys

mobile = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "mobile"))
lib = os.path.join(mobile, "lib")
pkg = re.search(r"^name:\s*(\S+)", open(os.path.join(mobile, "pubspec.yaml")).read(), re.M).group(1)
IMPORT = re.compile(r"""^\s*(?:import|export)\s+['"]([^'"]+)['"]""", re.M)

def rel(p):
    return os.path.relpath(p, lib).replace(os.sep, "/")

def resolve(src, target):
    if target.startswith("dart:"):
        return None
    if target.startswith(f"package:{pkg}/"):
        return os.path.normpath(os.path.join(lib, target[len(f"package:{pkg}/"):]))
    if target.startswith("package:"):
        return None
    return os.path.normpath(os.path.join(os.path.dirname(src), target))

def v1_banned(r):
    return (r in ("theme/design_tokens.dart", "theme/fixo_theme.dart", "widgets/th_components.dart")
            or r.startswith("views/")
            or (r.startswith("widgets/") and os.path.basename(r).startswith("fixo_")))

errors = []
for root, _, files in os.walk(lib):
    for name in files:
        if not name.endswith(".dart"):
            continue
        path = os.path.join(root, name)
        me = rel(path)
        inside_ui = me.startswith("ui/")
        for t in IMPORT.findall(open(path, encoding="utf-8").read()):
            dest = resolve(path, t)
            if dest is None:
                continue
            r = rel(dest)
            if inside_ui and v1_banned(r):
                errors.append(f"{me}: v2 file imports v1 code ({t})")
            elif not inside_ui and r.startswith("ui/design/"):
                errors.append(f"{me}: v1 file imports v2 design layer ({t})")

if errors:
    print("UI import-boundary violations:")
    print("\n".join("  " + e for e in errors))
    sys.exit(1)
print("ui import boundary ok")
