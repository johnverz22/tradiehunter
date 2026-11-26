#!/usr/bin/env python3
"""Screen-recordable end-to-end tour of all three points of view.

Plays one marketplace job through its whole life, hands-free, so you can hit
record and watch it:

    admin     (headed Chromium)   login, overview, credential approve/reject,
                                  payment verification, completed job, payout,
                                  dispute resolution, audit log
    homeowner (iOS simulator)     onboarding, login, post job, matching (radar
                                  animation), booked job, approve itemised amount,
                                  pay by bank transfer, review, dispute
    tradie    (iOS simulator)     login, dashboard, onboarding wizard, request
                                  detail + OfferCountdown, accept offer, check
                                  in, chat, check out, rate homeowner

The three actors take turns, choreographed through a small HTTP signal server
hosted by this script (mobile/integration_test/helpers/demo_helper.dart is the
Dart client, scripts/e2e-demo/admin_pov.mjs the browser one). Everything is
paced (--pace) with captions, a visible cursor and a console + timeline of what
is on screen. Anything the UI cannot do natively (native photo picker, LINZ
address lookup without a key) falls back to the API and is listed at the end.

Accounts: the demo runs on the persona fabric (docs/todos/08_e2e_persona_fabric_plan.md),
not the seeded *@fixo.test accounts. It provisions a fresh run through
scripts/e2e-personas.py (real signup / OTP / credential review, no DB writes),
hands the manifest to every actor (E2E_MANIFEST), records the demo jobs in the
manifest's `jobs` array (scenario "demo" / "demo-dispute", same shape as
e2e-journey.py's record_job) and deactivates the run's accounts on exit.
The homeowner's job is a direct request to the manifest tradie (the same path
e2e-journey.py uses), because the post-job form needs LINZ_API_KEY and quick
match would offer the job to a seeded tradie instead.

Usage (repo root, `docker compose up` + MailHog running, two iOS simulators):

    python3 scripts/e2e-demo.py                    # provision personas, 15s countdown, play
    python3 scripts/e2e-demo.py --manifest PATH    # reuse an existing fabric run (not deactivated on exit)
    python3 scripts/e2e-demo.py --keep-accounts    # leave the provisioned accounts active
    python3 scripts/e2e-demo.py --cleanup --manifest PATH   # deactivate that run's accounts and exit
    python3 scripts/e2e-demo.py --record           # screen-record the main display
    python3 scripts/e2e-demo.py --capture-sims     # save a PNG per scene per simulator
    python3 scripts/e2e-demo.py --record --capture-sims  # both
    python3 scripts/e2e-demo.py --single-flow      # happy path only (skip dispute)
    python3 scripts/e2e-demo.py --wait-enter       # start when you press Enter
    python3 scripts/e2e-demo.py --pace 5 --say     # slower, with spoken scene titles
    python3 scripts/e2e-demo.py --only-preflight   # check the environment, change nothing

Needs python3 (stdlib only), docker compose stack + MailHog, Flutter, Xcode simulators,
node + web/node_modules with Playwright's Chromium. Screen recording needs
macOS Screen Recording permission for your terminal.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import re
import shutil
import signal as os_signal
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
MOBILE = REPO / "mobile"
WEB = REPO / "web"
ADMIN_SCRIPT = REPO / "scripts" / "e2e-demo" / "admin_pov.mjs"

API = os.environ.get("FIXO_API_URL", "http://localhost:5000").rstrip("/") + "/api"
FLUTTER = os.environ.get("FLUTTER_BIN") or shutil.which("flutter") or str(Path.home() / "Develop/flutter/bin/flutter")
CRED_PREFIX = "demo-tour-"  # file-name marker; admin_pov.mjs only touches credential rows carrying it
# Signal-server data key -> scenario recorded in the manifest's `jobs` array.
DEMO_JOB_SCENARIOS = {"job": "demo", "dispute_job": "demo-dispute"}


def _load_script(name: str, filename: str):
    """Import a hyphen-named sibling script so the demo reuses the fabric's own helpers."""
    spec = importlib.util.spec_from_file_location(name, REPO / "scripts" / filename)
    mod = importlib.util.module_from_spec(spec)  # type: ignore[arg-type]
    sys.modules[name] = mod
    spec.loader.exec_module(mod)  # type: ignore[union-attr]
    return mod


PERSONAS = _load_script("e2e_personas", "e2e-personas.py")  # provisioning, credential upload, payout details
JOURNEY = _load_script("e2e_journey", "e2e-journey.py")  # apply_manifest / record_job

