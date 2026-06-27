# tools/ — build & validation harness

The template is validated by rendering both real LaTeX acmart and the Typst
output and diffing them. Most tasks go through the root `Makefile`
(`make reference|example|test|validate|diff`); these are the underlying tools.

| tool | purpose |
|---|---|
| `tc` | **`typst` wrapper** — runs `typst … --font-path fonts --ignore-system-fonts --root .`, so builds use the bundled full Libertinus + Inconsolata OTF. Always build through this (or pass those flags); plain `typst` may pick a feature-stripped system Libertinus. |
| `latex-build.sh FILE.tex [outdir]` | compile a `.tex` to a **stable** PDF in `tests/out/latex/` (default), using `-output-directory` so no aux files land in `tests/`. Reruns pdflatex until `TotPages`/labels settle and **fails on a surviving "Temporary page!"** (a single pass leaves acmart's TotPages unresolved → spurious extra page). |
| `build-reference.sh [sample]` | generate `acmart.cls` from `acmart/`, extract sample sources, compile a sample (default `acmsmall`) to `tests/out/latex/`. |
| `pdfdiff.py REF OURS OUTDIR [--dpi --pages]` | per-page side-by-side (`side-pNN.png`) + red/blue overlay (`overlay-pNN.png`) and a numeric mismatch %. |
| `linepitch.py FILE [--dpi --page]` | measure baseline pitch / first-line position — used to tune leading & spacing. |
| `validate-variants.py [name …]` | build matched LaTeX+Typst docs for each copyright mode (incl. CC) and option (review/screen/anonymous) and diff page 1; samples link colours for `screen`. This is what caught the section-uppercase bug. |
| `venv/` | Python venv (Pillow, numpy, fonttools) for the diff scripts. Create with `python3 -m venv tools/venv && tools/venv/bin/pip install pillow numpy fonttools`. |

Requires a TeX Live install (pdflatex, bibtex) and Poppler (`pdftoppm`, `pdftotext`, `pdfinfo`).
