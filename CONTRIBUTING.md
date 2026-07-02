# Contributing to faithful-acmart

The port is validated by rendering both the real LaTeX acmart output and the Typst
output and diffing them page-by-page. The harness is one Python program,
`tools/test.py`, driven by `tools/test_matrix.py`; build through `tools/tc` (a `typst`
wrapper that points at the bundled `fonts/`).

```sh
python3 -m venv tools/venv && tools/venv/bin/pip install pillow numpy fonttools pymupdf pikepdf
tools/venv/bin/python tools/test.py build   # LaTeX refs + Typst PDFs + example
tools/venv/bin/python tools/test.py check   # all regression gates
tools/venv/bin/python tools/test.py accept  # bless golden hashes after an intended change
```

Building the example or running `typst init` locally needs the package linked into the
Typst data dir, e.g. on macOS:

```sh
ln -sfn "$PWD" "$HOME/Library/Application Support/typst/packages/preview/faithful-acmart/0.1.0"
```

See [DESIGN.md](DESIGN.md) for the architecture, the source-vs-output matching
decisions, and the full validation-gate reference; [`acmart/`](acmart/) is the upstream
LaTeX class being matched, and [`fonts/`](fonts/README.md) documents the bundled fonts.