COLORS = {"admin": "35", "homeowner": "36", "tradie": "33", "demo": "32", "warn": "31"}


def paint(tag: str, text: str) -> str:
    code = COLORS.get(tag, "37")
    return f"\033[{code}m{text}\033[0m" if sys.stdout.isatty() else text


def log(tag: str, message: str) -> None:
    print(f"{paint(tag, f'[{tag:<9}]')} {message}", flush=True)


def die(message: str) -> None:
    print(paint("warn", f"\nERROR: {message}"), file=sys.stderr)
    sys.exit(2)


# ── Signal server ──────────────────────────────────────────────────────────────


class Show:
    """Shared state + timeline for one run."""

    def __init__(self, say: bool):
        self.lock = threading.Lock()
        self.signals: dict[str, float] = {}
        self.data: dict[str, str] = {}
        self.steps: list[dict] = []
        self.notes: list[dict] = []
        self.t0: float | None = None
        self.say = say
        # step_callbacks are called with the step dict on every new step signal.
        self.step_callbacks: list = []
        # on_data(key, value) runs BEFORE a data value is published, so a consumer
        # that sees the value can rely on side effects (manifest job record) being done.
        self.on_data = None

    def add_note(self, actor: str, message: str) -> None:
        self.notes.append({"t": round(self.offset(), 1), "actor": actor, "message": message})
        log("warn", f"{self.stamp()}  [{actor}] fallback: {message}")

    def offset(self) -> float:
        return 0.0 if self.t0 is None else time.time() - self.t0

    def stamp(self) -> str:
        o = int(self.offset())
        return f"+{o // 60:02d}:{o % 60:02d}"

    def snapshot(self) -> dict:
        with self.lock:
            return {"signals": dict(self.signals), "data": dict(self.data)}


def make_handler(show: Show):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def _send(self, payload: dict) -> None:
            raw = json.dumps(payload).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)

        def _body(self) -> dict:
            n = int(self.headers.get("Content-Length") or 0)
            try:
                return json.loads(self.rfile.read(n) or b"{}") if n else {}
            except json.JSONDecodeError:
                return {}

        def do_GET(self):
            self._send(show.snapshot())

        def do_POST(self):
            parts = self.path.strip("/").split("/")
            body = self._body()
            kind = parts[0]
            if kind == "data" and len(parts) == 2 and show.on_data:
                try:
                    show.on_data(parts[1], str(body.get("value", "")))
                except Exception as err:  # noqa: BLE001 - never stall the show for bookkeeping
                    log("warn", f"manifest job record failed for {parts[1]}: {err}")
            with show.lock:
                if kind == "signal" and len(parts) == 2:
                    show.signals.setdefault(parts[1], time.time())
                elif kind == "data" and len(parts) == 2:
                    show.data[parts[1]] = str(body.get("value", ""))
            if kind == "step":
                actor, title = body.get("actor", "?"), body.get("title", "")
                step = {"t": round(show.offset(), 1), "actor": actor, "title": title}
                show.steps.append(step)
                log(actor if actor in COLORS else "demo", f"{show.stamp()}  {title}")
                if show.say and show.t0 is not None:
                    subprocess.Popen(["say", re.sub(r"^\w+:\s*", "", title)], stderr=subprocess.DEVNULL)
                for cb in show.step_callbacks:
                    try:
                        cb(step)
                    except Exception:  # noqa: BLE001
                        pass
            elif kind == "note":
                actor, msg = body.get("actor", "?"), body.get("message", "")
                show.notes.append({"t": round(show.offset(), 1), "actor": actor, "message": msg})
                log("warn", f"{show.stamp()}  [{actor}] fallback: {msg}")
            self._send({"ok": True})

    return Handler


# ── HTTP / shell helpers ───────────────────────────────────────────────────────


def http(method: str, url: str, body: object = None, token: str | None = None, timeout: float = 15):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    if data is not None:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode()
            try:
                return resp.status, (json.loads(raw) if raw else None)
            except json.JSONDecodeError:
                return resp.status, raw
    except urllib.error.HTTPError as err:
        raw = err.read().decode()
        try:
            return err.code, json.loads(raw) if raw else None
        except json.JSONDecodeError:
            return err.code, raw
    except (urllib.error.URLError, OSError):
        return 0, None


def login(email: str, password: str) -> str | None:
    status, body = http("POST", f"{API}/auth/login", {"email": email, "password": password})
    return body.get("token") if status == 200 and isinstance(body, dict) else None


