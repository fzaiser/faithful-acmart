"""Vector recolour-overlay machinery (gs + qpdf + pdfjam, no rasterization).

Per-twin ``<name>-overlay.pdf`` (Typst red over LaTeX blue) and
``<name>-side-by-side.pdf`` (LaTeX | Typst, 2-up), keeping selectable vector text."""

from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

from test_matrix import TESTS
from harness import ROOT, LATEX, DIFF, typst_pdf, default_jobs, _pmap
from pdf_extract import page_count


# --- Vector recolor-overlay primitives (gs + qpdf + pdfjam, no rasterization) ---

def _qpdf(argv: list[str]) -> None:
    # qpdf exits 3 on warnings (e.g. a recovered xref); only treat worse as fatal.
    p = subprocess.run(["qpdf", *argv], capture_output=True, text=True)
    if p.returncode not in (0, 3):
        raise RuntimeError(f"qpdf {argv}: {p.stderr.strip()}")


def _gs_recolor(src: Path, dst: Path, rgb: tuple[float, float, float], tmp: Path) -> None:
    """Recolor `src`'s device-colour vector ink to the flat colour `rgb` (0-1), losslessly.

    PDF colour operators (rg/g/k) aren't PostScript-level, so a `-c` override can't
    intercept them when gs reads a PDF directly; lowering to PostScript first (ps2write)
    turns them into setrgbcolor/setgray/setcmykcolor, which the second pass overrides.
    `bind` captures the *original* operators inside each redefinition, so the forced
    colour is set without recursing. Near-white is left alone so page backgrounds /
    knockouts aren't tinted.

    Coverage gap: ink set through a spot/ICC colourspace (`setcolor`, e.g. acmart's
    JDS cover panel and its text) and embedded images keep their original colours —
    intercepting `setcolor` generically needs per-colourspace operand counting that
    isn't worth the fragility. Typst output uses only device colours, so Typst always
    recolours fully; the gap only shows on a couple of LaTeX cover pages."""
    ps = tmp / f"{src.stem}.ps"
    subprocess.run(["gs", "-q", "-dNOPAUSE", "-dBATCH", "-sDEVICE=ps2write", "-o", str(ps), str(src)],
                   check=True, capture_output=True)
    flat = "{} {} {} setrgbcolor".format(*rgb)
    override = (
        f"/setrgbcolor{{3 copy add add 2.97 ge{{setrgbcolor}}{{pop pop pop {flat}}}ifelse}}bind def "
        f"/setgray{{dup .97 ge{{setgray}}{{pop {flat}}}ifelse}}bind def "
        f"/setcmykcolor{{4 copy add add add .03 le{{setcmykcolor}}{{pop pop pop pop {flat}}}ifelse}}bind def "
        f"/sethsbcolor{{pop pop pop {flat}}}bind def"
    )
    subprocess.run(["gs", "-q", "-dNOPAUSE", "-dBATCH", "-sDEVICE=pdfwrite",
                    "-o", str(dst), "-c", override, "-f", str(ps)], check=True, capture_output=True)


def _vector_overlay(name: str, ref: Path, ours: Path, tmp: Path, out: Path) -> Path:
    """Typst ink recoloured red, stacked on top of LaTeX ink recoloured blue, into `out`.

    Typst (red) is always the overlay and LaTeX (blue) the base: Typst pages don't
    paint an opaque background, so red sits on top without hiding LaTeX, while LaTeX's
    panels/cover fills stay underneath. Normal blend (not alpha), so on exact overlap
    red wins and any drift leaves a blue halo. If page counts differ, qpdf overlays
    the shared prefix and LaTeX's extra pages show solo (the side-by-side shows the
    rest)."""
    blue, red = tmp / f"{name}-blue.pdf", tmp / f"{name}-red.pdf"
    _gs_recolor(ref, blue, (0, 0, 1), tmp)
    _gs_recolor(ours, red, (1, 0, 0), tmp)
    _qpdf(["--overlay", str(red), "--", str(blue), str(out)])
    return out


def _vector_sidebyside(name: str, ref: Path, ours: Path, tmp: Path, out: Path) -> Path:
    """LaTeX | Typst into `out`: collate the two page-for-page, then 2-up each pair
    onto one framed landscape page (qpdf --collate + pdfjam)."""
    inter = tmp / f"{name}-inter.pdf"
    _qpdf(["--collate", "--empty", "--pages", str(ref), str(ours), "--", str(inter)])
    subprocess.run(["pdfjam", "--quiet", "--nup", "2x1", "--landscape", "--frame", "true",
                    str(inter), "-o", str(out)], check=True, capture_output=True)
    return out


def cmd_overlay(args) -> int:
    """Per-twin vector <name>-overlay.pdf + <name>-side-by-side.pdf (no raster).

    <name>-overlay.pdf: Typst ink recoloured red over LaTeX ink recoloured blue (gs+qpdf).
    <name>-side-by-side.pdf: LaTeX | Typst, 2-up per page (qpdf+pdfjam). Both keep
    selectable vector text; per-twin work runs in parallel."""
    stems = args.stems or [n for n, t in TESTS.items() if t.kind == "twin"]
    DIFF.mkdir(parents=True, exist_ok=True)
    # The previous combined bundles are superseded by the per-twin files; drop them
    # so the directory doesn't carry stale, misleading output.
    for stale in ("overlay.pdf", "side-by-side.pdf"):
        (DIFF / stale).unlink(missing_ok=True)

    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)

        def process(name: str):
            t = TESTS.get(name)
            if t is None:
                print(f"skip  {name}: not in test matrix")
                return None
            ref, ours = LATEX / f"{name}.pdf", typst_pdf(name)
            if not ref.exists() or not ours.exists():
                print(f"skip  {name}: missing {'LaTeX' if not ref.exists() else 'Typst'} PDF")
                return None
            ov = _vector_overlay(name, ref, ours, tmp, DIFF / f"{name}-overlay.pdf")
            sd = _vector_sidebyside(name, ref, ours, tmp, DIFF / f"{name}-side-by-side.pdf")
            print(f"{name:>20}: {ov.name} ({page_count(ov)}p), {sd.name} ({page_count(sd)}p)")
            return name

        results = [r for r in _pmap(process, stems, default_jobs()) if r]

    if not results:
        print("no PDFs produced (build them first: test.py build)")
        return 1
    print(f"\nwrote {2 * len(results)} PDFs to {DIFF.relative_to(ROOT)}/ — per twin, "
          "<name>-overlay.pdf (Typst red / LaTeX blue) + <name>-side-by-side.pdf (LaTeX | Typst), vector")
    return 0
