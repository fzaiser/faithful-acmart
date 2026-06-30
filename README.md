# typst-acmart

A [Typst](https://typst.app) port of the LaTeX **acmart** document class. Write
idiomatic Typst and get output that looks as close as possible to LaTeX +
acmart — same fonts, sizes, margins, spacing, top matter, and running page
styles where Typst can model them.

All public acmart formats are accepted: `manuscript`, `acmsmall`, `acmlarge`,
`acmtog`, `sigconf`, `siggraph`, `sigplan`, `sigchi`, `sigchi-a`, `acmengage`,
and `acmcp`. The obsolete `siggraph` and `sigchi` options are aliases for
`sigconf`, matching the bundled LaTeX class.

## Status

Validated page-by-page against real LaTeX acmart output (see `tools/`). Covered:

- Page geometry, body typography, exact baseline grid
- Section/subsection/subsubsection/paragraph headings, including run-in headings
- Full frontmatter: title, authors + affiliations, abstract, CCS concepts,
  keywords, ACM reference format, page-1 footnotes (author notes, contact
  information, copyright/permission), running header & footer
- Proceedings top matter: sectioned abstract/CCS/keywords, author grids,
  conference copyright blocks, and proceedings ACM reference format
- `acmcp` cover page frame, article-type color label, infobox, special footer,
  and suppressed normal copyright/contact footnotes
- Body elements: figure/table captions, theorem environments
  (theorem/lemma/…/definition/proof with QED), lists, footnotes, code
- Bibliography, two backends (`bibliography-backend`): `"csl"` (default) — native
  Typst + a vendored ACM CSL (`src/styles/`) forked to track `ACM-Reference-Format.bst`;
  or `"bst"` — a pure-Typst port of the `.bst` itself (`src/parts/{bibtex,acmref}.typ`,
  no extra dependencies) that reproduces the bibtex reference text *exactly* across
  every entry type, used via `acm-cite` / `acm-bibliography` (see DESIGN.md)
- All copyright modes (acmcopyright/acmlicensed/rightsretained, the US/Canada/other
  -gov family, iw3c2w3[g], and Creative Commons with its licence badge). Unknown
  copyright modes, CC types, and unsupported CC versions are rejected.

Known differences from LaTeX (engine limits, not spacing errors — see
[DESIGN.md](DESIGN.md)):

- **Vertical fill / `\flushbottom`**: Typst cannot vertically justify pages or
  balance final two-column pages, so output is ragged-bottom. Spacing is otherwise
  matched to the LaTeX source.
- Line/page breaking differs between engines → horizontal word drift on dense
  pages and different page breaks.
- `sigchi-a` omits margin-note footnotes; `acmcp` anchors its infobox at the
  top-right rather than LaTeX's two-pass `zref` vertical position.
- Minor: residual ACM-CSL vs `.bst` gaps (hayagriva BibTeX→CSL data limits, see
  DESIGN.md); author note/✉ mark order; list hanging-label
  indent (no LaTeX `\llap`); `screen` link colour ~1/255 (Typst 8-bit CMYK).
- Math fidelity is still best-effort.

## Requirements

- Typst 0.12+ (developed against 0.14)
- **Fonts** (see below): Libertinus Serif/Sans, Inconsolata (zi4), Libertinus
  Math

### Fonts — important

acmart uses Libertinus (text), Inconsolata/zi4 (mono), and Libertinus Math.
**The Libertinus builds shipped in some font folders are feature-stripped** (no
small caps, ligatures, or kerning), which breaks theorem small-caps and degrades
text. Use the **full OpenType** builds.

The full fonts ship with TeX Live; this repo bundles them in `fonts/` (OFL).
Build with the bundled fonts via the wrapper:

```sh
tools/tc compile template/main.typ
tools/tc watch template/main.typ
```

(`tools/tc` runs `typst … --font-path fonts --ignore-system-fonts --root .`.)

If you install the full Libertinus + Inconsolata fonts system-wide, you can run
`typst` directly without the font flags.

## Usage

```typst
#import "/src/lib.typ": acmart, theorem, lemma, definition, proof
// once published: #import "@preview/acmart:0.0.1": *

#show: acmart.with(
  format: "acmsmall",
  title: "Your Title",
  journal: "JACM",
  acm-volume: 37, acm-number: 4, acm-article: 111,
  acm-year: 2018, acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed", copyright-year: 2018,
  authors: (
    (name: "Ada Lovelace", email: "ada@example.org", corresponding: true,
     affiliation: (institution: "Analytical Engine Co.",
                   city: "London", country: "UK")),
  ),
  abstract: [Your abstract.],
  ccs: ((500, "Computing methodologies", "Massively parallel algorithms"),),
  keywords: ("one", "two"),
)

= Introduction
Write normal Typst. Cite with @key, add figures, theorems, and a bibliography.

#bibliography("refs.bib")
```

A complete example is in [`template/main.typ`](template/main.typ).

### Key parameters

| Parameter | Meaning |
|---|---|
| `format` | Layout format. Accepted: `manuscript`, `acmsmall`, `acmlarge`, `acmtog`, `sigconf`, `siggraph`/`sigchi` (aliases), `sigplan`, `sigchi-a`, `acmengage`, `acmcp` |
| `title`, `subtitle` | Paper title / subtitle |
| `title-note`, `subtitle-note` | Footnotes anchored to the title / subtitle (symbol marks, in the page-1 footnote stack) |
| `authors` | List of author dicts: `name`, `email`, `orcid`, `note`, `corresponding`, `affiliation` (a `(institution, city, state, country)` dict, or an array of such dicts for several affiliations) |
| `abstract` | Abstract content |
| `ccs` | List of `(significance, area, concept)` — ≥500 bold, ≥300 italic, else roman |
| `keywords` | List/array of keywords |
| `teaser` | A full-width figure placed between the authors and the abstract |
| `badges` | Artifact-evaluation badges for the page-1 header: `(left: …, right: …)` content (e.g. a `36pt`-wide `image`) |
| `received` | Paper history (end of document): a string, or an array of `(stage, date)` items (empty stage → "Received"/"revised") |
| `journal`, `acm-volume`, `acm-number`, `acm-article`, `acm-year`, `acm-month`, `doi` | Publication metadata |
| `conference`, `booktitle`, `isbn` | Proceedings metadata |
| `copyright`, `copyright-year`, `cc-type`, `cc-version` | Copyright/CC metadata; invalid values fail at compile time |
| `code-data-link`, `contributions`, `article-type` | `acmcp` infobox/article-type metadata |
| `short-title`, `short-authors` | Running-head overrides (auto-derived otherwise) |

Theorem-like environments: `theorem`, `lemma`, `corollary`, `proposition`,
`conjecture`, `definition`, `example`, `remark`, `proof`. They share one counter
numbered within the section, e.g. `#theorem(name: "Optional")[…]`. The `acks`
function emits the unnumbered "Acknowledgments" section (`#acks[…]`; suppressed
under `anonymous`).

## Development & validation

The template is validated by rendering both the **real LaTeX acmart** output and
the Typst output and diffing them page-by-page. The whole harness is one Python
program, `tools/test.py`, driven by the test matrix in `tools/test_matrix.py`.

### Setup

```sh
# one-time: create the Python venv used by the harness
python3 -m venv tools/venv && tools/venv/bin/pip install pillow numpy fonttools
```

You also need **Typst**, a **TeX Live** install (`pdflatex`, `bibtex`), and
**Poppler** (`pdftoppm`, `pdftotext`, `pdfinfo`) on `PATH`. All commands below
build through `tools/tc`, the `typst` wrapper that points Typst at the bundled
full Libertinus + Inconsolata fonts (see [Fonts](#fonts--important)).

### Commands

```sh
PY=tools/venv/bin/python

$PY tools/test.py build                     # LaTeX references + all Typst PDFs + the example
$PY tools/test.py check                     # all regression gates (compiles Typst once, then gates)
$PY tools/test.py accept                    # rebuild Typst PDFs and bless the golden hashes
$PY tools/test.py overlay                   # per twin: <name>-overlay.pdf (Typst red / LaTeX blue) + <name>-side-by-side.pdf
$PY tools/test.py overlay acmcp-test sigchi-a-test  # ... or just the named twins
$PY tools/test.py validate                  # copyright/option variants vs LaTeX (mismatch %)
$PY tools/test.py probe --format sigconf    # dump a format's dimensions from the bundled class
$PY tools/test.py reference                 # build just the LaTeX acmsmall sample reference
$PY tools/test.py example                   # build just the Typst example
$PY tools/test.py list                      # print the test matrix
$PY tools/test.py clean                     # remove tests/out/
```

`tools/test.py metrics` prints the Tier 2 layout-metric table (no gating) and
`tools/test.py linepitch FILE.pdf` measures baseline pitch — both for tuning.

**Speed.** LaTeX is ~90% of a run's wall time (each `pdflatex` pass is ~0.6s and
acmart needs several per doc), so `build`, `check`, and `validate` build the
twin/variant references **in parallel** (`-j`, default `cpu-2`) and **skip
references whose cached PDF is already up to date** with its `.tex` and the
shared inputs (the class source, sample/twin bibs, the `.bst`). Editing only the
Typst port leaves every reference cached, so the inner loop is dominated by the
~20ms-per-file Typst compiles. Use `-j N` to cap parallelism and `--force` to
rebuild every reference (use it if you ever suspect a stale cache):

```sh
$PY tools/test.py check -j8        # at most 8 concurrent pdflatex builds
$PY tools/test.py build --force    # ignore the cache, rebuild all LaTeX refs
```

### Output

All generated output lives under `tests/out/` (gitignored):

```
tests/out/latex/   LaTeX builds: acmart.cls (from the bundled acmart/), samples, reference PDFs (+ aux)
tests/out/typst/   Typst output PDFs
tests/out/diff/    <name>-overlay.pdf / <name>-side-by-side.pdf — per-twin vector visual diffs from `overlay`
```

The committed golden artifact is `tests/golden/typst.sha256`.

### Tests

Tests are **matched twins** — `NAME.tex` (real LaTeX acmart) and `NAME.typ`
(ours) with identical content, diffed page-by-page — plus a Typst-only
**upstream-ref** port (`sample-acmsmall`, compared against the bundled sample
reference) and a few **smoke** docs (no LaTeX twin: alias/feature paths,
compiled and where deterministic golden-hashed). `tools/test.py list` prints the
full matrix; `tools/test_matrix.py` is the source of truth.

### Gates (`tools/test.py check`)

The harness compiles every Typst test once, captures warnings, then runs all
gates without recompiling:

- **Tier 0 (smoke)** — every test compiles with no warnings, page counts match,
  twins keep LaTeX/Typst page-count parity.
- **Tier 1 (golden)** — each Typst page raster is hashed and compared to
  `tests/golden/typst.sha256` (Typst is deterministic for a pinned engine +
  bundled fonts). After an intended change, `tools/test.py accept` refreshes it.
- **Tier 1.5 (text)** — `pdftotext` extraction is normalized and compared exactly
  for stable twins (`text_equal`), or with targeted `contains`/`absent`
  assertions for noisy PDFs (two-column order, author grids, bibliography).
- **Tier 1.6 (expected errors)** — invalid option cases must fail with the
  intended diagnostic.
- **Tier 2 (metrics)** — cross-engine layout geometry (left/top margin, baseline
  pitch) gated against `test_matrix` tolerances; right margin & line count are
  reported only (cross-engine line-breaking makes them noisy).

`tools/test.py validate` is a separate, representative visual suite over the
copyright modes and document options (the package supports every copyright mode;
the suite samples the common ones plus the options whose effect shows on page 1).

See [DESIGN.md](DESIGN.md) for the architecture and the source-vs-output
matching decisions, and [`acmart/`](acmart/) for the upstream LaTeX class being
matched. The bundled fonts are documented in [`fonts/`](fonts/README.md).

## License

Template code: MIT. Bundled Libertinus and Inconsolata fonts: SIL OFL (see
`fonts/OFL.txt`). The `acmart/` directory contains the upstream acmart class
under LPPL.
