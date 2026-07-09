# Contributing to faithful-acmart

Thanks for helping improve `faithful-acmart`. The project aims to keep user-facing
Typst source pleasant while matching LaTeX `acmart` output as closely as Typst can.

## Development setup

Sync the local Python environment used by the validation harness:

```sh
uv sync
```

The harness is one Python program, [`tools/test.py`](tools/test.py), driven by the
matrix in [`tools/test_matrix.py`](tools/test_matrix.py). Build through
[`tools/tc`](tools/tc), a `typst` wrapper that points at the bundled development
fonts in [`fonts/`](fonts/).

Common commands:

```sh
uv run python tools/test.py build   # LaTeX refs + Typst PDFs + example
uv run python tools/test.py check   # all regression gates
uv run python tools/test.py accept  # bless golden hashes after an intended change
```

Building the example or running `typst init` locally needs the package linked into
Typst's data directory. On macOS:

```sh
ln -sfn "$PWD" "$HOME/Library/Application Support/typst/packages/preview/faithful-acmart/0.1.0"
```

The matched twins import `/src/lib.typ` directly, so `uv run python tools/test.py check`
does not need this package link.

## Validation model

The port is validated by rendering both the real LaTeX `acmart` output and the Typst
output, then comparing them page-by-page. LaTeX references are built from the bundled
upstream sources in [`acmart/`](acmart/), not from the system TeX installation.

The main check builds the LaTeX references, compiles every Typst test once, and then
runs the gates:

- warning and page-count smoke checks
- committed Typst raster hashes in `tests/golden/`
- extracted-text equality and semantic assertions
- expected compile-error checks
- cross-engine layout metrics

`tools/test.py validate` separately builds copyright and option variants and reports
page-1 mismatch percentages. `tools/test.py probe --format <name>` audits layout
measurements against the LaTeX class.

## What the tests cover

The validation suite checks:

- Page geometry, body typography, baseline grid, and headings, including run-in
  headings.
- Front matter: title, authors and affiliations, abstract, CCS concepts, keywords,
  ACM reference format, page-1 footnotes, and running headers/footers.
- Proceedings top matter, author grids, and conference copyright blocks.
- The `acmcp` cover page frame, article-type label, infobox, and footer.
- Figure and table captions, theorem environments, lists, footnotes, code, and
  bibliography rendering.
- Copyright modes, including Creative Commons badge output and invalid-value errors.

Test documents live in [`tests/`](tests/):

| Path | Contents |
|---|---|
| `tests/twins/` | Matched `.tex` and `.typ` documents diffed against each other |
| `tests/typst-only/` | Typst-only smoke, alias, and feature checks |
| `tests/golden/` | Committed Tier 1 raster hashes |
| `tests/out/` | Generated PDFs, images, and diffs; gitignored |

The test matrix determines which directory a test belongs to and which gates apply.

## Working on layout code

Read [`DESIGN.md`](DESIGN.md) before changing layout behavior. It documents the
architecture, source-vs-output matching decisions, known limitations, and the
measurement model used by the port.

Useful pointers:

- [`src/lib.typ`](src/lib.typ) is the public `acmart(...)` entry point.
- [`src/formats/`](src/formats/) contains one builder per public format.
- [`src/parts/spacing.typ`](src/parts/spacing.typ) centralizes the TeX-to-Typst
  baseline-grid conversion.
- [`src/parts/frontmatter.typ`](src/parts/frontmatter.typ),
  [`src/parts/body.typ`](src/parts/body.typ), and
  [`src/parts/headings.typ`](src/parts/headings.typ) hold most visible layout rules.
- [`src/parts/acmref*.typ`](src/parts/) and [`src/parts/bibtex.typ`](src/parts/bibtex.typ)
  implement the ACM bibliography backends.

When changing measurements, re-derive values from the bundled `acmart` sources or a
probe, then run the relevant targeted test before the full `check` gate.

## Repository notes

[`typst.toml`](typst.toml) excludes development-only files from the published Typst
Universe bundle: the upstream LaTeX sources, tests, tools, development fonts,
contributor docs, and trademarked ACM logo sample.

The fonts in [`fonts/`](fonts/) are mirrored for development and validation. They are
not bundled with the published package, so user-facing documentation should continue
to tell users to provide the required fonts themselves.
