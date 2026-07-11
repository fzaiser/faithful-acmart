"""Copyright/option validation variants vs LaTeX.

Renders each variant with both engines, saves a side-by-side PNG, and gates the
page-1 raster mismatch percentage against the matrix thresholds."""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

import test_matrix as M
from harness import LATEX, TYPST, DIFF, OUT, ROOT, compile_typst, _pmap
from latex_build import latex_build, ref_is_fresh, ensure_class


# LaTeX/Typst templates for the validation suite (copyright modes + options).
_VALIDATE_TEX = r"""\documentclass[acmsmall{opts}]{{acmart}}
\acmJournal{{JACM}}
\acmVolume{{37}}\acmNumber{{4}}\acmArticle{{111}}\acmYear{{2018}}\acmMonth{{8}}
\acmDOI{{XXXXXXX.XXXXXXX}}\copyrightyear{{2018}}
{pre}
\begin{{document}}
\title{{Validating Options}}
\author{{Ben Trovato}}
\email{{trovato@corporation.com}}
\affiliation{{\institution{{Institute for Clarity in Documentation}}\city{{Dublin}}\country{{USA}}}}
\begin{{abstract}}
A short abstract used for validating acmart options and copyright modes.
\end{{abstract}}
\maketitle
\section{{Introduction}}\label{{sec:intro}}
Body text that visits \url{{https://www.acm.org}} and refers to \autoref{{sec:intro}}.
This sentence pads the paragraph with enough words to wrap onto a second line so
that review-mode line numbering has multiple lines to enumerate down the page.
\end{{document}}
"""

_VALIDATE_TYP = r"""#import "/src/lib.typ": acmart
#show: acmart.with(
  format: "acmsmall",
{opts}  title: "Validating Options",
  journal: "JACM", acm-volume: 37, acm-number: 4, acm-article: 111,
  acm-year: 2018, acm-month: 8, doi: "XXXXXXX.XXXXXXX", copyright-year: 2018,
  authors: ((name: "Ben Trovato", email: "trovato@corporation.com",
             affiliation: (institution: "Institute for Clarity in Documentation",
                           city: "Dublin", country: "USA")),),
  abstract: [A short abstract used for validating acmart options and copyright modes.],
)
= Introduction <sec:intro>
Body text that visits #link("https://www.acm.org") and refers to @sec:intro.
This sentence pads the paragraph with enough words to wrap onto a second line so
that review-mode line numbering has multiple lines to enumerate down the page.
"""


