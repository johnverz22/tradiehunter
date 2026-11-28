"""Stage machinery shared by every flow (moved from scripts/e2e-demo.py, plan 12 U1.1).

Console log, the HTTP signal server the actors choreograph through, the Show timeline,
per-scene simulator screenshots, admin web dev server, actor subprocesses, screen recording.
Behaviour is unchanged from the demo; only `start_recording`/`stop_recording` are extracted
from main() so every flow gets `--record` from one place.
"""
from __future__ import annotations

import json
import os
import re
import signal as os_signal
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from . import WEB
from .api import http

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


# ── Screen recording / server ──────────────────────────────────────────────────


def start_recording(out: Path) -> subprocess.Popen:
    """`screencapture -v` of the main display (needs macOS Screen Recording permission)."""
    recorder = subprocess.Popen(["screencapture", "-v", "-x", str(out)], stderr=subprocess.DEVNULL)
    time.sleep(2)
    log("demo", f"recording -> {out}")
    return recorder


def stop_recording(recorder: subprocess.Popen | None) -> None:
    if not recorder:
        return
    recorder.send_signal(os_signal.SIGINT)
    try:
        recorder.wait(timeout=20)
    except subprocess.TimeoutExpired:
        recorder.kill()


def start_signal_server(show: Show, port: int) -> ThreadingHTTPServer:
    server = ThreadingHTTPServer(("0.0.0.0", port), make_handler(show))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server
