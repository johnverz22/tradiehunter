#!/usr/bin/env python3
"""Render a React admin page to HTML in Node and assert on the markup.

There is no browser automation available in this repo, so this is how a page's
*rendered output* gets checked: the page is server-rendered with React, React
Query and a MemoryRouter in `<web>/.probe/`, with every axios call answered from
a JSON fixture, then the HTML is asserted against the fixture's `expect` list.

Why bundle with `vite build --ssr` instead of `node --experimental-strip-types`:
the page imports `@/…` aliases, CSS-adjacent modules and `import.meta.env`, all of
which vite already knows how to resolve for this app (web/vite.config.ts).

Usage (from the repo root):

    python3 scripts/web/render-probe.py \\
        --page features/credentials/pages/CredentialQueue \\
        --fixture scripts/web/fixtures/credentials/multi-page.json

    python3 scripts/web/render-probe.py --page <module under web/src> --fixture <json> [--export Name] [--keep]

`--page` is a module path relative to `web/src` (no extension). `--export` pins the
exported component to render; without it a default export wins and the page module's
own file name is the fallback (most admin pages use a named export).

Fixture format (see scripts/web/fixtures/credentials/*.json):

    {
      "route":    "/credentials",                 # MemoryRouter initial entry
      "prefetch": [ { "key": ["admin","credentials","pending",{"page":1,"pageSize":20}],
                      "url": "/admin/credentials/pending",
                      "body": { ... } } ],
      "routes":   [ { "url": "/admin/credentials/7/review", "status": 200, "body": {...} } ],
      "expect":   [ { "label": "empty state", "needle": "No credentials awaiting review.", "present": true } ]
    }

`prefetch` seeds the React Query cache under the page's own query key, which is
what makes data rendering synchronous during `renderToString` — copy the key from
the page's hook. Each prefetch entry's `url` is also served to axios, so a
read-only page only describes a query once; add `routes` only for calls that
happen outside a prefetch (mutations, secondary queries). `routes` answers axios
calls by URL substring, first match wins; an unmatched call throws, so a page
that fetches something the fixture forgot to describe fails loudly instead of
silently rendering an error state.

Requires python3 (stdlib only) and web/node_modules installed (`npm install` in web/).
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
WEB_DIR = REPO_ROOT / "web"
PROBE_DIR = WEB_DIR / ".probe"

ENTRY_TEMPLATE = """\
import React from 'react';
import { renderToString } from 'react-dom/server';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import api from '../src/services/api';
import fixture from './fixture.json';
import * as target from '../src/__PAGE__';

// Node has no localStorage; api.ts's request interceptor reads it for the JWT.
const store = new Map();
if (typeof globalThis.localStorage === 'undefined') {
  globalThis.localStorage = {
    getItem: (key) => (store.has(key) ? store.get(key) : null),
    setItem: (key, value) => { store.set(key, String(value)); },
    removeItem: (key) => { store.delete(key); },
    clear: () => { store.clear(); },
  };
}

// Deterministic HTTP: every axios call resolves from the fixture's `routes`.
api.defaults.adapter = async (config) => {
  const url = String(config.url ?? '');
  const route = (fixture.routes ?? []).find((entry) => url.includes(entry.url));
  if (!route) {
    throw new Error(`render-probe: no fixture route matches ${url} — add one to the fixture`);
  }
  return { data: route.body, status: route.status ?? 200, statusText: 'OK', headers: {}, config };
};

// Prefer a default export, but plenty of pages export only a named component
// (e.g. `export const CredentialQueue`) — `__EXPORT__` is that name.
const Page = target.default ?? target.__EXPORT__;
if (!Page) {
  throw new Error('render-probe: no default export and no "' + '__EXPORT__' + '" export in __PAGE__ — pass --export <Name>');
}

const client = new QueryClient({
  defaultOptions: {
    queries: { retry: false, staleTime: Infinity, refetchOnMount: false, refetchOnWindowFocus: false },
    mutations: { retry: false },
  },
});