def _validate_variant_results(
    names: list[str],
    jobs: int,
    force: bool = False,
) -> list[tuple[str, float, str]]:
    import numpy as np
    from PIL import Image

    LATEX.mkdir(parents=True, exist_ok=True)
    TYPST.mkdir(parents=True, exist_ok=True)
    DIFF.mkdir(parents=True, exist_ok=True)

    def render(pdf: Path):
        with tempfile.TemporaryDirectory() as td:
            out = Path(td) / "p"
            subprocess.run(["pdftoppm", "-r", "150", "-f", "1", "-l", "1", "-png",
                            str(pdf), str(out)], check=True, capture_output=True)
            f = sorted(Path(td).glob("p*.png"))[0]
            return np.asarray(Image.open(f).convert("RGB"))

    def mismatch(a, b):
        ga, gb = a.mean(axis=2), b.mean(axis=2)
        h, w = max(ga.shape[0], gb.shape[0]), max(ga.shape[1], gb.shape[1])

        def pad(g):
            o = np.full((h, w), 255.0)
            o[:g.shape[0], :g.shape[1]] = g[:h, :w]
            return o

        return float((np.abs(pad(ga) - pad(gb)) > 40).mean()) * 100.0

    def save_side(name, ref, our):
        h, w = max(ref.shape[0], our.shape[0]), max(ref.shape[1], our.shape[1])

        def pad(im):
            o = np.full((h, w, 3), 255, np.uint8)
            o[:im.shape[0], :im.shape[1]] = im[:h, :w]
            return o

        gap = np.full((h, 16, 3), 255, np.uint8)
        Image.fromarray(np.concatenate([pad(ref), gap, pad(our)], axis=1)).save(
            DIFF / f"var-{name}-side.png")

    def variant(name: str) -> tuple[str, float, str]:
        opts, pre, typ_opts = M.VARIANTS[name]
        tex = LATEX / f"var-{name}.tex"
        new_tex = _VALIDATE_TEX.format(opts=opts, pre=pre)
        # Only rewrite when the content changes, so an unchanged variant keeps its
        # mtime and ref_is_fresh can skip its (slow) LaTeX rebuild.
        if not (tex.exists() and tex.read_text() == new_tex):
            tex.write_text(new_tex)
        typ = OUT / f"var-{name}.typ"
        typ.write_text(_VALIDATE_TYP.format(opts=typ_opts))
        if force or not ref_is_fresh(tex, LATEX / f"var-{name}.pdf"):
            latex_build(tex)
        rc, stderr = compile_typst(typ, TYPST / f"var-{name}.pdf")
        typ.unlink(missing_ok=True)
        if rc != 0:
            detail = stderr.strip() or f"rc={rc}"
            raise RuntimeError(f"{name}: Typst validation compile failed\n{detail}")
        ref, our = render(LATEX / f"var-{name}.pdf"), render(TYPST / f"var-{name}.pdf")
        save_side(name, ref, our)
        note = ""
        if name == "screen":
            def link_rgb(img):
                rgb = img.reshape(-1, 3).astype(int)
                colourful = rgb[(rgb.max(1) - rgb.min(1)) > 40]
                return colourful[colourful.sum(1).argmin()] if len(colourful) else None
            rc, oc = link_rgb(ref), link_rgb(our)
            if rc is not None and oc is not None:
                d = int(max(abs(rc - oc)))
                # A ±1-2/channel delta is expected (Typst writes CMYK as 8-bit).
                if d > 2:
                    note += f"link rgb ref~{tuple(rc)} our~{tuple(oc)} (Δ{d}) "
        return name, mismatch(ref, our), note

    ensure_class(LATEX)  # warm the class before the parallel fan-out (write race)
    return _pmap(variant, names, jobs)


def _validate_failures(rows: list[tuple[str, float, str]]) -> list[str]:
    failures = []
    missing = sorted(set(M.VARIANTS) - set(M.VARIANT_MISMATCH_MAX))
    extra = sorted(set(M.VARIANT_MISMATCH_MAX) - set(M.VARIANTS))
    if missing:
        failures.append("validation variants missing mismatch thresholds: " + ", ".join(missing))
    if extra:
        failures.append("validation thresholds without variants: " + ", ".join(extra))
    for name, pct, _note in rows:
        limit = M.VARIANT_MISMATCH_MAX.get(name)
        if limit is None:
            failures.append(f"{name}: no validation mismatch threshold")
        elif pct > limit:
            failures.append(f"{name}: validation mismatch {pct:.2f}% > {limit:.2f}%")
    return failures


def gate_validate(jobs: int, force: bool = False) -> list[str]:
    rows = _validate_variant_results(list(M.VARIANTS), jobs, force)
    return _validate_failures(rows)


def cmd_validate(args) -> int:
    names = args.names or list(M.VARIANTS)
    rows = _validate_variant_results(names, args.jobs, args.force)
    failures = _validate_failures(rows)
    print(f"{'variant':16} {'mismatch%':>9} {'max%':>7}   notes")
    print("-" * 60)
    for name, pct, note in rows:
        limit = M.VARIANT_MISMATCH_MAX.get(name)
        max_label = f"{limit:.2f}" if limit is not None else "unset"
        print(f"{name:16} {pct:9.2f} {max_label:>7}   {note}")
    print(f"\nside-by-sides: {DIFF.relative_to(ROOT)}/var-*-side.png")
    for failure in failures:
        print(f"FAIL {failure}", file=sys.stderr)
    return 1 if failures else 0
