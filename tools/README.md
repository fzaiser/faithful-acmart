# tools/

The build & validation harness:

- [`test.py`](test.py) — the one command runner (`build`, `check`, `accept`,
  `overlay`, `validate`, `probe`, `example`, `list`, `clean`, plus the
  `metrics`/`linepitch` tuning views).
  Its LaTeX oracle stages the repository's ACM `.bbx`/`.cbx`/`.dbx`,
  biblatex-software files, BST, and audited `amsart.cls` beside the generated
  class. Nonzero TeX/BibTeX/Biber exits and unresolved rerun state are fatal, so
  a system TeX Live update cannot silently redefine the reference output.
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
