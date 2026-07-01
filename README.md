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
- Bibliography, three backends (`bib-backend`): `"typst"` (default) — native
  Typst + a vendored ACM CSL (`src/styles/`) forked to track `ACM-Reference-Format.bst`;
  or `"bibtex"` — a pure-Typst port of the `.bst` itself (`src/parts/{bibtex,acmref}.typ`,
  no extra dependencies) that reproduces the bibtex reference text *exactly* across
  every entry type; or `"biblatex"` — a pure-Typst ACM BibLaTeX renderer for
  `acmnumeric` / `acmauthoryear` reference formatting, including ACM's
  `biblatex-software` artifact entries. All three are driven by idiomatic native
  syntax — `@key`, grouped `#cite(<a>, <b>)`, `#bibliography("/refs.bib")` (the
  `cite` and `bibliography` names are shadowed to route through the active backend) —
  plus `cite-text` / `cite-year` / `cite-author` for textual citations (see DESIGN.md)
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
- `sigchi-a` omits margin-note footnotes; `acmcp` top-aligns its cover infobox
  with the body rather than LaTeX's two-pass `zref` bottom-anchoring.
- Minor: residual ACM-CSL vs `.bst` gaps (hayagriva BibTeX→CSL data limits);
  author note/✉ mark order; list hanging-label
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

Import with the wildcard (`*`). Besides `acmart` and the theorem environments, it
brings in the **shadowed `cite` and `bibliography`** and the textual-citation
helpers (`cite-text` / `cite-year` / `cite-author`) — these route `#cite` and
`#bibliography` through the active `bib-backend`, so they must be in scope. With a
selective import you would get Typst's built-ins instead, which only work on the
default `"typst"` backend.

```typst
#import "/src/lib.typ": *
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
python3 -m venv tools/venv && tools/venv/bin/pip install pillow numpy fonttools pymupdf pikepdf
```

You also need **Typst**, a **TeX Live** install (`pdflatex`, `bibtex`),
**Poppler** (`pdftoppm`, `pdftotext`, `pdfinfo`), and **qpdf** on `PATH`. All
commands below build through `tools/tc`, the `typst` wrapper that points Typst
at the bundled full Libertinus + Inconsolata fonts (see [Fonts](#fonts--important)).

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
shared inputs (the class source, sample/twin bibs and media, the `.bst`). Editing only the
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
  twins keep LaTeX/Typst page-count parity. A nonempty
  `expected_page_count_diff` documents the one accepted parity mismatch and fails
  if the page counts later match.
- **Tier 1 (golden)** — each Typst page raster is hashed and compared to
  `tests/golden/typst.sha256` (Typst is deterministic for a pinned engine +
  bundled fonts). `golden_exempt` must explain any test that is not golden-pinned.
  After an intended change, `tools/test.py accept` refreshes it.
- **Tier 1.5 (text)** — `pdftotext` extraction is normalized and compared exactly
  for stable twins (`text_equal`), or with targeted `contains`/`absent`
  assertions for noisy PDFs (two-column order, author grids, bibliography).
  Twins that exempt sequence or char-bag equality must carry
  validated `expected_text_diffs`: coherent LaTeX/Typst fragments that show the
  tolerated extracted-text difference. Each diff carries an
  `ExtractionArtifact("...")` or `TypstTranslation("...")` cause.
- **Tier 1.6 (expected errors)** — invalid option cases must fail with the
  intended diagnostic.
- **Tier 1.7 (hyperlinks)** — every twin's `/URI` link set is compared against
  LaTeX+hyperref with `qpdf` object-stream decoding (links are invisible to
  `pdftotext`). A nonempty
  `expected_link_diff` documents an expected mismatch; the gate fails if the
  field is empty and links differ, or if the field is set and links match.
- **Tier 1.8 (fonts)** — per-letter font check via **PyMuPDF**: every alphabetic
  character must render in the same family (serif/sans/mono), weight, italic, size,
  and colour as LaTeX. Catches what the text gates (characters only) can't — a wrong
  family (serif where acmart sets `\sffamily`), a too-small author block, a stray
  colour. Mono *size* is skipped (LaTeX's zi4 and the bundled Inconsolata scale
  differently); `expected_font_diffs` document known content/math gaps and anchor
  them to validated PDF fragments. The raw font comparison still runs and fails
  if an expected font diff has gone stale.
- **Tier 1.9 (order)** — per-chunk reading-order check via **pikepdf**
  (`tools/pdf_chunks.py`): Typst writes a *tagged* PDF, so each logical chunk
  (title, an author line, the contact-info block, a heading, a bib entry) is read
  back in logical order from the structure tree and its tokens checked — by LCS
  alignment — to occur in that order in the *flat* (untagged) LaTeX `pdftotext`
  stream. Catches an element emitted out of order (an affiliation/email swap, a
  reordered citation field) that the order-independent word/char bags can't see;
  the LCS sub-sequence match is immune to reflow, page breaks and column flow.
  `expected_order_diffs` document known extraction-order asymmetries and anchor
  them to validated PDF fragments. The raw order comparison still runs and fails
  if an expected order diff has gone stale. Run
  `tools/test.py order` for a per-twin report, or
  `tools/pdf_chunks.py <stem>` to dump one document's chunks + per-chunk disorder.
- **Tier 2 (metrics)** — cross-engine layout geometry (left/top margin, baseline
  pitch) gated against `test_matrix` tolerances; right margin & line count are
  reported only (cross-engine line-breaking makes them noisy). A nonempty
  `metrics_page1_only` documents why a multi-page twin compares page 1 only.
  A nonempty `metrics_uniform_pitch` documents why baseline pitch is meaningful
  enough to gate. A nonempty `expected_metrics_diff` documents a known metric
  mismatch and fails if metrics later pass.

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
