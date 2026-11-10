#!/usr/bin/env python3
"""Screen-recordable end-to-end tour of all three points of view.

Plays one marketplace job through its whole life, hands-free, so you can hit
record and watch it:

    admin     (headed Chromium)   login, overview, credential approve/reject,
                                  payment verification, completed job, payout,
                                  dispute resolution, audit log
    homeowner (iOS simulator)     onboarding, login, post job, matching (radar
                                  animation), match result, pay by bank transfer,
                                  confirm completion, review, dispute
    tradie    (iOS simulator)     login, dashboard, onboarding wizard, request
                                  detail + OfferCountdown, accept offer, check
                                  in, chat, check out, rate homeowner

The three actors take turns, choreographed through a small HTTP signal server
hosted by this script (mobile/integration_test/helpers/demo_helper.dart is the
Dart client, scripts/e2e-demo/admin_pov.mjs the browser one). Everything is
paced (--pace) with captions, a visible cursor and a console + timeline of what
is on screen. Anything the UI cannot do natively (native photo picker, LINZ
address lookup without a key) falls back to the API and is listed at the end.

Usage (repo root, `docker compose up` running, two iOS simulators available):

    python3 scripts/e2e-demo.py                    # 15s countdown, then play
    python3 scripts/e2e-demo.py --record           # screen-record the main display
    python3 scripts/e2e-demo.py --capture-sims     # save a PNG per scene per simulator
    python3 scripts/e2e-demo.py --record --capture-sims  # both
    python3 scripts/e2e-demo.py --single-flow      # happy path only (skip dispute)
    python3 scripts/e2e-demo.py --wait-enter       # start when you press Enter
    python3 scripts/e2e-demo.py --pace 5 --say     # slower, with spoken scene titles
    python3 scripts/e2e-demo.py --only-preflight   # check the environment, change nothing

Needs python3 (stdlib only), docker compose stack, Flutter, Xcode simulators,
node + web/node_modules with Playwright's Chromium. Screen recording needs
macOS Screen Recording permission for your terminal.
"""

from __future__ import annotations

import argparse
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
PG_USER = os.environ.get("POSTGRES_USER", "fixo")
PG_DB = os.environ.get("POSTGRES_DB", "fixo")
STAFF = ("staff@fixo.test", "Test1234!")
TRADIE = ("tradie-verified@fixo.test", "Test1234!")
DEMO_TRADIE = ("tradie@fixo.nz", "Demo1!Fixo")
CRED_PREFIX = "demo-tour-"

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


def set_availability(creds: tuple[str, str], available: bool) -> None:
    token = login(*creds)
    if token:
        http("POST", f"{API}/profile/availability", {"available": available}, token)


def psql(sql: str) -> str:
    proc = subprocess.run(
        ["docker", "compose", "exec", "-T", "db", "psql", "-U", PG_USER, "-d", PG_DB, "-tA",
         "-v", "ON_ERROR_STOP=1", "-c", sql],
        cwd=REPO, capture_output=True, text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip())
    return proc.stdout.strip()


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


def preflight(args) -> tuple[str, str]:
    log("demo", "preflight")
    status, _ = http("POST", f"{API}/auth/login", {})
    if status == 0:
        die(f"API not reachable at {API} — start the stack: `docker compose up -d`")
    if not Path(FLUTTER).exists() and not shutil.which(FLUTTER):
        die(f"flutter not found ({FLUTTER}); set FLUTTER_BIN")
    if not (WEB / "node_modules" / "@playwright").exists():
        die("web/node_modules missing Playwright — run `npm ci` in web/")
    if not any((Path.home() / "Library/Caches/ms-playwright").glob("chromium-*")):
        die("Playwright Chromium missing — run `npx playwright install chromium` in web/")
    seed = subprocess.run(["bash", str(REPO / "scripts/seed-test-accounts.sh")], cwd=REPO, capture_output=True, text=True)
    if seed.returncode != 0:
        die(f"seed-test-accounts.sh failed:\n{seed.stdout[-800:]}{seed.stderr[-400:]}")
    for label, creds in (("staff", STAFF), ("tradie", TRADIE)):
        if not login(*creds):
            die(f"cannot log in as {label} {creds[0]}")
    udids = pick_simulators(args)
    log("demo", f"homeowner sim {udids[0]} | tradie sim {udids[1]}")
    return udids


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


