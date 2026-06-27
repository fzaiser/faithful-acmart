#!/usr/bin/env python3
"""Validate acmart copyright modes and document options against real LaTeX.

For each variant, writes a matched LaTeX + Typst document (identical content,
differing only in the option/copyright mode), compiles both, and diffs page 1 —
holding the modes/options to the same standard as the default path.

LaTeX -> tests/out/latex/var-<name>.pdf, Typst -> tests/out/typst/var-<name>.pdf,
side-by-side + overlay -> tests/out/diff/var-<name>-*.png. Prints a mismatch %
table; for `screen` it also samples link colors.

Usage: tools/validate-variants.py [name ...]   (default: all)
"""
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
LATEX = ROOT / "tests/out/latex"
TYPST = ROOT / "tests/out/typst"
DIFF = ROOT / "tests/out/diff"

# LaTeX template: {opts} extra class options, {pre} extra preamble (setcopyright etc.)
TEX = r"""\documentclass[acmsmall{opts}]{{acmart}}
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

TYP = r"""#import "/src/lib.typ": acmart
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

# name: (latex class opts, latex preamble, typst args)
VARIANTS = {
    "acmlicensed":   ("", r"\setcopyright{acmlicensed}",   '  copyright: "acmlicensed",\n'),
    "acmcopyright":  ("", r"\setcopyright{acmcopyright}",  '  copyright: "acmcopyright",\n'),
    "rightsretained":("", r"\setcopyright{rightsretained}",'  copyright: "rightsretained",\n'),
    "usgov":         ("", r"\setcopyright{usgov}",         '  copyright: "usgov",\n'),
    "usgovmixed":    ("", r"\setcopyright{usgovmixed}",    '  copyright: "usgovmixed",\n'),
    "cc-by-nc-sa":   ("", "\\setcopyright{cc}\n\\setcctype{by-nc-sa}",
                      '  copyright: "cc", cc-type: "by-nc-sa",\n'),
    "screen":    (",screen", r"\setcopyright{acmlicensed}", '  screen: true,\n'),
    "review":    (",review", r"\setcopyright{acmlicensed}", '  review: true,\n'),
    "anonymous": (",anonymous", r"\setcopyright{acmlicensed}", '  anonymous: true,\n'),
}


def render(pdf, dpi=150, page=1):
    out = DIFF / "_tmp"
    subprocess.run(["pdftoppm", "-r", str(dpi), "-f", str(page), "-l", str(page),
                    "-png", str(pdf), str(out)], check=True)
    f = sorted(DIFF.glob("_tmp*.png"))[0]
    img = np.asarray(Image.open(f).convert("RGB"))
    f.unlink()
    return img


def build(name):
    opts, pre, typ_opts = VARIANTS[name]
    LATEX.mkdir(parents=True, exist_ok=True)
    TYPST.mkdir(parents=True, exist_ok=True)
    DIFF.mkdir(parents=True, exist_ok=True)
    tex = LATEX / f"var-{name}.tex"
    tex.write_text(TEX.format(opts=opts, pre=pre))
    typ = ROOT / "tests/out" / f"var-{name}.typ"
    typ.write_text(TYP.format(opts=typ_opts))
    subprocess.run([str(ROOT / "tools/latex-build.sh"), str(tex)],
                   check=True, capture_output=True)
    subprocess.run([str(ROOT / "tools/tc"), "compile", str(typ),
                    str(TYPST / f"var-{name}.pdf")], check=True, capture_output=True)
    typ.unlink()


def mismatch(a, b):
    ga, gb = a.mean(axis=2), b.mean(axis=2)
    h, w = max(ga.shape[0], gb.shape[0]), max(ga.shape[1], gb.shape[1])
    def pad(g):
        o = np.full((h, w), 255.0); o[:g.shape[0], :g.shape[1]] = g[:h, :w]; return o
    return float((np.abs(pad(ga) - pad(gb)) > 40).mean()) * 100.0


def save_side(name, ref, our):
    h = max(ref.shape[0], our.shape[0]); w = max(ref.shape[1], our.shape[1])
    def pad(im):
        o = np.full((h, w, 3), 255, np.uint8); o[:im.shape[0], :im.shape[1]] = im[:h, :w]; return o
    gap = np.full((h, 16, 3), 255, np.uint8)
    Image.fromarray(np.concatenate([pad(ref), gap, pad(our)], axis=1)).save(DIFF / f"var-{name}-side.png")


def main():
    names = sys.argv[1:] or list(VARIANTS)
    print(f"{'variant':16} {'mismatch%':>9}   notes")
    print("-" * 50)
    for name in names:
        build(name)
        ref = render(LATEX / f"var-{name}.pdf")
        our = render(TYPST / f"var-{name}.pdf")
        save_side(name, ref, our)
        note = ""
        if name == "screen":
            # sample the darkest coloured (non-gray) pixel as the link colour proxy
            for tag, img in (("ref", ref), ("our", our)):
                rgb = img.reshape(-1, 3).astype(int)
                colourful = rgb[(rgb.max(1) - rgb.min(1)) > 40]
                if len(colourful):
                    c = colourful[colourful.sum(1).argmin()]
                    note += f"{tag} link rgb~{tuple(c)} "
        print(f"{name:16} {mismatch(ref, our):9.2f}   {note}")
    print(f"\nside-by-sides: {DIFF}/var-*-side.png")


if __name__ == "__main__":
    main()
