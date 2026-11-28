"""Simulator discovery and window arrangement (moved from scripts/e2e-demo.py, plan 12 U1.1).

iOS simulators only for now (plan decision 1). Android device ids and the 10.0.2.2 rewrite
from scripts/run-e2e.sh join this module in phase U9.
"""
from __future__ import annotations

import json
import subprocess

from .stage import die


def booted_simulators() -> list[tuple[str, str]]:
    out = subprocess.run(["xcrun", "simctl", "list", "devices", "booted", "-j"], capture_output=True, text=True).stdout
    devices = json.loads(out or "{}").get("devices", {})
    return [(d["name"], d["udid"]) for group in devices.values() for d in group if d.get("state") == "Booted"]


def pick_simulators(homeowner_udid: str | None = None, tradie_udid: str | None = None) -> tuple[str, str]:
    """Returns (homeowner_udid, tradie_udid)."""
    if homeowner_udid and tradie_udid:
        return homeowner_udid, tradie_udid
    sims = booted_simulators()
    if len(sims) < 2:
        die("need two booted iOS simulators (open two in Simulator.app, or pass --homeowner-udid/--tradie-udid)."
            f" Booted: {sims or 'none'}")
    big = [s for s in sims if "Max" in s[0] or "Plus" in s[0]]
    homeowner = homeowner_udid or (big[0] if big else sims[0])[1]
    tradie = tradie_udid or next(u for _, u in sims if u != homeowner)
    return homeowner, tradie


def arrange_windows(homeowner_udid: str, tradie_udid: str) -> None:
    """Best effort: Chromium left, simulators right. Silently skipped without Accessibility permission."""
    script = """
    tell application "Finder" to set b to bounds of window of desktop
    set sw to item 3 of b
    tell application "System Events"
      if exists process "Simulator" then
        tell process "Simulator"
          set ws to windows
          if (count of ws) >= 2 then
            set position of item 1 of ws to {sw - 900, 30}
            set position of item 2 of ws to {sw - 450, 30}
          end if
        end tell
      end if
    end tell"""
    subprocess.run(["osascript", "-e", script], capture_output=True, timeout=15)
