# faithful-acmart

`faithful-acmart` is a [Typst](https://typst.app) package for writing ACM-style
papers. It ports the public LaTeX `acmart` formats while keeping the document source
idiomatic Typst.

Use it when you want ACM-looking output from Typst: matching fonts, page geometry,
top matter, captions, theorem environments, copyright blocks, and ACM bibliography
styles as closely as Typst allows.

## Getting started

Create a new paper from the template:

```sh
typst init @preview/faithful-acmart:0.1.0
```

Or import the package in an existing document:

```typst
#import "@preview/faithful-acmart:0.1.0": *

#show: acmart.with(
  format: "acmsmall",
  title: "Your Title",
  journal: "JACM",
  acm-volume: 37,
  acm-number: 4,
  acm-article: 111,
  acm-year: 2018,
  acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed",
  copyright-year: 2018,
  authors: (
    (
      name: "Ada Lovelace",
      email: "ada@example.org",
      corresponding: true,
      affiliation: (
        institution: "Analytical Engine Co.",
        city: "London",
        country: "UK",
      ),
    ),
  ),
  abstract: [Your abstract.],
  ccs: ((500, "Computing methodologies", "Massively parallel algorithms"),),
  keywords: ("one", "two"),
)

= Introduction
Write normal Typst. Cite with @key and finish with a bibliography.

#bibliography("refs.bib")
```

Use the wildcard import (`*`). It brings `acmart`, the theorem environments,
`cite`, `bibliography`, and the textual citation helpers (`cite-text`, `cite-year`,
`cite-author`) into scope. A complete starter document is in
[`template/main.typ`](template/main.typ).

## Fonts

ACM documents use **Libertinus** for text/math and **Inconsolatazi4** for monospace.
Typst packages cannot bundle fonts, so install or provide these families before
compiling:

- `Libertinus Serif`
- `Libertinus Sans`
- `Libertinus Math`
- `Inconsolatazi4`

On the command line, install the fonts system-wide or pass a font directory:

```sh
typst compile --font-path <font-folder> main.typ
```

In the Typst web app, upload the font files into the project. Libertinus is available
from the [Libertinus releases](https://github.com/alerque/libertinus/releases);
`Inconsolatazi4` ships with TeX Live's `inconsolata` package. The project repository
also mirrors both families in [`fonts/`](fonts/).

## Formats

Set the output style with `format`:

| Format | Use |
|---|---|
| `manuscript` | ACM manuscript layout |
| `acmsmall`, `acmlarge` | Single-column ACM journal layouts |
| `acmtog` | Two-column ACM TOG layout |
| `sigconf` | Standard ACM conference proceedings |
| `siggraph`, `sigchi` | Aliases of `sigconf`, matching `acmart` |
| `sigplan` | SIGPLAN proceedings |
| `sigchi-a` | Legacy landscape SIGCHI extended abstract |
| `acmengage` | ACM EngageCSEdu proceedings |
| `acmcp` | ACM Computing Proceedings cover format |

## Common options

Most papers only need a subset of these:

| Option | Purpose |
|---|---|
| `title`, `subtitle` | Paper title and subtitle |
| `title-note`, `subtitle-note` | Footnotes attached to the title/subtitle |
| `authors` | Array of author dictionaries |
| `abstract`, `ccs`, `keywords` | Standard ACM front matter |
| `journal`, `acm-volume`, `acm-number`, `acm-article`, `acm-year`, `acm-month`, `doi` | Journal metadata |
| `conference`, `booktitle`, `isbn` | Proceedings metadata |
| `copyright`, `copyright-year`, `cc-type`, `cc-version` | Copyright and Creative Commons metadata |
| `anonymous`, `review`, `screen`, `nonacm`, `author-draft`, `submission-id` | Common `acmart` modes |
| `print-ccs`, `print-acm-reference`, `print-folios` | Top-matter/output toggles |
| `teaser`, `badges`, `received` | Teaser figure, artifact badges, and paper history |
| `language`, `translations` | Main language and translated top matter |
| `short-title`, `short-authors` | Running-head overrides |
| `font-size` | One of `8pt`, `9pt`, `10pt`, `11pt`, `12pt`, or `auto` |

Author dictionaries accept `name`, `email`, `orcid`, `note`, `corresponding`, and
`affiliation`. An affiliation is a dictionary with fields such as `institution`,
`city`, `state`, and `country`; pass an array of affiliation dictionaries for multiple
affiliations.

CCS entries are `(significance, area, concept)`: significance `500` or higher prints
bold, `300` or higher prints italic, and lower values print roman.

Supported `copyright` values include `acmcopyright`, `acmlicensed`,
`rightsretained`, `usgov`, `usgovmixed`, `cagov`, `cagovmixed`,
`licensedusgovmixed`, `licensedcagov`, `licensedcagovmixed`, `othergov`,
`licensedothergov`, `iw3c2w3`, `iw3c2w3g`, `cc`, and `none`. For `copyright: "cc"`,
set `cc-type` to `zero`, `by`, `by-sa`, `by-nd`, `by-nc`, `by-nc-sa`, or
`by-nc-nd`.

For `acmcp`, provide `acmcp-logo: image("logo.png")`. The ACM journal logo is a
trademark and is not bundled.

## Citations and references

The default bibliography backend is `"bibtex"`, a pure-Typst implementation of
ACM's `ACM-Reference-Format.bst`. Use normal Typst citation syntax:

```typst
Prior work includes @Cohen:1996:EAE and #cite(<Li:2008:PUC>, <Smith:2020>).
#cite-text(<Cohen:1996:EAE>) gives a textual citation.

#bibliography("refs.bib")
```

Choose a backend with `bib-backend`:

| Backend | Behavior |
|---|---|
| `"bibtex"` | Default; closest to LaTeX `acmart` with BibTeX |
| `"biblatex"` | ACM BibLaTeX renderer, including software artifacts |
| `"typst"` | Typst's native `bibliography()` with the built-in ACM CSL style |

Set `cite-style: "author-year"` for author-year citations; otherwise citations are
numeric. With the `bibtex` and `biblatex` backends, a single bibliography file may be
relative (`"refs.bib"`); multiple files must use project-absolute paths such as
`"/refs.bib"`.

## Theorems and acknowledgments

The package exports `theorem`, `lemma`, `corollary`, `proposition`, `conjecture`,
`definition`, `example`, `remark`, and `proof`. Theorem-like environments share a
section-scoped counter:

```typst
#theorem(name: "Optional name")[
  Every finite acyclic graph has a topological ordering.
]

#proof[
  Remove a source vertex and continue by induction.
]
```

Use `#acks[...]` or `#acknowledgments[...]` for the unnumbered acknowledgments
section. It is suppressed automatically in anonymous mode.

## Known differences from LaTeX

Some differences come from Typst and LaTeX being different layout engines:

- Typst cannot reproduce LaTeX's `\flushbottom` vertical fill or final two-column
  balancing, so pages are ragged-bottom.
- Line and page breaks can differ from LaTeX on dense pages.
- `sigchi-a` does not move footnotes into the margin.
- `acmcp` approximates the vertical position of the cover infobox.
- The `"typst"` bibliography backend is convenient, but less faithful than the
  default `"bibtex"` backend.
- PDF accessibility tags are emitted only with Typst 0.14+; visual output works from
  Typst 0.12.

For the detailed design rationale and validation notes, see [`DESIGN.md`](DESIGN.md).

## Requirements

- Typst 0.12 or newer.
- The fonts listed in [Fonts](#fonts).

## License and trademarks

The package is licensed MIT; the `template/` directory is MIT-0 so papers created
from `typst init` carry no attribution requirement. See [`LICENSE`](LICENSE).

Creative Commons badges in `src/assets/cc/` are Creative Commons trademarks, not
part of the MIT license; see [`src/assets/cc/README.md`](src/assets/cc/README.md).
The ACM journal logo is not bundled; provide it yourself for `acmcp`.

## Contributing

Development setup, validation, and repository internals are documented in
[`CONTRIBUTING.md`](CONTRIBUTING.md).
