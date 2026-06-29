# tools/

The build & validation harness:

- [`test.py`](test.py) — the one command runner (`build`, `check`, `accept`,
  `diff`, `validate`, `probe`, `reference`, `example`, `list`, `clean`, plus the
  `metrics`/`linepitch` tuning views).
- [`test_matrix.py`](test_matrix.py) — the test matrix and gate data (tests, text
  assertions, metric tolerances, expected errors, validation variants, the pinned
  Typst version, and the golden DPI).
- [`tc`](tc) — `typst` wrapper that uses the bundled full Libertinus + Inconsolata
  fonts; always build through it.
- [`probe.tex`](probe.tex) — the LaTeX layout probe used by `test.py probe`.
- `venv/` — Python venv (Pillow, numpy, fonttools).

See the **Development & validation** section of the [root README](../README.md)
for setup, commands, output directories, and the gate descriptions.
