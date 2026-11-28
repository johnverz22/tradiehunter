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
lib/fabric.py's record_job, same shape as e2e-journey.py) and deactivates the run's accounts on exit.
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
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # scripts/ -> `e2e` package

from e2e.lib import MOBILE, REPO, WEB  # noqa: E402
from e2e.lib.api import API, http, try_login as login  # noqa: E402
from e2e.lib.fabric import (  # noqa: E402
    PERSONAS, check_fabric, cleanup_fabric, load_manifest, make_job_recorder, persona_of,
    provision_fabric, require_local_stack,
)
from e2e.lib.report import write_report  # noqa: E402
from e2e.lib.sims import arrange_windows, pick_simulators  # noqa: E402
from e2e.lib.stage import (  # noqa: E402
    Actor, Show, die, ensure_web, log, make_sim_capture_callback, paint, start_recording,
    start_signal_server, stop_recording, wait_for,
)

ADMIN_SCRIPT = REPO / "scripts" / "e2e-demo" / "admin_pov.mjs"

FLUTTER = os.environ.get("FLUTTER_BIN") or shutil.which("flutter") or str(Path.home() / "Develop/flutter/bin/flutter")
CRED_PREFIX = "demo-tour-"  # file-name marker; admin_pov.mjs only touches credential rows carrying it
# Signal-server data key -> scenario recorded in the manifest's `jobs` array.
DEMO_JOB_SCENARIOS = {"job": "demo", "dispute_job": "demo-dispute"}


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
    udids = pick_simulators(args.homeowner_udid, args.tradie_udid)
    log("demo", f"homeowner sim {udids[0]} | tradie sim {udids[1]}")
    return udids


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
    server = start_signal_server(show, args.port)
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
        show.on_data = make_job_recorder(manifest_path, DEMO_JOB_SCENARIOS)

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
            recorder = start_recording(run_dir / "recording.mov")

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
        stop_recording(recorder)
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
