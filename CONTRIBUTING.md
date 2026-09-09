# Contributing

## Setup

Install `uv`, a TeX distribution providing `pdflatex`, `bibtex`, and `biber`, and `typst-package-check`.
Use the Typst version pinned by `TYPST_VERSION` in [tools/test_matrix.py](tools/test_matrix.py); raster goldens depend on that compiler and the locked Python dependencies.
The [CI workflow](.github/workflows/tests.yml) records the tested installation commands and system packages.

```sh
uv sync --frozen
```

Compile repository documents through `tools/tc`.
It supplies the project root and bundled fonts, isolating output from system font versions.
For example:

```sh
mkdir -p tests/out
tools/tc compile tests/twins/body-test.typ tests/out/body-test.pdf
```

Generated files belong in `tests/out/`; private working notes belong in `scratch/`.
Both are ignored by Git.

## Validation

```sh
uv run python tools/test.py unit
uv run python tools/test.py check
```

`check` builds reference PDFs from the bundled LaTeX class and bibliography styles, rerunning TeX until references stabilize.
It compares text, typography, layout, and PDF semantics, checks Typst raster goldens, and validates the distributable package.
Use `check --help` for the current gates.

Fixtures live in `tests/twins/` as matching `.tex` and `.typ` documents, in `tests/typst-only/` for smoke tests, and in `tests/unit/` for logic tests.
Register document fixtures and their expectations in [tools/test_matrix.py](tools/test_matrix.py).
Keep paired fixtures equivalent in content and intent.

The package check compiles a fresh starter project and every `typst` example in the README against the distributable files.
It does not require a locally installed package.
The `example` command does; see [local package testing](PUBLISHING.md#local-package-testing).

## Investigating a difference

Start with a targeted build and comparison:

```sh
uv run python tools/test.py smoke body-test
uv run python tools/test.py report body-test
```

The HTML report in `tests/out/report/index.html` shows both PDFs side by side.
With Ghostscript and qpdf installed, it also includes a vector overlay.
Without a fixture name, `report` selects failures from the last `check`.

Read [DESIGN.md](DESIGN.md) before changing layout assumptions.
Use `tools/test.py probe --format <name>` to measure the bundled class, and the `text`, `metrics`, or `linepitch` commands to inspect output; each has `--help`.
`source-data` checks transcribed data against upstream sources, and `bib-oracle` compares the bibliography reader with BibTeX.

Fix the implementation or fixture when a comparison reveals a bug.
For an accepted engine difference, record its cause and bounded expectation in the matrix.
Avoid broadening text normalization to absorb a local mismatch: that weakens checks for every document.
Exemptions must fail when their expected difference disappears.

## Updating baselines

After inspecting an intended rendering change, regenerate raster hashes:

```sh
uv run python tools/test.py accept
uv run python tools/test.py check
```

A compiler or rasterizer upgrade also requires inspecting the resulting page changes before accepting new hashes.
Use `compat` to check a different Typst release without applying the pinned raster expectations.

## Documentation

Keep paper-writing guidance in [README.md](README.md), architectural decisions and compatibility limits in [DESIGN.md](DESIGN.md), and release steps in [PUBLISHING.md](PUBLISHING.md).
Option defaults, format measurements, and test expectations belong in code.
Comments should explain constraints or surprising choices that the surrounding code cannot explain.
