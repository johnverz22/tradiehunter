"""HTTP, polling and upload helpers (moved unchanged from scripts/e2e-journey.py, plan 12 U1.2).

Two flavours on purpose:
  * `get/post/delete/_request` raise StepFailed on HTTP >= 400 and parse money as Decimal.
  * `http` never raises (status 0 = unreachable); `try_login` returns a token or None.
Only ever points at the local docker stack: call `require_local()` first.
"""
from __future__ import annotations

import base64
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from decimal import Decimal

API_BASE = os.environ.get("FIXO_API_URL", "http://localhost:5000").rstrip("/")
API = API_BASE + "/api"

HTTP_TIMEOUT = 15
POLL_TIMEOUT = 45
POLL_INTERVAL = 2

# Smallest valid PNG; a unique suffix defeats the server's receipt dedupe.
_PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
)


class StepFailed(Exception):
    pass


class Unreachable(Exception):
    pass


def require_local():
    host = (urllib.parse.urlparse(API_BASE).hostname or "").lower()
    if host not in ("localhost", "127.0.0.1", "::1"):
        raise Unreachable("refusing FIXO_API_URL %r: not localhost (local docker stack only)" % API_BASE)


def set_poll_timeout(seconds):
    """`--timeout` hook. (In e2e-journey.py the old `global POLL_TIMEOUT` assignment never reached
    poll(), whose default was bound at definition time; this makes the flag actually work.)"""
    global POLL_TIMEOUT
    POLL_TIMEOUT = int(seconds)


# ── Raising, Decimal-aware client ────────────────────────────────────────────


def _json_default(o):
    """Request bodies may carry Decimal amounts: integral values go out as ints
    (exact), others as floats (fine for the 2dp test amounts used here)."""
    if isinstance(o, Decimal):
        return int(o) if o == o.to_integral_value() else float(o)
    raise TypeError("cannot serialise %r" % (o,))


def _request(method, path, token=None, body=None, raw=None, content_type=None):
    headers = {}
    data = None
    if token:
        headers["Authorization"] = "Bearer " + token
    if raw is not None:
        data, headers["Content-Type"] = raw, content_type
    elif body is not None:
        data, headers["Content-Type"] = json.dumps(body, default=_json_default).encode(), "application/json"
    req = urllib.request.Request(API + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as r:
            status, text = r.status, r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        status, text = e.code, e.read().decode("utf-8", "replace")
    except (urllib.error.URLError, OSError) as e:
        raise Unreachable("%s %s: %s" % (method, path, e))
    if status >= 400:
        raise StepFailed("%s %s -> HTTP %d: %s" % (method, path, status, text[:300]))
    if status == 204 or not text.strip():
        return None
    try:
        # Money is a JSON number server-side; parse it as Decimal so amounts
        # are compared exactly (never through binary floats).
        return json.loads(text, parse_float=Decimal)
    except ValueError:
        return {"_raw": text}


def get(path, token=None):
    return _request("GET", path, token)


def post(path, token=None, body=None):
    return _request("POST", path, token, body if body is not None else {})


def delete(path, token=None):
    return _request("DELETE", path, token)


def _upload_png(path, field_name, filename, token):
    boundary = "fixojourney%d" % int(time.time() * 1000)
    payload = _PNG + ("|fixo-journey-%d" % time.time_ns()).encode()
    head = (
        '--%s\r\nContent-Disposition: form-data; name="%s"; '
        'filename="%s"\r\nContent-Type: image/png\r\n\r\n' % (boundary, field_name, filename)
    ).encode()
    tail = ("\r\n--%s--\r\n" % boundary).encode()
    return _request(
        "POST",
        path,
        token,
        raw=head + payload + tail,
        content_type="multipart/form-data; boundary=" + boundary,
    )


def upload_receipt(job_id, token):
    return _upload_png("/jobs/%d/payment/upload-receipt" % job_id, "receipt", "receipt.png", token)


def upload_photo(job_id, token):
    return _upload_png("/jobs/%d/photos" % job_id, "files", "issue.png", token)


def login(creds):
    """creds = (email, password). Raises Unreachable with a hint when the account is missing."""
    try:
        body = post("/auth/login", body={"email": creds[0], "password": creds[1]})
    except StepFailed as e:
        raise Unreachable(
            "cannot log in as %s (%s) — run: bash scripts/seed-test-accounts.sh"
            % (creds[0], str(e)[:160].replace("\n", " "))
        )
    token = (body or {}).get("token")
    if not token:
        raise Unreachable("login for %s returned no token: %r" % (creds[0], body))
    return token


def poll(desc, fn, timeout=None):
    timeout = POLL_TIMEOUT if timeout is None else timeout
    end = time.time() + timeout
    last = None
    while time.time() < end:
        last = fn()
        if last:
            return last
        time.sleep(POLL_INTERVAL)
    raise StepFailed("timed out after %ds waiting for: %s" % (timeout, desc))


def status_of(job_id, token):
    return (get("/jobs/%d" % job_id, token) or {}).get("status")


def wait_status(job_id, token, expected):
    def check():
        s = status_of(job_id, token)
        return s == expected

    try:
        poll("job %d status == %s" % (job_id, expected), check)
    except StepFailed:
        raise StepFailed(
            "job %d never reached %s (now %s)" % (job_id, expected, status_of(job_id, token))
        )


# ── Non-raising client (used by the stage/fabric preflight and the signal server) ──


def http(method: str, url: str, body: object = None, token: str | None = None, timeout: float = 15):
    """Absolute-URL request. Returns (status, parsed body); status 0 when unreachable. Never raises."""
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


def try_login(email: str, password: str) -> str | None:
    status, body = http("POST", f"{API}/auth/login", {"email": email, "password": password})
    return body.get("token") if status == 200 and isinstance(body, dict) else None
