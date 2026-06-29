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
- Bibliography via the official ACM CSL
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
- Minor: ACM-CSL vs `.bst` details; author note/✉ mark order; list hanging-label
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
the Typst output and diffing them page-by-page.

```sh
# one-time: create the Python venv used by the diff tools
python3 -m venv tools/venv && tools/venv/bin/pip install pillow numpy fonttools

make reference     # build the LaTeX acmsmall reference from acmart/ (needs TeX Live)
make example       # build the Typst example
make test          # build the LaTeX references + all Typst test PDFs
make check         # smoke, golden, extracted text, expected errors, metrics
make validate      # copyright/options visual validation against LaTeX
make diff STEM=full-test PAGES=1-2   # diff a Typst output vs its LaTeX reference
```

All generated output lives under `tests/out/` (gitignored):

```
tests/out/latex/   LaTeX builds (acmart.cls, samples, reference PDFs)
tests/out/typst/   Typst output PDFs
tests/out/diff/    visual-diff images
```

Pieces:

- `tools/build-reference.sh` — extracts the sample sources from `acmart/` and
  compiles a sample to `tests/out/latex/<name>.pdf`.
- `tools/latex-build.sh` — compile any `.tex` to a *stable* PDF (reruns until
  `TotPages`/labels settle; fails on surviving "Temporary page" or final LaTeX
  errors). Builds against the `acmart.cls` generated from the bundled `acmart/`,
  never the system install.
- `tools/check_text.py` — compares normalized extracted LaTeX/Typst PDF text for
  strict tests and runs semantic assertions for noisy tests.
- `tools/check_errors.py` — verifies expected compile failures for invalid
  options.
- `tools/probe.tex` (`make probe`) — dump a format's geometry / sizes / skips from
  the bundled class to audit `src/formats/<format>.typ`.
- `tools/pdfdiff.py` — per-page side-by-side + red/blue overlay diff and a
  numeric mismatch %.
- `tools/linepitch.py` — measure baseline pitch / first-line position in a PDF.
- `tools/tc` — `typst` wrapper that uses the bundled fonts.
- `acmart/` — the upstream LaTeX acmart source (the spec being matched).

See [DESIGN.md](DESIGN.md) for the architecture and the source-vs-output
matching decisions. Each subdirectory has its own README:
[`src/`](src/README.md) (package modules), [`tools/`](tools/README.md) (harness),
[`tests/`](tests/README.md) (test docs), [`fonts/`](fonts/README.md) (bundled fonts).

## License

Template code: MIT. Bundled Libertinus and Inconsolata fonts: SIL OFL (see
`fonts/OFL.txt`). The `acmart/` directory contains the upstream acmart class
under LPPL.
