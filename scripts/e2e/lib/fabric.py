"""Persona-fabric glue (moved from scripts/e2e-demo.py, plan 12 U1.1).

Provisions / reuses / cleans up a fabric run through scripts/e2e-personas.py (real signup,
OTP and credential review, never DB writes) and records flow jobs in the manifest.
`PERSONAS` is the loaded e2e-personas.py module (hyphenated file name, so imported by path).
"""
from __future__ import annotations

import importlib.util
import json
import os
import re
import subprocess
import sys
import threading
import time
from pathlib import Path

from . import REPO, SCRIPTS
from .api import API, http, try_login as login
from .stage import die, log


def _load_script(name: str, filename: str):
    """Import a hyphen-named sibling script so flows reuse the fabric's own helpers."""
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / filename)
    mod = importlib.util.module_from_spec(spec)  # type: ignore[arg-type]
    sys.modules[name] = mod
    spec.loader.exec_module(mod)  # type: ignore[union-attr]
    return mod


PERSONAS = _load_script("e2e_personas", "e2e-personas.py")  # provisioning, credential upload, payout details

def require_local_stack() -> None:
    """Same safety rule as the fabric: local docker stack only."""
    try:
        PERSONAS.api_base()
        PERSONAS.mailhog_base()
    except PERSONAS.Unreachable as err:
        die(str(err))


def load_manifest(path: Path) -> dict:
    try:
        m = json.loads(Path(path).read_text())
    except (OSError, ValueError) as err:
        die(f"cannot read manifest {path}: {err}")
    if m.get("schemaVersion") != 1:
        die(f"manifest {path} has schemaVersion {m.get('schemaVersion')!r}, expected 1")
    missing = [r for r in ("homeowner", "tradie", "staff") if persona_of(m, r) is None]
    if missing:
        die(f"manifest {path} has no {'/'.join(missing)} persona — the demo needs staff for the admin scenes "
            "(provision with e2e-personas.py --staff 1)")
    return m


def persona_of(manifest: dict, role: str) -> dict | None:
    return next((p for p in manifest.get("personas", []) if p.get("role") == role), None)


def check_fabric(manifest: dict) -> list[str]:
    """Read-only: every persona must log in and the tradie must be verified. Returns warnings."""
    warnings: list[str] = []
    tokens = {}
    for role in ("staff", "homeowner", "tradie"):
        p = persona_of(manifest, role)
        tokens[role] = login(p["email"], p["password"])
        if not tokens[role]:
            die(f"cannot log in as manifest {role} {p['email']} (deactivated by --cleanup? re-provision)")
    prof = http("GET", f"{API}/profile", token=tokens["tradie"])[1] or {}
    if prof.get("isVerified") is not True:
        die("manifest tradie is not verified — fabric personas must hold an approved credential")
    if prof.get("isAvailable") is False:
        warnings.append("manifest tradie is unavailable; the demo will set availability through the API")
    if not prof.get("bankAccountNumber"):
        warnings.append("manifest tradie has no payout bank details; the demo will add them through the API "
                        "(e2e-personas.py ensure_payout_details) so the admin payout scene can run")
    return warnings


def provision_fabric(run_dir: Path, run_prefix: str = "demo", homeowners: int = 1, tradies: int = 1,
                     staff: int = 1) -> Path:
    """Runs e2e-personas.py for this run and returns the manifest path it reports.

    Per-flow sizing (plan 12 U2.3) passes the minimum persona counts; defaults match the old demo."""
    run_id = run_prefix + time.strftime("%m%d%H%M%S")
    cmd = [sys.executable, str(REPO / "scripts" / "e2e-personas.py"), "--run-id", run_id,
           "--homeowners", str(homeowners), "--tradies", str(tradies), "--staff", str(staff), "--retry", "2"]
    log("demo", f"provisioning personas: {' '.join(cmd[1:])}")
    proc = subprocess.Popen(cmd, cwd=REPO, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    lines: list[str] = []
    for line in proc.stdout:  # type: ignore[union-attr]
        lines.append(line.rstrip())
        if line.strip():
            log("demo", f"personas | {line.rstrip()}")
    proc.wait()
    (run_dir / "personas.log").write_text("\n".join(lines) + "\n")
    found = re.search(r"^MANIFEST=(.+)$", "\n".join(lines), re.M)
    if proc.returncode != 0 or not found:
        partial = re.search(r"partial manifest: (.+?)\)", "\n".join(lines))
        if partial and Path(partial.group(1)).is_file():  # don't leave half a run active
            cleanup_fabric(Path(partial.group(1)))
        die(f"persona provisioning failed (exit {proc.returncode}); see {run_dir / 'personas.log'}")
    return Path(found.group(1)).resolve()


def cleanup_fabric(manifest_path: Path) -> bool:
    """e2e-personas.py --cleanup: deactivates the run's qa+ accounts (rows stay, logins stop)."""
    log("demo", f"deactivating personas of {manifest_path}")
    proc = subprocess.run([sys.executable, str(REPO / "scripts" / "e2e-personas.py"), "--cleanup", str(manifest_path)],
                          cwd=REPO, capture_output=True, text=True)
    for line in (proc.stdout + proc.stderr).splitlines():
        if line.strip():
            log("demo", f"cleanup | {line}")
    if proc.returncode != 0:
        log("warn", f"persona cleanup reported failures (exit {proc.returncode})")
    return proc.returncode == 0


# ── Manifest job recording ─────────────────────────────────────────────────────


def record_job(manifest_path: Path, job_id: int, scenario: str) -> bool:
    """Append a job to the manifest's `jobs` array (same shape as e2e-journey.py's record_job:
    {id, scenario, homeownerEmail, tradieEmail} of the first persona of each role). Atomic write.
    Returns False when the job was already recorded."""
    path = str(manifest_path)
    with open(path) as fh:
        m = json.load(fh)
    if any(j.get("id") == job_id for j in m.get("jobs", [])):
        return False
    ho, tr = persona_of(m, "homeowner"), persona_of(m, "tradie")
    m.setdefault("jobs", []).append(
        {"id": job_id, "scenario": scenario, "homeownerEmail": ho["email"], "tradieEmail": tr["email"]}
    )
    tmp = path + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(m, fh, indent=2)
        fh.write("\n")
    os.replace(tmp, path)
    return True


def make_job_recorder(manifest_path: Path, scenarios: dict[str, str]):
    """on_data hook: `scenarios` maps a signal-server data key to the scenario name recorded in the
    manifest (e.g. {"job": "demo", "dispute_job": "demo-dispute"})."""
    lock = threading.Lock()

    def record(key: str, value: str) -> None:
        scenario = scenarios.get(key)
        if not scenario or not value.isdigit():
            return
        with lock:
            if record_job(manifest_path, int(value), scenario):
                log("demo", f"recorded job {value} in manifest as scenario '{scenario}'")

    return record
