# Contributing

## Setup

Install `uv` and `typst-package-check`.
Reproducible comparisons require pinned tools:

| Tool | Version and setup |
|---|---|
| Typst | `TYPST_VERSION` in [test_matrix.py](tools/test_matrix.py); installation commands in [CI](.github/workflows/tests.yml) |
| Python dependencies | `uv sync --frozen` |
| TeX Live | The `texlive` command installs the [pinned distribution](tools/texlive.py) in your user cache. |

```sh
uv sync --frozen
uv run python tools/test.py texlive
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

Run the unit tests and the full regression suite before submitting changes:

```sh
uv run python tools/test.py unit
uv run python tools/test.py check
```

`check` builds reference PDFs from the bundled LaTeX class and bibliography styles.
It compares text, typography, layout, and PDF semantics, checks Typst raster goldens, and validates the distributable package.
Use `check --help` for the current gates.

Fixtures live in `tests/twins/` as matching `.tex` and `.typ` documents, in `tests/typst-only/` for smoke tests, and in `tests/unit/` for logic tests.
Register document fixtures and their expectations in [tools/test_matrix.py](tools/test_matrix.py).
Keep paired fixtures equivalent in content and intent.

The package check compiles a fresh starter project and every `typst` example in the README and `docs/` against the distributable files.
It does not require a locally installed package.
The `example` command does; see [local package testing](PUBLISHING.md#local-package-testing).

## Investigating a difference

Start with a targeted build and comparison:

```sh
uv run python tools/test.py smoke body-test
uv run python tools/test.py report body-test
```

Open `tests/out/report/index.html` for side-by-side pages and an overlay: blue for LaTeX, red for Typst.
Without a fixture name, `report` selects failures from the last `check`.

Read [DESIGN.md](DESIGN.md) before changing layout assumptions.
Use `tools/test.py probe --format <name>` to measure the bundled class, and the `text`, `metrics`, or `linepitch` commands to inspect output; each has `--help`.
`source-data` checks transcribed data against upstream sources, and `bib-oracle` compares the bibliography reader with BibTeX.
For bibliography date changes, compare the affected forms with Biber and update the reference's capability statement.

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
Likewise, moving the TeX Live pin requires inspecting every recorded residual that changes.
If a test starts loading a package missing from the pinned install, add it to the package list in `tools/texlive.py`.
Use `compat` to check a different Typst release without applying the pinned raster expectations.

## Documentation

Keep each explanation in the document that serves its reader:

| Document | Purpose |
|---|---|
| [README](README.md) | Typst Universe showcase and quick start |
| [Starter](template/main.typ) | A guide with working examples in an ACM-style paper |
| [Reference](docs/reference.md) | Option contracts and user-visible limits |
| [Design](DESIGN.md) | Architecture and design constraints |
| [Publishing](PUBLISHING.md) | Release workflow |

Write for human readers, using concrete examples, short explanations, and tables where they help comparison.
Introduce each section with a sentence before a table or list.
Link to detailed restrictions instead of repeating them.
Keep measurements and test expectations in code, with comments only for non-obvious constraints.

Examples are compiled by the package check:

- Use a column-zero backtick fence labelled `typst`; use a longer fence around examples containing raw blocks.
- Body-only snippets receive an `acmsmall` preamble; snippets with a show rule receive only the package import.
- To render an illustration, put `<!-- render: name -->` before the fence and link to `docs/assets/name.svg` from the README, or `assets/name.svg` from `docs/`.
- Add `compact` after the name to trim margins and large blank gaps.
  Caption these illustrations to explain the omitted space.
- The starter illustration shows the first page of `template/main.typ`.

Regenerate and check illustrations with the pinned compiler:

```sh
uv run python tools/test.py docs
uv run python tools/test.py package
```

Inspect changed SVGs before committing them.
The package check rejects stale illustrations and checks links, headings, and package versions.
