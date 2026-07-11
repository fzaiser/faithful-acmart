# tools/

The build & validation harness:

- [`test.py`](test.py) — the one command runner (`build`, `check`, `accept`,
  `overlay`, `validate`, `probe`, `example`, `list`, `clean`, plus the
  `metrics`/`linepitch` tuning views, the `sweep` format×size compile net, and
  the on-demand `bib-oracle` that checks the pure-Typst `.bib` reader against the
  real `bibtex` binary over the twins' `.bib` files and the well-formed mutation
  corpus in [`../tests/bib-oracle/`](../tests/bib-oracle/)).
  Its LaTeX oracle stages the repository's ACM `.bbx`/`.cbx`/`.dbx`,
  biblatex-software files, BST, and audited `amsart.cls` beside the generated
  class. Nonzero TeX/BibTeX/Biber exits and unresolved rerun state are fatal, so
  a system TeX Live update cannot silently redefine the reference output.
  `test.py` itself is only the CLI: the machinery lives in focused sibling
  modules it imports —
  [`harness.py`](harness.py) (paths, clock, Typst compile, parallel map),
  [`pdf_extract.py`](pdf_extract.py) (PDF readers + per-run cache),
  [`latex_build.py`](latex_build.py) (reference builds + LaTeX oracle),
  [`source_data.py`](source_data.py) (dtx/BST/copyright parsers + package gate),
  [`gate_residuals.py`](gate_residuals.py) (shared expected-diff helpers),
  [`gates_core.py`](gates_core.py) (matrix/smoke/golden/errors/unit/sweep),
  [`gates_text.py`](gates_text.py) (text/bag gate),
  [`gates_semantic.py`](gates_semantic.py) (metadata/links/fonts/structure/order/outline),
  [`gates_layout.py`](gates_layout.py) (metrics/word-positions/rules),
  [`overlay.py`](overlay.py) (vector overlay/side-by-side),
  [`validate.py`](validate.py) (copyright/option variants),
  [`report.py`](report.py) (the `report` HTML comparison view), and
  [`bib_oracle.py`](bib_oracle.py) (the on-demand `.bib`-reader oracle).
- `test.py report [<stem> …]` writes a self-contained
  `tests/out/report/index.html` (with page PNGs alongside it) placing each twin's
  LaTeX and Typst pages side by side, plus the vector overlay (Typst red / LaTeX
  blue) as a third column where Ghostscript/qpdf are present, and heads each twin
  with the gates that flagged it in the most recent `check`. With no stems it
  defaults to the twins that failed that check. All output is under `tests/out/`
  (gitignored); no baseline images are stored in git.
- [`test_matrix.py`](test_matrix.py) — the test matrix and gate data (tests, text
  assertions, metric tolerances, expected errors, validation variants, the pinned
  Typst version, and the golden DPI).
- [`tc`](tc) — `typst` wrapper that uses the bundled full Libertinus + Inconsolata
  fonts; always build through it.
- [`probe.tex`](probe.tex) — the LaTeX layout probe used by `test.py probe`.
- [`../pyproject.toml`](../pyproject.toml) / [`../uv.lock`](../uv.lock) — uv-managed
  Python dependencies for the visual and PDF-structure gates.

See [`../CONTRIBUTING.md`](../CONTRIBUTING.md) for setup, commands, output
directories, and the gate descriptions.