def seed_credentials() -> int:
    profile = psql(f"""select p."Id" from "TradieProfiles" p join "AspNetUsers" u on u."Id" = p."UserId"
                      where u."Email" = '{TRADIE[0]}';""")
    if not profile.isdigit():
        die("tradie-verified has no TradieProfile — run scripts/seed-test-accounts.sh")
    rows = ", ".join(
        f"({profile}, '{t}', 'credentials/{CRED_PREFIX}{t.lower()}.pdf', '{CRED_PREFIX}{t.lower()}.pdf', 'Pending')"
        for t in ("Insurance", "Certification")
    )
    psql(f'insert into "TradieCredentials" ("TradieProfileId","Type","FileKey","OriginalFileName","Status") values {rows};')
    return int(profile)


def seed_bank_details(profile: int) -> None:
    """Gives the test tradie payout bank details if it has none (does not
    overwrite anything real) so the admin's Process button is enabled."""
    psql(
        f'update "TradieProfiles" set "BankAccountName" = \'Tradie Verified\', '
        f'"BankAccountNumber" = \'12-3456-7890123-00\' '
        f'where "Id" = {profile} and ("BankAccountNumber" is null or "BankAccountNumber" = \'\');'
    )


def cleanup_credentials(profile: int | None) -> None:
    try:
        psql(f"""delete from "TradieCredentials" where "OriginalFileName" like '{CRED_PREFIX}%';""")
        if profile:
            psql(f"""update "TradieProfiles" set "IsVerified" = exists (select 1 from "TradieCredentials" c
                    where c."TradieProfileId" = {profile} and c."Status" = 'Approved') where "Id" = {profile};""")
    except RuntimeError as err:
        log("warn", f"credential cleanup failed: {err}")


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


def write_report(show: Show, run_dir: Path, ok: bool) -> None:
    (run_dir / "timeline.json").write_text(json.dumps({"ok": ok, "steps": show.steps, "notes": show.notes}, indent=2))
    lines = ["# e2e demo timeline", "", "| time | actor | scene |", "|---|---|---|"]
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
    ap.add_argument("--only-preflight", action="store_true")
    args = ap.parse_args()

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
    profile: int | None = None
    ok = False
    try:
        vite = ensure_web(args.web_port)
        set_availability(DEMO_TRADIE, False)
        set_availability(TRADIE, True)
        profile = seed_credentials()
        seed_bank_details(profile)
        log("demo", f"logs: {run_dir}")

        # Pass --single-flow through so the mobile test can skip the dispute step.
        dart = lambda persona: [  # noqa: E731
            FLUTTER, "test", "integration_test/demo_tour_test.dart", "--reporter", "expanded",
            "--device-id", homeowner_udid if persona == "homeowner" else tradie_udid,
            "--dart-define", f"FIXO_PERSONA={persona}", "--dart-define", f"DEMO_CTL={ctl}",
            "--dart-define", f"DEMO_PACE={int(args.pace)}", "--dart-define", f"DEMO_THEME={args.theme}",
            "--dart-define", f"DEMO_SINGLE_FLOW={'true' if args.single_flow else 'false'}",
            "--dart-define", "FIXO_DISABLE_PUSH=true",
        ]

        admin = Actor("admin", ["node", str(ADMIN_SCRIPT)], REPO, {
            **os.environ, "DEMO_CTL": ctl, "DEMO_PACE": str(args.pace), "DEMO_WINDOW": args.window,
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
        set_availability(DEMO_TRADIE, True)
        cleanup_credentials(profile)
        server.shutdown()
        write_report(show, run_dir, ok)

    print()
    log("demo", f"{'PASS' if ok else 'FAIL'} — {len(show.steps)} scenes in {show.stamp()}")
    if show.notes:
        log("demo", f"{len(show.notes)} API fallback(s) — see timeline.md")
    log("demo", f"timeline + logs: {run_dir}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
