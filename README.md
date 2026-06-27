# typst-acmart

A [Typst](https://typst.app) port of the LaTeX **acmart** document class. Write
idiomatic Typst and get output that looks as close as possible to LaTeX +
acmart — same fonts, sizes, margins, and spacing.

Currently implements the **`acmsmall`** format (single-column ACM journal). The
architecture keeps formats pluggable (`src/formats/`), so others (`sigconf`,
`sigplan`, …) can be added later.

## Status

Validated page-by-page against real LaTeX acmart output (see `tools/`). What
works for `acmsmall`:

- Page geometry, body typography, exact baseline grid
- Section/subsection/subsubsection/paragraph headings (incl. run-in)
- Full frontmatter: title, authors + affiliations, abstract, CCS concepts,
  keywords, ACM reference format, page-1 footnotes (author notes, contact
  information, copyright/permission), running header & footer
- Body elements: figure/table captions, theorem environments
  (theorem/lemma/…/definition/proof with QED), lists, footnotes, code
- Bibliography via the official ACM CSL

Differences from LaTeX are limited to engine-level line/page breaking and minor
bibliography-CSL details.

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
| `format` | Layout format (`"acmsmall"`) |
| `title`, `subtitle` | Paper title / subtitle |
| `authors` | List of author dicts: `name`, `email`, `orcid`, `note`, `corresponding`, `affiliation: (institution, city, state, country)` |
| `abstract` | Abstract content |
| `ccs` | List of `(significance, area, concept)` — ≥500 bold, ≥300 italic, else roman |
| `keywords` | List/array of keywords |
| `journal`, `acm-volume`, `acm-number`, `acm-article`, `acm-year`, `acm-month`, `doi` | Publication metadata |
| `copyright`, `copyright-year` | Copyright mode (e.g. `"acmlicensed"`) |
| `short-title`, `short-authors` | Running-head overrides (auto-derived otherwise) |

Theorem-like environments: `theorem`, `lemma`, `corollary`, `proposition`,
`conjecture`, `definition`, `example`, `remark`, `proof`. They share one counter
numbered within the section, e.g. `#theorem(name: "Optional")[…]`.

## Development

The reference LaTeX output and the visual-diff harness live in `reference/` and
`tools/`:

- `tools/pdfdiff.py` — per-page side-by-side + overlay diff of two PDFs
- `tools/linepitch.py` — measure baseline pitch / first-line position
- `acmart/` — the upstream LaTeX acmart source (the spec)

Regenerate the LaTeX references from `acmart/` and compare against Typst output.

## License

Template code: MIT. Bundled Libertinus and Inconsolata fonts: SIL OFL (see
`fonts/OFL.txt`). The `acmart/` directory contains the upstream acmart class
under LPPL.