# ── Simulator screenshot capture ───────────────────────────────────────────────


def capture_sim(udid: str, out_path: Path) -> None:
    """Fire-and-forget xcrun simctl screenshot.  Errors are silently dropped —
    a missed frame is never worth stalling the demo for."""
    try:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        subprocess.Popen(
            ["xcrun", "simctl", "io", udid, "screenshot", str(out_path)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    except Exception:  # noqa: BLE001
        pass


def make_sim_capture_callback(
    show: Show, run_dir: Path, homeowner_udid: str, tradie_udid: str
):
    """Returns a step_callback that fires xcrun simctl screenshot for the right
    simulator(s) ~1 s after every scene change so the app has settled."""
    actor_udid = {"homeowner": homeowner_udid, "tradie": tradie_udid}
    counters: dict[str, int] = {"homeowner": 0, "tradie": 0}

    def _callback(step: dict) -> None:
        actor = step.get("actor", "")
        udid = actor_udid.get(actor)
        if udid is None:
            return
        # Give the simulator ~1 s to paint the new screen before capturing.
        counters[actor] = counters.get(actor, 0) + 1
        idx = counters[actor]
        slug = re.sub(r"[^\w]+", "_", step.get("title", "scene")).strip("_").lower()[:48]
        out = run_dir / "sim-shots" / actor / f"{idx:02d}_{slug}.png"

        def _fire():
            time.sleep(1.0)
            capture_sim(udid, out)
            log("demo", f"[sim-shot] {out.relative_to(run_dir)}")

        threading.Thread(target=_fire, daemon=True).start()

    return _callback


# ── Environment ────────────────────────────────────────────────────────────────


def booted_simulators() -> list[tuple[str, str]]:
    out = subprocess.run(["xcrun", "simctl", "list", "devices", "booted", "-j"], capture_output=True, text=True).stdout
    devices = json.loads(out or "{}").get("devices", {})
    return [(d["name"], d["udid"]) for group in devices.values() for d in group if d.get("state") == "Booted"]


def pick_simulators(args) -> tuple[str, str]:
    """Returns (homeowner_udid, tradie_udid)."""
    if args.homeowner_udid and args.tradie_udid:
        return args.homeowner_udid, args.tradie_udid
    sims = booted_simulators()
    if len(sims) < 2:
        die("need two booted iOS simulators (open two in Simulator.app, or pass --homeowner-udid/--tradie-udid)."
            f" Booted: {sims or 'none'}")
    big = [s for s in sims if "Max" in s[0] or "Plus" in s[0]]
    homeowner = args.homeowner_udid or (big[0] if big else sims[0])[1]
    tradie = args.tradie_udid or next(u for _, u in sims if u != homeowner)
    return homeowner, tradie


# ── Persona fabric ─────────────────────────────────────────────────────────────


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


def preflight(args) -> tuple[str, str]:
    log("demo", "preflight")
    require_local_stack()
    status, _ = http("POST", f"{API}/auth/login", {})
    if status == 0:
        die(f"API not reachable at {API} — start the stack: `docker compose up -d`")
    if not Path(FLUTTER).exists() and not shutil.which(FLUTTER):
        die(f"flutter not found ({FLUTTER}); set FLUTTER_BIN")
    if not (WEB / "node_modules" / "@playwright").exists():
        die("web/node_modules missing Playwright — run `npm ci` in web/")
    if not any((Path.home() / "Library/Caches/ms-playwright").glob("chromium-*")):
        die("Playwright Chromium missing — run `npx playwright install chromium` in web/")
    if args.manifest:
        manifest = load_manifest(Path(args.manifest))
        for w in check_fabric(manifest):
            log("demo", f"note: {w}")
        log("demo", f"manifest OK: run {manifest.get('runId')} ({args.manifest})")
    else:
        # Fresh provisioning needs MailHog (OTP + staff invite mails) and the superadmin login.
        if http("GET", f"{PERSONAS.mailhog_base()}/api/v2/messages?limit=1")[0] != 200:
            die(f"MailHog not reachable at {PERSONAS.mailhog_base()} — e2e-personas.py reads OTPs from it "
                "(`docker compose up -d`), or pass --manifest PATH to reuse a fabric run")
        try:
            PERSONAS.admin_login()
        except PERSONAS.Unreachable as err:
            die(str(err))
        log("demo", "personas will be provisioned fresh (scripts/e2e-personas.py --staff 1)")
    udids = pick_simulators(args)
    log("demo", f"homeowner sim {udids[0]} | tradie sim {udids[1]}")
    return udids


def provision_fabric(run_dir: Path) -> Path:
    """Runs e2e-personas.py for this demo run and returns the manifest path it reports."""
    run_id = "demo" + time.strftime("%m%d%H%M%S")
    cmd = [sys.executable, str(REPO / "scripts" / "e2e-personas.py"), "--run-id", run_id,
           "--homeowners", "1", "--tradies", "1", "--staff", "1", "--retry", "2"]
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


def prepare_fabric(manifest: dict, show: Show) -> None:
    """Fills gaps the demo needs, strictly through the API (never SQL), and reports each as a fallback."""
    tr = persona_of(manifest, "tradie")
    jwt = login(tr["email"], tr["password"])
    try:
        prof = http("GET", f"{API}/profile", token=jwt)[1] or {}
        if prof.get("isAvailable") is False:
            http("POST", f"{API}/profile/availability", {"available": True}, jwt)
            show.add_note("demo", "tradie availability set to true through POST /profile/availability "
                                  "(manifest persona was unavailable)")
        if PERSONAS.ensure_payout_details(jwt, tr):
            show.add_note("demo", "tradie payout bank details added through PUT /profile "
                                  "(manifest persona had none; admin payout scene needs them) — fabric gap, "
                                  "fixed in e2e-personas.py for new runs")
        # Two PENDING credentials for the admin's approve/reject scene. Fabric personas arrive
        # already verified (one approved credential), so these only add queue rows; the tradie stays
        # verified. Uploaded as the tradie through the real route: the native file picker can't be driven.
        for cred_type in ("Insurance", "Certification"):
            PERSONAS.upload_credential(jwt, f"{CRED_PREFIX}{cred_type.lower()}.png", cred_type,
                                       f"demo-{manifest.get('runId')}-{cred_type.lower()}")
        show.add_note("demo", "two pending tradie credentials uploaded through POST /tradie/credentials "
                              "(native file picker can't be driven) for the admin approve/reject scene")
    except (PERSONAS.StepFailed, PERSONAS.Unreachable) as err:
        raise RuntimeError(f"preparing the fabric personas failed: {err}") from err


def make_job_recorder(manifest_path: Path):
    """on_data hook: append demo job ids to the manifest with e2e-journey.py's own record_job."""
    lock = threading.Lock()

    def record(key: str, value: str) -> None:
        scenario = DEMO_JOB_SCENARIOS.get(key)
        if not scenario or not value.isdigit():
            return
        with lock:
            JOURNEY.apply_manifest(str(manifest_path))  # binds HOMEOWNER/TRADIE + MANIFEST_PATH
            if any(j.get("id") == int(value) for j in JOURNEY._read_manifest(str(manifest_path)).get("jobs", [])):
                return
            JOURNEY.record_job(int(value), scenario)
            log("demo", f"recorded job {value} in manifest as scenario '{scenario}'")

    return record


# ── Admin web ──────────────────────────────────────────────────────────────────


def ensure_web(port: int) -> subprocess.Popen | None:
    url = f"http://localhost:{port}"
    if http("GET", url)[0] == 200:
        log("demo", f"web console already serving on {url}")
        return None
    log("demo", f"starting admin web on {url}")
    proc = subprocess.Popen(
        ["npx", "vite", "--port", str(port), "--strictPort", "--config", "vite.e2e.config.ts"],
        cwd=WEB, env={**os.environ, "VITE_API_URL": "/api"},
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    deadline = time.time() + 60
    while time.time() < deadline:
        if http("GET", url)[0] == 200:
            return proc
        if proc.poll() is not None:
            break
        time.sleep(1)
    proc.terminate()
    die("admin web did not start (is the port taken by another dev server? use --web-port)")


# ── Processes ──────────────────────────────────────────────────────────────────


class Actor:
    def __init__(self, name: str, cmd: list[str], cwd: Path, env: dict, logfile: Path):
        self.name = name
        self.log_path = logfile
        self.proc = subprocess.Popen(cmd, cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                     text=True, bufsize=1, start_new_session=True)
        self.tail: list[str] = []
        threading.Thread(target=self._pump, daemon=True).start()

    def _pump(self) -> None:
        with open(self.log_path, "w") as fh:
            for line in self.proc.stdout:  # type: ignore[union-attr]
                fh.write(line)
                fh.flush()
                self.tail = (self.tail + [line.rstrip()])[-25:]

    def alive(self) -> bool:
        return self.proc.poll() is None

    def stop(self) -> None:
        if self.alive():
            try:
                os.killpg(self.proc.pid, os_signal.SIGTERM)
            except ProcessLookupError:
                pass


def wait_for(show: Show, signal_name: str, actors: list[Actor], timeout: float, what: str) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        if signal_name in show.snapshot()["signals"]:
            return
        for a in actors:
            if not a.alive():
                raise RuntimeError(f"{a.name} exited before '{signal_name}'\n  " + "\n  ".join(a.tail[-12:]))
        time.sleep(0.5)
    raise RuntimeError(f"timed out waiting for {what}")


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


# ── Main ───────────────────────────────────────────────────────────────────────


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pace", type=float, default=3, help="seconds each screen is held (default 3)")
    ap.add_argument("--countdown", type=int, default=15, help="seconds between 'ready' and the first scene (default 15)")
    ap.add_argument("--wait-enter", action="store_true", help="start when you press Enter instead of a countdown")
    ap.add_argument("--record", action="store_true", help="screen-record the main display with `screencapture -v`")
    ap.add_argument("--capture-sims", action="store_true",
                    help="save a PNG per scene per simulator using xcrun simctl io screenshot")
    ap.add_argument("--single-flow", action="store_true",
                    help="happy-path only: skip the dispute sub-flow so the demo ends at the homeowner review")
    ap.add_argument("--say", action="store_true", help="speak each scene title with macOS `say`")
    ap.add_argument("--theme", choices=["light", "dark"], default="light", help="mobile theme (default light)")
    ap.add_argument("--homeowner-udid")
    ap.add_argument("--tradie-udid")
    ap.add_argument("--web-port", type=int, default=8090)
    ap.add_argument("--port", type=int, default=5099, help="signal server port")
    ap.add_argument("--window", default="1280x860+0+0", help="admin browser window WxH+X+Y")
    ap.add_argument("--no-arrange", action="store_true", help="don't try to position simulator windows")
    ap.add_argument("--build-timeout", type=int, default=900, help="seconds allowed for each simulator build")
    ap.add_argument("--only-preflight", action="store_true", help="check the environment, change nothing")
    ap.add_argument("--manifest", metavar="PATH",
                    help="reuse an existing persona-fabric manifest instead of provisioning a new run "
                         "(its accounts are not deactivated on exit)")
    ap.add_argument("--keep-accounts", action="store_true",
                    help="don't deactivate the accounts this run provisioned when it exits")
    ap.add_argument("--cleanup", action="store_true",
                    help="with --manifest PATH: deactivate that run's accounts (e2e-personas.py --cleanup) and exit")
    args = ap.parse_args()

    if args.cleanup:
        if not args.manifest:
            die("--cleanup needs --manifest PATH (the run printed it, and timeline.md records it)")
        require_local_stack()
        return 0 if cleanup_fabric(Path(args.manifest).resolve()) else 1

    homeowner_udid, tradie_udid = preflight(args)
    if args.only_preflight:
        log("demo", "preflight OK")
        return 0

    run_dir = Path(tempfile.gettempdir()) / "fixo-e2e-demo" / time.strftime("%Y%m%d-%H%M%S")
    run_dir.mkdir(parents=True, exist_ok=True)
    show = Show(args.say)
    server = ThreadingHTTPServer(("0.0.0.0", args.port), make_handler(show))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    ctl = f"http://127.0.0.1:{args.port}"

    # Register the per-step simulator screenshot callback when requested.
    if args.capture_sims:
        show.step_callbacks.append(
            make_sim_capture_callback(show, run_dir, homeowner_udid, tradie_udid)
        )
        log("demo", f"sim-shots -> {run_dir / 'sim-shots'}/")

    actors: list[Actor] = []
    vite: subprocess.Popen | None = None
    recorder: subprocess.Popen | None = None
    manifest_path: Path | None = None
    provisioned = False
    ok = False
    try:
        vite = ensure_web(args.web_port)
        log("demo", f"logs: {run_dir}")
        if args.manifest:
            manifest_path = Path(args.manifest).resolve()
        else:
            manifest_path = provision_fabric(run_dir)
            provisioned = True
        manifest = load_manifest(manifest_path)
        log("demo", f"persona fabric run {manifest.get('runId')} -> {manifest_path}")
        prepare_fabric(manifest, show)
        show.on_data = make_job_recorder(manifest_path)

        # Pass --single-flow through so the mobile test can skip the dispute step.
        dart = lambda persona: [  # noqa: E731
            FLUTTER, "test", "integration_test/demo_tour_test.dart", "--reporter", "expanded",
            "--device-id", homeowner_udid if persona == "homeowner" else tradie_udid,
            "--dart-define", f"FIXO_PERSONA={persona}", "--dart-define", f"E2E_MANIFEST={manifest_path}",
            "--dart-define", f"DEMO_CTL={ctl}",
            "--dart-define", f"DEMO_PACE={int(args.pace)}", "--dart-define", f"DEMO_THEME={args.theme}",
            "--dart-define", f"DEMO_SINGLE_FLOW={'true' if args.single_flow else 'false'}",
            "--dart-define", "FIXO_DISABLE_PUSH=true",
        ]

        admin = Actor("admin", ["node", str(ADMIN_SCRIPT)], REPO, {
            **os.environ, "E2E_MANIFEST": str(manifest_path), "DEMO_CTL": ctl, "DEMO_PACE": str(args.pace), "DEMO_WINDOW": args.window,
            "DEMO_WEB_URL": f"http://localhost:{args.web_port}", "DEMO_API_URL": API,
            "DEMO_SINGLE_FLOW": "true" if args.single_flow else "false",
        }, run_dir / "admin.log")
        actors.append(admin)
        wait_for(show, "admin_ready", actors, 120, "the admin browser")
        log("admin", "browser ready")

        # Flutter builds share mobile/build, so bring the simulators up one at a time.
        for persona in ("homeowner", "tradie"):
            log(persona, "building + launching app (first run can take minutes)…")
            a = Actor(persona, dart(persona), MOBILE, {**os.environ}, run_dir / f"{persona}.log")
            actors.append(a)
            wait_for(show, f"{persona}_ready", actors, args.build_timeout, f"the {persona} simulator")
            log(persona, "app ready at login")

        if not args.no_arrange:
            try:
                arrange_windows(homeowner_udid, tradie_udid)
            except Exception:  # noqa: BLE001 - cosmetic only
                pass

        if args.wait_enter:
            input(paint("demo", "\nAll three screens are ready. Start your recording, then press Enter to play… "))
        else:
            print(paint("demo", f"\nAll three screens are ready. Recording starts in {args.countdown}s — hit record now."))
            for i in range(args.countdown, 0, -1):
                print(f"\r  {i:>2}s ", end="", flush=True)
                time.sleep(1)
            print()
        if args.record:
            out = run_dir / "recording.mov"
            recorder = subprocess.Popen(["screencapture", "-v", "-x", str(out)], stderr=subprocess.DEVNULL)
            time.sleep(2)
            log("demo", f"recording -> {out}")

        show.t0 = time.time()
        http("POST", f"{ctl}/signal/go")
        log("demo", "▶ go")

        # In single-flow mode, the dispute step is skipped, so we only need
        # tradie_done (not dispute_opened / admin_done from the dispute branch).
        while True:
            snap = show.snapshot()["signals"]
            if args.single_flow:
                if "homeowner_done" in snap and "tradie_done" in snap:
                    break
            else:
                if "admin_done" in snap and "tradie_done" in snap:
                    break
            for a in actors:
                if not a.alive() and f"{a.name}_done" not in snap and a.proc.returncode not in (0, None):
                    raise RuntimeError(f"{a.name} failed (exit {a.proc.returncode})\n  " + "\n  ".join(a.tail[-15:]))
            time.sleep(1)
        # let the mobile tests finish their last beat and exit cleanly
        for a in actors:
            try:
                a.proc.wait(timeout=60)
            except subprocess.TimeoutExpired:
                pass
        ok = all(a.proc.returncode in (0, None) for a in actors)
    except KeyboardInterrupt:
        log("warn", "interrupted")
    except RuntimeError as err:
        log("warn", str(err))
    finally:
        if recorder:
            recorder.send_signal(os_signal.SIGINT)
            try:
                recorder.wait(timeout=20)
            except subprocess.TimeoutExpired:
                recorder.kill()
        for a in actors:
            a.stop()
        if vite:
            vite.terminate()
        server.shutdown()
        write_report(show, run_dir, ok, manifest_path, provisioned)
        if provisioned and manifest_path and not args.keep_accounts:
            cleanup_fabric(manifest_path)

    print()
    log("demo", f"{'PASS' if ok else 'FAIL'} — {len(show.steps)} scenes in {show.stamp()}")
    if show.notes:
        log("demo", f"{len(show.notes)} API fallback(s) — see timeline.md")
    log("demo", f"timeline + logs: {run_dir}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
