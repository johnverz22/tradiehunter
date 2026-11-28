"""Run reports (moved from scripts/e2e-demo.py and scripts/e2e-journey.py, plan 12 U1.1/U1.2)."""
from __future__ import annotations

import json
from pathlib import Path
from xml.sax.saxutils import quoteattr

from .stage import Show


def write_report(show: Show, run_dir: Path, ok: bool, manifest_path: Path | None = None,
                 provisioned: bool = False) -> None:
    jobs: list = []
    run_id = None
    if manifest_path and manifest_path.is_file():
        try:
            m = json.loads(manifest_path.read_text())
            run_id = m.get("runId")
            jobs = [j for j in m.get("jobs", []) if str(j.get("scenario", "")).startswith("demo")]
        except ValueError:
            pass
    (run_dir / "timeline.json").write_text(json.dumps(
        {"ok": ok, "manifest": str(manifest_path) if manifest_path else None, "runId": run_id,
         "provisionedByDemo": provisioned, "demoJobs": jobs, "steps": show.steps, "notes": show.notes}, indent=2))
    lines = ["# e2e demo timeline", ""]
    if manifest_path:
        lines += [f"Persona fabric run `{run_id}` — manifest `{manifest_path}`"
                  + (" (provisioned by this demo)" if provisioned else " (reused)"),
                  "Demo jobs: " + (", ".join(f"{j['id']} ({j['scenario']})" for j in jobs) or "none recorded"), ""]
    lines += ["| time | actor | scene |", "|---|---|---|"]
    for s in show.steps:
        m, sec = divmod(int(s["t"]), 60)
        lines.append(f"| {m:02d}:{sec:02d} | {s['actor']} | {s['title']} |")
    if show.notes:
        lines += ["", "## API fallbacks", ""] + [f"- [{n['actor']}] {n['message']}" for n in show.notes]
    (run_dir / "timeline.md").write_text("\n".join(lines) + "\n")


def write_junit(path, rows, total):
    fails = sum(1 for _, _, e in rows if e)
    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<testsuite name="e2e-journey" tests="%d" failures="%d" time="%.2f">' % (len(rows), fails, total),
    ]
    for name, dt, err in rows:
        lines.append('  <testcase classname="journey" name=%s time="%.2f"%s' % (
            quoteattr(name), dt, ">" if err else "/>"))
        if err:
            lines.append("    <failure message=%s/>" % quoteattr(err))
            lines.append("  </testcase>")
    lines.append("</testsuite>")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
