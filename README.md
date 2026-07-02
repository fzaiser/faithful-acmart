# faithful-acmart

A [Typst](https://typst.app) port of the LaTeX **acmart** document class. Write
idiomatic Typst and get output that looks as close as possible to LaTeX + acmart —
same fonts, sizes, margins, spacing, top matter, and running-page styles where Typst
can model them, validated page-by-page against real LaTeX acmart.

All public acmart formats are accepted: `manuscript`, `acmsmall`, `acmlarge`,
`acmtog`, `sigconf`, `siggraph`, `sigplan`, `sigchi`, `sigchi-a`, `acmengage`, and
`acmcp` (`siggraph`/`sigchi` are aliases for `sigconf`, matching the bundled class).

## Getting started

```sh
typst init @preview/faithful-acmart:0.1.0
```

or import the package into an existing document:

```typst
#import "@preview/faithful-acmart:0.1.0": *

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
     affiliation: (institution: "Analytical Engine Co.", city: "London", country: "UK")),
  ),
  abstract: [Your abstract.],
  ccs: ((500, "Computing methodologies", "Massively parallel algorithms"),),
  keywords: ("one", "two"),
)

= Introduction
Write normal Typst. Cite with @key, add figures, theorems, and a bibliography.

#bibliography("refs.bib")
```

Import with the wildcard (`*`): besides `acmart` and the theorem environments it
brings in the **shadowed `cite` and `bibliography`** and the textual-citation helpers
(`cite-text` / `cite-year` / `cite-author`), which route `#cite` / `#bibliography`
through the active bibliography backend and must be in scope. A complete example is in
[`template/main.typ`](template/main.typ).

## Fonts (required)

acmart is set in **Libertinus** (text + math) and **Inconsolata** (`zi4`, for
monospace). Typst embeds only *Libertinus Serif*, and Typst packages cannot ship
fonts, so you must provide the rest yourself — the exact families the template asks for
are:

`Libertinus Serif`, `Libertinus Sans`, `Libertinus Math`, and `Inconsolatazi4`.

- **Command line:** put the font files in a folder and compile with
  `typst compile --font-path <folder> main.typ`, or install the fonts system-wide.
- **Web app:** upload the font files into your project; Typst detects project fonts
  automatically.

Libertinus is available from the [Libertinus project](https://github.com/alerque/libertinus/releases)
(OFL); the `Inconsolatazi4` OpenType files ship with TeX Live's `inconsolata` package.
Both font families are also kept, unmodified, in this repository's `fonts/` directory
(SIL Open Font License). Without them, the sans-serif headings/titles, math, and
monospace fall back to substitute fonts and the output will not match acmart.

## Parameters

| Parameter | Meaning |
|---|---|
| `format` | Layout format (see the list above) |
| `title`, `subtitle` | Paper title / subtitle |
| `title-note`, `subtitle-note` | Footnotes anchored to the title / subtitle |
| `authors` | List of author dicts: `name`, `email`, `orcid`, `note`, `corresponding`, `affiliation` (an `(institution, city, state, country)` dict, or an array of them) |
| `abstract` | Abstract content |
| `ccs` | List of `(significance, area, concept)` — ≥500 bold, ≥300 italic, else roman |
| `keywords` | List/array of keywords |
| `teaser` | A full-width figure placed between the authors and the abstract |
| `badges` | Artifact-evaluation badges for the page-1 header: `(left: …, right: …)` |
| `received` | Paper history (end of document): a string or `(stage, date)` items |
| `journal`, `acm-volume`, `acm-number`, `acm-article`, `acm-year`, `acm-month`, `doi` | Publication metadata |
| `conference`, `booktitle`, `isbn` | Proceedings metadata |
| `copyright`, `copyright-year`, `cc-type`, `cc-version` | Copyright / CC metadata; invalid values fail at compile time |
| `code-data-link`, `contributions`, `article-type` | `acmcp` cover metadata |
| `acmcp-logo` | The journal logo shown on the `acmcp` cover, as content (e.g. `image("logo.png")`). **Required by the `acmcp` format** — the ACM journal logo is ACM's trademark and is not bundled, so supply your own |
| `bib-backend`, `cite-style` | Bibliography engine (see below) and `"numeric"` / `"author-year"` |
| `short-title`, `short-authors` | Running-head overrides (auto-derived otherwise) |

**Theorem environments:** `theorem`, `lemma`, `corollary`, `proposition`,
`conjecture`, `definition`, `example`, `remark`, `proof` — one shared counter numbered
within the section, e.g. `#theorem(name: "Optional")[…]`. `#acks[…]` emits the
unnumbered "Acknowledgments" section (suppressed under `anonymous`).

## Bibliography backends

`bib-backend` selects how the reference list and citations are rendered:

- **`"bibtex"` (default)** — a pure-Typst port of `ACM-Reference-Format.bst`, matching
  LaTeX acmart's own default (natbib + BibTeX). Reproduces the bibtex reference text
  exactly across every entry type. *Current limitation:* in-text citations are not yet
  hyperlinked to the reference list (links within reference entries — DOI/arXiv/URL —
  do work).
- **`"typst"`** — Typst's native `bibliography()` with its built-in ACM CSL style.
  Idiomatic, and in-text citations link to the reference list, but it is an
  **approximation**: it is bounded by hayagriva's BibTeX→CSL data mapping.
- **`"biblatex"`** — a pure-Typst ACM BibLaTeX renderer (`acmnumeric` / `acmauthoryear`,
  including `biblatex-software` artifacts).

All three use idiomatic native syntax — `@key`, grouped `#cite(<a>, <b>)`, and
`#bibliography("refs.bib")`.

## What's covered

Validated page-by-page against real LaTeX acmart:

- Page geometry, body typography, the exact baseline grid, headings (incl. run-in)
- Full frontmatter: title, authors + affiliations, abstract, CCS, keywords, the ACM
  reference format, page-1 footnotes (author notes, contact info, copyright), and the
  running header/footer — plus the proceedings top matter and author grids
- `acmcp` cover page: frame, article-type label, infobox, and special footer
- Figure/table captions, theorem environments (with QED), lists, footnotes, code
- All copyright modes (acmcopyright / acmlicensed / rightsretained, the gov family,
  iw3c2w3[g], and Creative Commons with its licence badge); invalid values are rejected

### Known differences from LaTeX

Engine limits, not spacing errors (see [DESIGN.md](DESIGN.md)):

- **Vertical fill (`\flushbottom`)**: Typst can't vertically justify or balance final
  two-column pages, so output is ragged-bottom (spacing is otherwise matched).
- Cross-engine line/page breaking → word drift on dense pages and different breaks.
- `sigchi-a` omits margin-note footnotes; `acmcp` top-aligns its cover infobox.
- The `"typst"` backend has residual ACM-CSL vs `.bst` gaps; math fidelity is
  best-effort.
- PDF accessibility tags are emitted only on Typst 0.14+ (output is otherwise correct
  from 0.12).

## Licensing & trademarks

- The package is licensed **MIT** (see [`LICENSE`](LICENSE)); the `template/` directory —
  copied into your project by `typst init` — is **MIT-0** (no attribution required) so
  your paper carries no obligations. This is the `license = "MIT AND MIT-0"` manifest field.
- The **Creative Commons licence badges** in `src/assets/cc/` are Creative Commons
  **trademarks**, *not* covered by the MIT licence. They are the official, unmodified CC
  press-kit buttons, used to indicate a work's CC licence as Creative Commons' trademark
  policy permits (see [`src/assets/cc/README.md`](src/assets/cc/README.md)).
- **Fonts are not bundled** with the package; Libertinus and Inconsolata are each under
  the SIL Open Font License (install them yourself, as above).
- The **ACM journal logo** is ACM's trademark and is not bundled; supply it via
  `acmcp-logo` for the `acmcp` format.

## Requirements

- Typst **0.12+** (0.14+ to emit PDF accessibility tags).
- The fonts listed under [Fonts](#fonts-required).

## Development

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
