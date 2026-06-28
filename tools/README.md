# tools/ — build & validation harness

The template is validated by rendering both real LaTeX acmart and the Typst
output and diffing them. Most tasks go through the root `Makefile`
(`make reference|example|test|validate|diff`); these are the underlying tools.

| tool | purpose |
|---|---|
| `tc` | **`typst` wrapper** — runs `typst … --font-path fonts --ignore-system-fonts --root .`, so builds use the bundled full Libertinus + Inconsolata OTF. Always build through this (or pass those flags); plain `typst` may pick a feature-stripped system Libertinus. |
| `latex-build.sh FILE.tex [outdir]` | compile a `.tex` to a **stable** PDF in `tests/out/latex/` (default), using `-output-directory` so no aux files land in `tests/`. **Generates `acmart.cls` from the bundled `acmart/` and puts it first on `TEXINPUTS`**, so builds use the repo's class, not the system one. Reruns pdflatex until `TotPages`/labels settle and **fails on a surviving "Temporary page!"** (a single pass leaves acmart's TotPages unresolved → spurious extra page). |
| `build-reference.sh [sample]` | extract sample sources from `acmart/samples/` and compile a sample (default `acmsmall`) to `tests/out/latex/` via `latex-build.sh` (which supplies the bundled `acmart.cls`). |
| `probe.tex` (`make probe`) | dump acmsmall's ground-truth dimensions (geometry, font sizes, baselineskips, `\small/\med/\bigskip`) from the **bundled** class, to audit `src/formats/acmsmall.typ`. Prints `PROBE …`/`SIZE …` lines. |
| `pdfdiff.py REF OURS OUTDIR [--dpi --pages]` | per-page side-by-side (`side-pNN.png`) + red/blue overlay (`overlay-pNN.png`) and a numeric mismatch %. |
| `linepitch.py FILE [--dpi --page]` | measure baseline pitch / first-line position — used to tune leading & spacing. |
| `validate-variants.py [name …]` | build matched LaTeX+Typst docs for each copyright mode (incl. CC) and option (review/screen/anonymous) and diff page 1; samples link colours for `screen`. This is what caught the section-uppercase bug. |
| `venv/` | Python venv (Pillow, numpy, fonttools) for the diff scripts. Create with `python3 -m venv tools/venv && tools/venv/bin/pip install pillow numpy fonttools`. |

Requires a TeX Live install (pdflatex, bibtex) and Poppler (`pdftoppm`, `pdftotext`, `pdfinfo`).
