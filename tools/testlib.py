"""Shared helpers for the regression gates (check_smoke / check_golden / metrics).

All paths are anchored at the repo root. PDFs from both engines are in PDF big
points (1/72 in), so geometry extracted here is directly comparable.
"""

from __future__ import annotations

import hashlib
import re
import statistics
import subprocess
import tempfile
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TESTS = ROOT / "tests"
LATEX = TESTS / "out" / "latex"
TYPST = TESTS / "out" / "typst"
GOLDEN = TESTS / "golden"
MANIFEST = TESTS / "manifest.toml"
TC = ROOT / "tools" / "tc"

GOLDEN_DPI = 150  # raster resolution for Tier 1 page hashes


def load_manifest() -> dict:
    with open(MANIFEST, "rb") as f:
        return tomllib.load(f)


def tests(man: dict) -> dict:
    return man["tests"]


def ref_stem(name: str, cfg: dict) -> str:
    return cfg.get("reference", name)


def latex_pdf(name: str, cfg: dict) -> Path:
    return LATEX / f"{ref_stem(name, cfg)}.pdf"


def typst_pdf(name: str) -> Path:
    return TYPST / f"{name}.pdf"


def page_count(pdf: Path) -> int:
    out = subprocess.run(["pdfinfo", str(pdf)], capture_output=True, text=True).stdout
    m = re.search(r"^Pages:\s+(\d+)", out, re.M)
    return int(m.group(1)) if m else -1


def compile_typst(stem: str, out: Path) -> tuple[int, str]:
    """Compile tests/<stem>.typ via tc; return (returncode, stderr)."""
    src = TESTS / f"{stem}.typ"
    proc = subprocess.run(
        [str(TC), "compile", str(src), str(out), "--diagnostic-format", "short"],
        capture_output=True, text=True,
    )
    return proc.returncode, proc.stderr


def rasterize(pdf: Path, dpi: int, prefix: Path) -> list[Path]:
    subprocess.run(
        ["pdftoppm", "-r", str(dpi), "-png", str(pdf), str(prefix)],
        check=True, capture_output=True,
    )
    return sorted(prefix.parent.glob(prefix.name + "-*.png"))


def page_hashes(pdf: Path, dpi: int) -> list[str]:
    # Own temp dir per call: pdftoppm pads page numbers by total page count, so a
    # shared dir would let a previous PDF's PNGs leak into this one's glob.
    with tempfile.TemporaryDirectory() as td:
        pngs = rasterize(pdf, dpi, Path(td) / "ras")
        return [hashlib.sha256(p.read_bytes()).hexdigest() for p in pngs]


_PAGE_RE = re.compile(r'<page width="([\d.]+)" height="([\d.]+)"')
_WORD_RE = re.compile(
    r'<word xMin="([\d.]+)" yMin="([\d.]+)" xMax="([\d.]+)" yMax="([\d.]+)">(.*?)</word>'
)


def words(pdf: Path) -> dict:
    """1-based page index -> {w, h, words:[(x0,y0,x1,y1,text), ...]} via pdftotext -bbox."""
    out = subprocess.run(
        ["pdftotext", "-bbox", str(pdf), "-"], capture_output=True, text=True
    ).stdout
    pages: dict = {}
    n = 0
    for line in out.splitlines():
        pm = _PAGE_RE.search(line)
        if pm:
            n += 1
            pages[n] = {"w": float(pm.group(1)), "h": float(pm.group(2)), "words": []}
            continue
        wm = _WORD_RE.search(line)
        if wm and n:
            x0, y0, x1, y1 = (float(v) for v in wm.groups()[:4])
            pages[n]["words"].append((x0, y0, x1, y1, wm.group(5)))
    return pages


def page_metrics(page: dict) -> dict | None:
    """Layout geometry for one page: text-block margins, line count, baseline pitch."""
    ws = page["words"]
    if not ws:
        return None
    left = min(w[0] for w in ws)
    right = page["w"] - max(w[2] for w in ws)
    top = min(w[1] for w in ws)
    # Cluster word tops into lines: a new line starts when the gap exceeds 2pt.
    ys = sorted(w[1] for w in ws)
    line_tops = [ys[0]]
    for y in ys[1:]:
        if y - line_tops[-1] > 2.0:
            line_tops.append(y)
    gaps = [b - a for a, b in zip(line_tops, line_tops[1:])]
    pitch = statistics.median(gaps) if gaps else 0.0
    return {"left": left, "right": right, "top": top, "lines": len(line_tops), "pitch": pitch}
