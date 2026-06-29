# tools/ — build & validation harness

The template is validated by rendering both real LaTeX acmart and the Typst
output and diffing them. Most tasks go through the root `Makefile`
(`make reference|example|test|check|accept|validate|diff`); these are the
underlying tools.

**`make check`** is the automated pass/fail gate (no manual inspection). It runs
smoke, golden, extracted-text, expected-error, and metrics gates in that order;
`tests/manifest.toml` drives the PDF-facing gates.

| tool | purpose |
|---|---|
| `tc` | **`typst` wrapper** — runs `typst … --font-path fonts --ignore-system-fonts --root .`, so builds use the bundled full Libertinus + Inconsolata OTF. Always build through this (or pass those flags); plain `typst` may pick a feature-stripped system Libertinus. |
| `latex-build.sh FILE.tex [outdir]` | compile a `.tex` to a **stable** PDF in `tests/out/latex/` (default), using `-output-directory` so no aux files land in `tests/`. **Generates `acmart.cls` from the bundled `acmart/` and puts it first on `TEXINPUTS`**, so builds use the repo's class, not the system one. Reruns pdflatex until `TotPages`/labels settle and fails on surviving "Temporary page!" or final LaTeX errors. |
| `build-reference.sh [sample]` | extract sample sources from `acmart/samples/` and compile a sample (default `acmsmall`) to `tests/out/latex/` via `latex-build.sh` (which supplies the bundled `acmart.cls`). |
| `probe.tex` (`make probe`) | dump acmsmall's ground-truth dimensions (geometry, font sizes, baselineskips, `\small/\med/\bigskip`) from the **bundled** class, to audit `src/formats/acmsmall.typ`. Prints `PROBE …`/`SIZE …` lines. |
| `pdfdiff.py REF OURS OUTDIR [--dpi --pages]` | per-page side-by-side (`side-pNN.png`) + red/blue overlay (`overlay-pNN.png`) and a numeric mismatch %. |
| `testlib.py` | shared helpers for the gates (manifest loader, page count, raster hashing, `pdftotext -bbox` word boxes, per-page layout metrics). Not run directly. |
| `check_smoke.py` (**Tier 0**, `make check`) | compile every test; FAIL on any Typst warning/error, on a page count ≠ manifest, or on broken LaTeX/Typst page-count parity. |
| `check_golden.py [--accept]` (**Tier 1**, `make check`/`make accept`) | hash each Typst page raster and compare to `tests/golden/typst.sha256`; catches any unintended output change (Typst-only, no LaTeX). `--accept` blesses the current output. |
| `check_text.py [--report]` (**Tier 1.5**, `make check`) | extract text with `pdftotext`, normalize harmless Unicode/whitespace/page-folio differences, and either require exact LaTeX-vs-Typst equality (`text_equal = true`) or run manifest semantic `contains`/`absent` assertions for noisy PDFs. `--report` prints equality/skip status and first diffs. |
| `check_errors.py` (**Tier 1.6**, `make check`) | compile temporary Typst documents that should fail and assert diagnostics for invalid copyright/CC/font-size/language/draft options. |
| `metrics.py [--report]` (**Tier 2**, `make check`) | extract layout geometry from both PDFs and gate left/top margin + baseline pitch against manifest tolerances; right margin & line count are reported only (cross-engine line-breaking makes them noisy). `--report` prints the full table. |
| `linepitch.py FILE [--dpi --page]` | measure baseline pitch / first-line position — used to tune leading & spacing. |
| `validate-variants.py [name …]` | build matched LaTeX+Typst docs for each copyright mode (incl. CC) and option (review/screen/anonymous) and diff page 1; samples link colours for `screen`. This is what caught the section-uppercase bug. |
| `venv/` | Python venv (Pillow, numpy, fonttools) for the diff scripts. Create with `python3 -m venv tools/venv && tools/venv/bin/pip install pillow numpy fonttools`. |

Requires a TeX Live install (pdflatex, bibtex) and Poppler (`pdftoppm`, `pdftotext`, `pdfinfo`).
