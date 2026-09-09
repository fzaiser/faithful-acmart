from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

from test_matrix import TESTS
from harness import ROOT, LATEX, DIFF, typst_pdf, default_jobs, _pmap
from pdf_extract import page_count


def _qpdf(argv: list[str]) -> None:
    # qpdf exit code 3 denotes warnings.
    p = subprocess.run(["qpdf", *argv], capture_output=True, text=True)
    if p.returncode not in (0, 3):
        raise RuntimeError(f"qpdf {argv}: {p.stderr.strip()}")


def _gs_recolor(src: Path, dst: Path, rgb: tuple[float, float, float], tmp: Path) -> None:
    """Recolor device-color ink, preserving near-white backgrounds.

    Convert to PostScript first so color operators can be overridden; bind retains the original operators to avoid recursion.
    Spot colors, ICC colors, and embedded images retain their original colors."""
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
    """Overlay red Typst ink on blue LaTeX ink.

    Typst goes on top because it has no opaque page background.
    Normal blending makes exact overlaps red; extra LaTeX pages remain visible."""
    blue, red = tmp / f"{name}-blue.pdf", tmp / f"{name}-red.pdf"
    _gs_recolor(ref, blue, (0, 0, 1), tmp)
    _gs_recolor(ours, red, (1, 0, 0), tmp)
    _qpdf(["--overlay", str(red), "--", str(blue), str(out)])
    return out


def _vector_sidebyside(name: str, ref: Path, ours: Path, tmp: Path, out: Path) -> Path:
    inter = tmp / f"{name}-inter.pdf"
    _qpdf(["--collate", "--empty", "--pages", str(ref), str(ours), "--", str(inter)])
    subprocess.run(["pdfjam", "--quiet", "--nup", "2x1", "--landscape", "--frame", "true",
                    str(inter), "-o", str(out)], check=True, capture_output=True)
    return out


def cmd_overlay(args) -> int:
    stems = args.stems or [n for n, t in TESTS.items() if t.kind == "twin"]
    DIFF.mkdir(parents=True, exist_ok=True)
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
