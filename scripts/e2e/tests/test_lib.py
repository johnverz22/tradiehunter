"""Self-tests for scripts/e2e/lib (stdlib unittest, no stack needed).

    python3 -m unittest discover -s scripts/e2e/tests -t scripts -v
"""
import json
import tempfile
import threading
import unittest
from decimal import Decimal
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from unittest import mock

from e2e.lib import api, asserts, fabric, report, stage


class _Fake(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def _reply(self, code, payload):
        raw = json.dumps(payload).encode() if payload is not None else b""
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        if self.path.endswith("/money"):
            body = b'{"labour": 85.5, "final": 90}'
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif self.path.endswith("/boom"):
            self._reply(409, {"error": "nope"})
        else:
            self._reply(204, None)

    def do_POST(self):
        n = int(self.headers.get("Content-Length") or 0)
        body = json.loads(self.rfile.read(n) or b"{}")
        if body.get("password") == "good":
            self._reply(200, {"token": "tok"})
        else:
            self._reply(401, {"error": "bad"})


class ApiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.srv = ThreadingHTTPServer(("127.0.0.1", 0), _Fake)
        threading.Thread(target=cls.srv.serve_forever, daemon=True).start()
        cls.base = f"http://127.0.0.1:{cls.srv.server_address[1]}"

    @classmethod
    def tearDownClass(cls):
        cls.srv.shutdown()
        cls.srv.server_close()

    def setUp(self):
        p = mock.patch.object(api, "API", self.base + "/api")
        p.start()
        self.addCleanup(p.stop)

    def test_money_parses_as_decimal(self):
        out = api.get("/money")
        self.assertEqual(out["labour"], Decimal("85.5"))
        self.assertEqual(asserts.dec(out["final"]), Decimal(90))

    def test_http_error_raises_step_failed(self):
        with self.assertRaises(api.StepFailed):
            api.get("/boom")

    def test_204_is_none(self):
        self.assertIsNone(api.get("/empty"))

    def test_unreachable(self):
        with mock.patch.object(api, "API", "http://127.0.0.1:1/api"):
            with self.assertRaises(api.Unreachable):
                api.get("/x")
            self.assertEqual(api.http("GET", "http://127.0.0.1:1/")[0], 0)

    def test_login_paths(self):
        self.assertEqual(api.login(("a@b.c", "good")), "tok")
        with self.assertRaises(api.Unreachable):
            api.login(("a@b.c", "bad"))
        self.assertEqual(api.try_login("a@b.c", "good"), "tok")
        self.assertIsNone(api.try_login("a@b.c", "bad"))

    def test_decimal_body_serialises(self):
        self.assertEqual(api._json_default(Decimal("12")), 12)
        self.assertEqual(api._json_default(Decimal("12.5")), 12.5)

    def test_require_local_refuses_remote(self):
        with mock.patch.object(api, "API_BASE", "https://prod.example.com"):
            with self.assertRaises(api.Unreachable):
                api.require_local()
        with mock.patch.object(api, "API_BASE", "http://localhost:5000"):
            api.require_local()

    def test_poll_uses_runtime_timeout(self):
        # Regression: e2e-journey.py's --timeout never reached poll() (default bound at def time).
        old = api.POLL_TIMEOUT
        self.addCleanup(api.set_poll_timeout, old)
        api.set_poll_timeout(0)
        with self.assertRaises(api.StepFailed) as cm:
            api.poll("never", lambda: False)
        self.assertIn("after 0s", str(cm.exception))


class AssertsTests(unittest.TestCase):
    def test_subsequence(self):
        self.assertTrue(asserts.is_subsequence(["a", "c"], ["a", "b", "c"]))
        self.assertFalse(asserts.is_subsequence(["c", "a"], ["a", "b", "c"]))

    def test_completion_money_exact(self):
        job = {"finalHours": 2, "labourAmount": Decimal("170.00"), "adjustmentsTotal": Decimal("20.10"),
               "finalAmount": Decimal("190.10"), "totalAmount": Decimal("190.10")}
        with mock.patch.object(asserts, "get", return_value=job):
            asserts.assert_completion_money(1, "t", Decimal("85"), "2")
        job["finalAmount"] = Decimal("190.11")
        with mock.patch.object(asserts, "get", return_value=job):
            with self.assertRaises(api.StepFailed):
                asserts.assert_completion_money(1, "t", Decimal("85"), "2")

    def test_audit_trail_order_and_markers(self):
        hist = [{"toStatus": s, "changedAtUtc": f"2026-01-01T00:00:0{i}"}
                for i, s in enumerate(asserts.PATH_V2)]
        a = {"statusHistory": list(reversed(hist)), "chatTranscript": [{"content": "hi"}]}
        with mock.patch.object(asserts, "get", return_value=a):
            asserts.assert_audit_trail(1, "st", 2, ["hi"])
            with self.assertRaises(api.StepFailed):
                asserts.assert_audit_trail(1, "st", 2, ["missing"])


class StageTests(unittest.TestCase):
    def test_signal_server_roundtrip(self):
        show = stage.Show(say=False)
        seen = []
        show.on_data = lambda k, v: seen.append((k, v))
        srv = stage.start_signal_server(show, 0)
        self.addCleanup(srv.server_close)
        self.addCleanup(srv.shutdown)
        ctl = f"http://127.0.0.1:{srv.server_address[1]}"
        api.http("POST", f"{ctl}/signal/go")
        api.http("POST", f"{ctl}/data/job", {"value": "42"})
        api.http("POST", f"{ctl}/step", {"actor": "tradie", "title": "tradie: accept"})
        api.http("POST", f"{ctl}/note", {"actor": "demo", "message": "fallback"})
        snap = api.http("GET", ctl)[1]
        self.assertIn("go", snap["signals"])
        self.assertEqual(snap["data"]["job"], "42")
        self.assertEqual(seen, [("job", "42")])
        self.assertEqual(show.steps[0]["title"], "tradie: accept")
        self.assertEqual(show.notes[0]["message"], "fallback")


class FabricReportTests(unittest.TestCase):
    def _manifest(self, d):
        p = Path(d) / "m.json"
        p.write_text(json.dumps({"schemaVersion": 1, "runId": "r1", "personas": [
            {"role": "homeowner", "email": "h@x", "password": "p"},
            {"role": "tradie", "email": "t@x", "password": "p"},
            {"role": "staff", "email": "s@x", "password": "p"}]}))
        return p

    def test_record_job_shape_and_dedupe(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._manifest(d)
            self.assertTrue(fabric.record_job(p, 7, "demo"))
            self.assertFalse(fabric.record_job(p, 7, "demo"))
            jobs = json.loads(p.read_text())["jobs"]
            self.assertEqual(jobs, [{"id": 7, "scenario": "demo", "homeownerEmail": "h@x", "tradieEmail": "t@x"}])

    def test_job_recorder_filters_keys(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._manifest(d)
            rec = fabric.make_job_recorder(p, {"job": "demo"})
            rec("other", "5")
            rec("job", "abc")
            rec("job", "9")
            self.assertEqual([j["id"] for j in json.loads(p.read_text())["jobs"]], [9])

    def test_junit(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d) / "j.xml"
            report.write_junit(str(out), [("ok step", 1.0, None), ("bad", 2.0, "boom")], 3.0)
            text = out.read_text()
            self.assertIn('tests="2" failures="1"', text)
            self.assertIn("boom", text)


if __name__ == "__main__":
    unittest.main()
