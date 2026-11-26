#!/usr/bin/env python3
"""Build mockup | app side-by-side images (fix plan P-06, task 0.4).

    python3 scripts/compare-shots.py [--shots DIR] [--mockups DIR] [--map FILE]
                                     [--out DIR] [--themes light,dark]
                                     [--only id[,id]] [--height 1600] [--strict]

Inputs
  mockups  docs/design/mobile/mockups/png/<id>-<theme>.png
           (make them with: node docs/design/mobile/tools/mockup-shots.mjs)
  shots    docs/runs/v2/screenshots/<theme>/<capture name>.png
           (make them with: scripts/run-shots.sh)
  map      docs/design/mobile/tools/shot-map.json  (mockup id -> capture names)

Output
  <out>/<theme>/<id>.png   mockup on the left, app on the right, with a caption
  <out>/coverage.md        one row per screen and theme: paired / missing side
  Default out is <shots>/compare. With --strict the exit code is 1 when any
  screen/theme has no pair, so it can gate a PR.

Needs Pillow (pip install pillow).
"""
import argparse
import json
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:  # pragma: no cover
    sys.exit("Pillow is required: pip install pillow")

ROOT = Path(__file__).resolve().parent.parent
BG = (24, 28, 40)
FG = (232, 237, 248)
MUTED = (157, 170, 196)


def font(size):
    for name in ("DejaVuSans.ttf", "Arial.ttf", "Helvetica.ttc"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def fit_height(img, height):
    w = max(1, round(img.width * height / img.height))
    return img.resize((w, height), Image.LANCZOS)


def run_info(shots, theme, capture):
    """commit / text scale from the run.json written next to the capture, if any."""
    persona_dir = (shots / theme / capture).parent
    for candidate in (persona_dir / "run.json",):
        if candidate.exists():
            try:
                d = json.loads(candidate.read_text())
                return f"{d.get('commit', '?')}  x{d.get('text_scale', '1.0')}"
            except (ValueError, OSError):
                pass
    return "no run.json"


def pair(mockup_path, app_path, caption, sub, height):
    left = fit_height(Image.open(mockup_path).convert("RGB"), height)
    right = fit_height(Image.open(app_path).convert("RGB"), height)
    pad, head = 24, 116
    canvas = Image.new("RGB", (left.width + right.width + pad * 3, height + head + pad), BG)
    d = ImageDraw.Draw(canvas)
    d.text((pad, 14), caption, fill=FG, font=font(28))
    d.text((pad, 52), sub, fill=MUTED, font=font(20))
    canvas.paste(left, (pad, head))
    canvas.paste(right, (left.width + pad * 2, head))
    d.text((pad, head - 28), "mockup", fill=MUTED, font=font(18))
    d.text((left.width + pad * 2, head - 28), "app", fill=MUTED, font=font(18))
    return canvas


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--shots", default=str(ROOT / "docs/runs/v2/screenshots"))
    ap.add_argument("--mockups", default=str(ROOT / "docs/design/mobile/mockups/png"))
    ap.add_argument("--map", default=str(ROOT / "docs/design/mobile/tools/shot-map.json"))
    ap.add_argument("--out", default=None)
    ap.add_argument("--themes", default="light,dark")
    ap.add_argument("--only", default="")
    ap.add_argument("--height", type=int, default=1600)
    ap.add_argument("--strict", action="store_true")
    a = ap.parse_args()

    shots, mockups = Path(a.shots), Path(a.mockups)
    out = Path(a.out) if a.out else shots / "compare"
    mapping = {k: v for k, v in json.loads(Path(a.map).read_text()).items() if not k.startswith("_")}
    only = {s.strip() for s in a.only.split(",") if s.strip()}
    unknown = only - set(mapping)
    if unknown:
        sys.exit(f"unknown screen id(s): {', '.join(sorted(unknown))}")

    rows, made, gaps = [], 0, 0
    for theme in [t.strip() for t in a.themes.split(",") if t.strip()]:
        (out / theme).mkdir(parents=True, exist_ok=True)
        for sid, names in mapping.items():
            if only and sid not in only:
                continue
            m = mockups / f"{sid}-{theme}.png"
            app = next(((n, shots / theme / f"{n}.png") for n in names if (shots / theme / f"{n}.png").exists()), None)
            if m.exists() and app:
                name, path = app
                pair(m, path, f"{sid}  ·  {theme}", f"app: {name}.png   {run_info(shots, theme, name)}", a.height).save(out / theme / f"{sid}.png")
                rows.append((sid, theme, "paired", name))
                made += 1
            else:
                missing = ("mockup png" if not m.exists() else "") + (" + " if not m.exists() and not app else "") + ("app capture" if not app else "")
                rows.append((sid, theme, f"MISSING {missing}", ", ".join(names)))
                gaps += 1

    lines = ["# Mockup vs app coverage", "", "| screen | theme | status | capture |", "|---|---|---|---|"]
    lines += [f"| `{s}` | {t} | {st} | {c} |" for s, t, st, c in rows]
    out.mkdir(parents=True, exist_ok=True)
    (out / "coverage.md").write_text("\n".join(lines) + "\n")
    print(f"paired {made}, missing {gaps}; wrote {out}/<theme>/<id>.png and {out}/coverage.md")
    return 1 if (a.strict and gaps) else 0


if __name__ == "__main__":
    sys.exit(main())
