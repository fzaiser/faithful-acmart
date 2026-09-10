from __future__ import annotations

import html
import json
import shutil
import sys
from pathlib import Path

from test_matrix import TESTS
from harness import ROOT, OUT, LATEX, typst_pdf
from overlay import page_svgs, write_comparison, write_page_svgs

REPORT_DIR = OUT / "report"
STATUS_FILE = REPORT_DIR / "check-status.json"
IMG_DIR = REPORT_DIR / "img"


def record_check_status(gate_failures: dict[str, list[str]]) -> None:
    """Identify fixture failures by the leading token in each gate diagnostic."""
    twins = {name for name, t in TESTS.items() if t.kind == "twin"}
    per_twin: dict[str, set[str]] = {}
    for slug, failures in gate_failures.items():
        for failure in failures:
            head = failure.split(":", 1)[0].strip().split(" ")[0] if failure else ""
            if head in twins:
                per_twin.setdefault(head, set()).add(slug)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    STATUS_FILE.write_text(json.dumps(
        {stem: sorted(slugs) for stem, slugs in sorted(per_twin.items())}, indent=2))


def _read_status() -> dict[str, list[str]]:
    if not STATUS_FILE.exists():
        return {}
    try:
        return json.loads(STATUS_FILE.read_text())
    except (json.JSONDecodeError, OSError):
        return {}


def _rel(path: Path) -> str:
    return path.relative_to(REPORT_DIR).as_posix()


_STYLE = """
:root { color-scheme: light dark; }
* { box-sizing: border-box; }
body { margin: 0; font: 15px/1.5 -apple-system, system-ui, sans-serif;
       background: #f4f5f7; color: #16181d; }
@media (prefers-color-scheme: dark) {
  body { background: #16181d; color: #e6e8ec; }
  header.top, section.twin { background: #1f232b; }
}
header.top { position: sticky; top: 0; z-index: 2; padding: 14px 24px;
             background: #fff; border-bottom: 1px solid #0002; }
header.top h1 { margin: 0; font-size: 18px; }
header.top p { margin: 4px 0 0; opacity: .7; font-size: 13px; }
main { padding: 24px; display: flex; flex-direction: column; gap: 28px; }
section.twin { background: #fff; border: 1px solid #0002; border-radius: 10px;
               padding: 18px 20px; }
section.twin > h2 { margin: 0 0 4px; font-size: 17px; font-family: ui-monospace, monospace; }
.chips { display: flex; flex-wrap: wrap; gap: 6px; margin: 8px 0 4px; }
.chip { font-size: 12px; padding: 2px 9px; border-radius: 999px;
        background: #d93025; color: #fff; font-weight: 600; }
.chip.ok { background: #1a7f37; }
.pages { display: flex; flex-direction: column; gap: 18px; margin-top: 14px; }
.page { border-top: 1px solid #0001; padding-top: 12px; }
.page .plabel { font-size: 13px; font-weight: 600; opacity: .75; margin-bottom: 8px; }
.cols { display: flex; gap: 14px; overflow-x: auto; }
figure { margin: 0; flex: 1 1 0; min-width: 220px; }
figure a { display: block; }
figure figcaption { font-size: 12px; opacity: .7; margin-bottom: 5px; text-align: center; }
figure img { width: 100%; height: auto; border: 1px solid #0002; border-radius: 4px;
             background: #fff; }
.missing { font-size: 13px; opacity: .6; padding: 40px 8px; text-align: center;
           border: 1px dashed #0003; border-radius: 4px; }
"""


def _figure(caption: str, svg: Path | None) -> str:
    """Show one page, linked so a click opens the SVG on its own for zooming."""
    body = (f'<a href="{html.escape(_rel(svg))}"><img loading="lazy" '
            f'src="{html.escape(_rel(svg))}" alt="{html.escape(caption)}"></a>'
            if svg is not None else '<div class="missing">— no page —</div>')
    return f'<figure><figcaption>{html.escape(caption)}</figcaption>{body}</figure>'


def _twin_section(stem: str, gates: list[str]) -> str:
    ref, ours = LATEX / f"{stem}.pdf", typst_pdf(stem)
    latex_pages = page_svgs(ref) if ref.exists() else []
    typst_pages = page_svgs(ours) if ours.exists() else []
    latex_svgs = write_page_svgs(latex_pages, IMG_DIR / f"{stem}-latex")
    typst_svgs = write_page_svgs(typst_pages, IMG_DIR / f"{stem}-typst")
    overlay_svgs = write_comparison(latex_pages, typst_pages, IMG_DIR / f"{stem}-overlay")

    if gates:
        chips = "".join(f'<span class="chip">{html.escape(g)}</span>' for g in gates)
    else:
        chips = '<span class="chip ok">no recorded check failures</span>'

    rows = []
    for i in range(len(overlay_svgs)):
        cols = [
            _figure("LaTeX", latex_svgs[i] if i < len(latex_svgs) else None),
            _figure("Typst", typst_svgs[i] if i < len(typst_svgs) else None),
            _figure("Overlay", overlay_svgs[i]),
        ]
        rows.append(
            f'<div class="page"><div class="plabel">page {i + 1}</div>'
            f'<div class="cols">{"".join(cols)}</div></div>')
    if not rows:
        rows.append('<div class="missing">no PDF pages — run `test.py build` first</div>')

    return (f'<section class="twin"><h2>{html.escape(stem)}</h2>'
            f'<div class="chips">{chips}</div>'
            f'<div class="pages">{"".join(rows)}</div></section>')


def cmd_report(args) -> int:
    status = _read_status()
    stems = args.stems
    if not stems:
        stems = sorted(status)
        if not stems:
            print("no stems given and no recorded check failures "
                  "(run `test.py check`, or name twins explicitly).", file=sys.stderr)
            return 2
        print(f"reporting the {len(stems)} twin(s) that failed the last check: "
              + ", ".join(stems))

    unknown = [s for s in stems if s not in TESTS or TESTS[s].kind != "twin"]
    if unknown:
        print("not a known twin: " + ", ".join(unknown), file=sys.stderr)
        return 2

    if IMG_DIR.exists():
        shutil.rmtree(IMG_DIR)
    IMG_DIR.mkdir(parents=True, exist_ok=True)

    sections = []
    for stem in stems:
        print(f"  rendering {stem}…")
        sections.append(_twin_section(stem, status.get(stem, [])))

    doc = (
        '<!doctype html><html lang="en"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        "<title>typst-acmart comparison report</title>"
        f"<style>{_STYLE}</style></head><body>"
        '<header class="top"><h1>typst-acmart comparison report</h1>'
        f'<p>{len(stems)} twin(s): LaTeX vs Typst, page by page. '
        "Red chips are gates that flagged the twin in the last check. "
        "In the overlay, blue is LaTeX ink and red is Typst ink, so the darker a mark is, "
        "the better the two engines agree there; matching grays and antialiased edges keep "
        "a faint tint. Click any page to open it on its own.</p></header>"
        f'<main>{"".join(sections)}</main></body></html>')
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    index = REPORT_DIR / "index.html"
    index.write_text(doc)
    print(f"\nwrote {index.relative_to(ROOT)} "
          f"({len(list(IMG_DIR.glob('*.svg')))} page images in "
          f"{IMG_DIR.relative_to(ROOT)}/)")
    return 0