async function main() {
  for (const entry of fixture.prefetch ?? []) {
    await client.prefetchQuery({ queryKey: entry.key, queryFn: () => Promise.resolve(entry.body) });
  }

  const routePath = fixture.path;

  process.stdout.write(
    renderToString(
      <QueryClientProvider client={client}>
        <MemoryRouter initialEntries={[fixture.route ?? '/']}>
          {routePath ? (
            <Routes>
              <Route path={routePath} element={<Page />} />
            </Routes>
          ) : (
            <Page />
          )}
        </MemoryRouter>
      </QueryClientProvider>,
    ),
  );
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
"""


def shell(cmd: list[str], cwd: Path) -> str:
    proc = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if proc.returncode != 0:
        sys.stderr.write(proc.stdout)
        sys.stderr.write(proc.stderr)
        raise SystemExit(f"command failed ({proc.returncode}): {' '.join(cmd)}")
    return proc.stdout


def vite_bin() -> list[str]:
    local = WEB_DIR / "node_modules" / ".bin" / "vite"
    return [str(local)] if local.exists() else ["npx", "vite"]


FALLBACK_PAGES: dict[str, str] = {
    "credentials": "features/credentials/pages/CredentialQueue",
    "payments": "features/payments/pages/PaymentQueue",
    "audit": "features/audit/pages/AuditLogsPage",
    "payouts/queue.json": "features/payouts/pages/PayoutQueue",
    "payouts/batches.json": "features/payouts/pages/PayoutBatches",
}


def resolve_page_for_fixture(fixture_path: Path, fixture: dict) -> str | None:
    if "page" in fixture:
        return str(fixture["page"])
    try:
        fixtures_dir = REPO_ROOT / "scripts/web/fixtures"
        rel = str(fixture_path.relative_to(fixtures_dir))
        if rel in FALLBACK_PAGES:
            return FALLBACK_PAGES[rel]
        top = fixture_path.relative_to(fixtures_dir).parts[0]
        if top in FALLBACK_PAGES:
            return FALLBACK_PAGES[top]
    except ValueError:
        pass
    return None


def run_probe(
    page: str,
    fixture_path: Path,
    export_name: str = "default",
    keep: bool = False,
    quiet: bool = False,
) -> tuple[bool, int, int, list[str]]:
    page_path = (WEB_DIR / "src" / page).with_suffix(".tsx")
    if not page_path.exists():
        raise SystemExit(f"no such page module: {page_path}")
    if not fixture_path.is_absolute():
        fixture_path = (REPO_ROOT / fixture_path).resolve()
    if not fixture_path.exists() or not fixture_path.is_file():
        raise SystemExit(f"no such fixture: {fixture_path}")
    fixture = json.loads(fixture_path.read_text())
    if "routes" not in fixture:
        fixture["routes"] = [
            {"url": entry["url"], "body": entry["body"], "status": entry.get("status", 200)}
            for entry in fixture.get("prefetch", [])
            if "url" in entry
        ]

    probe_entry = PROBE_DIR / "entry.tsx"
    if PROBE_DIR.exists():
        shutil.rmtree(PROBE_DIR)
    PROBE_DIR.mkdir(parents=True)
    (PROBE_DIR / "fixture.json").write_text(json.dumps(fixture, indent=2))

    named = export_name if export_name != "default" else fixture.get("export", Path(page).name)
    probe_entry.write_text(
        ENTRY_TEMPLATE.replace("__PAGE__", page).replace("__EXPORT__", named)
    )

    rel_fix = fixture_path.relative_to(REPO_ROOT) if fixture_path.is_relative_to(REPO_ROOT) else fixture_path
    if not quiet:
        print(f"\nprobe: {page} (export {named}) <- {rel_fix}")

    shell(vite_bin() + ["build", "--ssr", ".probe/entry.tsx", "--outDir", ".probe/out", "--logLevel", "warn"], WEB_DIR)

    bundle = PROBE_DIR / "out" / "entry.js"
    if not bundle.exists():
        candidates = sorted(p for p in (PROBE_DIR / "out").glob("*.js"))
        if not candidates:
            raise SystemExit("vite produced no SSR bundle in web/.probe/out")
        bundle = candidates[0]

    html = shell(["node", str(bundle.relative_to(WEB_DIR))], WEB_DIR)
    (PROBE_DIR / "render.html").write_text(html)

    flat = html.replace("<!-- -->", "")
    if not quiet:
        print(f"rendered {len(html)} chars of HTML")

    expectations = fixture.get("expect", [])
    failures: list[str] = []
    passed_count = 0
    for entry in expectations:
        needle = entry["needle"]
        expected = entry.get("present", True)
        found = needle in flat
        ok = found == expected
        if ok:
            passed_count += 1
        else:
            failures.append(entry.get("label", needle))
        if not quiet:
            print(f"{'PASS' if ok else 'FAIL'}  {entry.get('label', needle)}: "
                  f"{'present' if found else 'absent'} (expected {'present' if expected else 'absent'}) -> {needle!r}")

    tbody = re.search(r"<tbody>(.*?)</tbody>", flat, re.S)
    if tbody and not quiet:
        text = re.sub(r"(?:\s*\|\s*)+", " | ", re.sub(r"<[^>]+>", " | ", tbody.group(1))).strip(" |")
        print("\n--- rendered <tbody> text ---\n" + text[:800])

    if keep:
        print(f"\nkept: {PROBE_DIR.relative_to(REPO_ROOT)} (entry.tsx, fixture.json, out/, render.html)")
    else:
        shutil.rmtree(PROBE_DIR)

    if not quiet:
        if not expectations:
            print("\nno `expect` entries in the fixture — nothing asserted")
        if failures:
            print(f"\n{len(failures)} of {len(expectations)} assertions failed: {', '.join(failures)}")
        else:
            print(f"\n{len(expectations)}/{len(expectations)} assertions passed")

    return len(failures) == 0, passed_count, len(expectations), failures


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--page", help="module path under web/src, e.g. features/users/pages/UserListPage (optional if fixture defines it)")
    parser.add_argument("--fixture", help="fixture JSON (routes + prefetch + expect)")
    parser.add_argument("--export", default="default", help="named export to render (default: the default export)")
    parser.add_argument("--keep", action="store_true", help="keep web/.probe/ (bundle, fixture, rendered HTML) for debugging")
    parser.add_argument("--all", action="store_true", help="discover and run all probe fixtures under scripts/web/fixtures/")
    args = parser.parse_args()

    if args.all:
        fixtures_dir = REPO_ROOT / "scripts/web/fixtures"
        all_fixtures = sorted(fixtures_dir.glob("**/*.json"))
        if not all_fixtures:
            print("No fixtures found under scripts/web/fixtures/")
            return 1
        print(f"Running probe test suite: found {len(all_fixtures)} fixtures...")
        results = []
        overall_failures = 0
        total_assertions = 0
        passed_assertions = 0
        for f in all_fixtures:
            data = json.loads(f.read_text())
            page = args.page or resolve_page_for_fixture(f, data)
            if not page:
                print(f"SKIP {f.relative_to(REPO_ROOT)}: cannot infer --page")
                continue
            ok, p_cnt, tot_cnt, fails = run_probe(page, f, export_name=args.export, keep=args.keep, quiet=False)
            results.append((f.relative_to(REPO_ROOT), ok, p_cnt, tot_cnt, fails))
            total_assertions += tot_cnt
            passed_assertions += p_cnt
            if not ok:
                overall_failures += 1

        print("\n" + "=" * 60)
        print("Probe Test Suite Summary:")
        print("=" * 60)
        for path, ok, p_cnt, tot_cnt, fails in results:
            status = "PASS" if ok else "FAIL"
            print(f"  {status:4}  {path} ({p_cnt}/{tot_cnt})")
            if fails:
                for fail in fails:
                    print(f"        └─ {fail}")
        print("-" * 60)
        print(f"Total: {len(results) - overall_failures}/{len(results)} fixtures passed, {overall_failures} failed. "
              f"({passed_assertions}/{total_assertions} assertions passed)")
        print("=" * 60)
        return 0 if overall_failures == 0 else 1

    if not args.fixture:
        parser.error("--fixture is required unless --all is specified")

    fixture_path = Path(args.fixture)
    if not fixture_path.is_absolute():
        fixture_path = (REPO_ROOT / fixture_path).resolve()
    if not fixture_path.exists() or not fixture_path.is_file():
        raise SystemExit(f"no such fixture: {fixture_path}")
    fixture_data = json.loads(fixture_path.read_text())

    page = args.page or resolve_page_for_fixture(fixture_path, fixture_data)
    if not page:
        parser.error("Could not infer --page from fixture; please pass --page explicitly")

    ok, _, _, _ = run_probe(page, fixture_path, export_name=args.export, keep=args.keep, quiet=False)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
