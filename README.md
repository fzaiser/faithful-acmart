# faithful-acmart

A [Typst](https://typst.app) port of LaTeX's `acmart` document class, with ACM page layouts, front matter, bibliography styles, and theorem environments.
The test suite compares rendered documents against the [bundled LaTeX sources](acmart/).
See [compatibility limits](DESIGN.md#compatibility-limits) for differences between the engines.

## Getting started

Install the [required fonts](#fonts), then create a paper:

```sh
typst init @preview/faithful-acmart:0.1.0
```

For an existing document, import the package and apply `acmart`:

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
  authors: (
    (
      name: "Ada Lovelace",
      email: "ada@example.org",
      affiliation: (
        institution: "Analytical Engine Institute",
        city: "London",
        country: "UK",
      ),
    ),
  ),
  abstract: [Your abstract.],
  keywords: ("one", "two"),
)

= Introduction
Write ordinary Typst and cite prior work @Cohen:1996:EAE.

#bibliography("refs.bib")
```

Use the wildcard import (`*`) to include the package's `cite` and `bibliography` functions.
The [starter document](template/main.typ) includes figures, tables, and theorems.
The minimum Typst version is recorded in [typst.toml](typst.toml).

## Fonts

Provide **Libertinus Serif**, **Libertinus Sans**, **Libertinus Math**, and **Inconsolatazi4**.
They are available in the repository's [fonts directory](fonts/), with provenance and licensing information.
Fonts are excluded from the published package.

Install them system-wide or pass their directory when compiling:

```sh
typst compile --font-path <font-folder> main.typ
```

In the Typst web app, upload the font files into your project.

## Choosing a format

| `format` | Layout |
|---|---|
| `manuscript` | Manuscript; the default |
| `acmsmall`, `acmlarge` | Single-column journals |
| `acmtog` | Two-column TOG journal |
| `sigconf` | Conference proceedings |
| `siggraph`, `sigchi` | Aliases of `sigconf`, as in acmart |
| `sigplan` | SIGPLAN proceedings |
| `acmengage` | EngageCSEdu |
| `sigchi-a` | Legacy landscape extended abstract |
| `acmcp` | Cover-page format; requires `acmcp-logo: image("logo.png")` |

For proceedings, supply `conference: (name: "…", short: "…", venue: "…", date: "…")`, along with `booktitle` and `isbn`.
Omitting `conference` retains acmart's placeholder metadata; `conference: none` suppresses it.
Set `acm-year` and `acm-month` explicitly to keep publication dates independent of the compile date.

## Paper metadata

The `acmart` signature in [src/lib.typ](src/lib.typ) lists all options and defaults.
Common submission options are `anonymous`, `review`, `screen`, and `submission-id`; `short-title` and `short-authors` override running heads.

An author can have an `orcid`, a `note` or array of notes, and an array of `affiliation` dictionaries.
Each affiliation requires a `country`.
Identical notes share a footnote mark; at most one author may set `corresponding: true`.
The contact block preserves the declaration order of email, affiliations, and affiliation fields.
To group authors under a shared affiliation in a journal title block, put the affiliation on the last author in that group.

For CCS concepts, paste the [ACM CCS tool](https://dl.acm.org/ccs)'s output into a raw block:

````typ
ccs: ```
\ccsdesc[500]{Software and its engineering~Virtual machines}
```
````

The package accepts the tool's complete output, including CCSXML, or an array of `(significance, area, concept)` tuples.
When both XML and `\ccsdesc` are present, it uses `\ccsdesc`.

Set `copyright` and `copyright-year` from the publication's rights instructions.
For Creative Commons, use `copyright: "cc"` with `cc-type` and `cc-version`.

## Citations

| `bib-backend` | Reference style |
|---|---|
| `"bibtex"` | Default; ACM's `ACM-Reference-Format.bst` |
| `"biblatex"` | ACM BibLaTeX styles, including software artifacts |
| `"typst"` | Typst's built-in ACM CSL style |

The first two backends run entirely in Typst; set `cite-style: "author-year"` for author-year citations.
They accept a single relative bibliography path or an array of project-absolute paths, such as `bibliography(("/refs.bib", "/more.bib"))`.

```typst
Prior work includes @Cohen:1996:EAE[p. 42].
#cite(<Li:2008:PUC>, <Hollis:1999:VBD>) groups several citations.
#cite-text(<Cohen:1996:EAE>) cites the author in prose.

#bibliography("refs.bib")
```

`cite` accepts `form: "prose"`, `"author"`, `"year"`, `"full"`, or `none` as well as the default `"normal"`.
Use `form: none` to include an uncited entry in the reference list.
A page locator goes in `supplement`; the `"full"` and `none` forms do not take one.
The `bibtex` backend follows natbib in dropping supplements from numeric author-only and year-only citations.

For bibliography fields containing custom TeX commands, supply a `tex-render` callback, for example `tex-render: s => default-tex-render(s.replace("\\myunit", "kg"))`.
This changes field rendering; sorting and citation labels still use the built-in parser.

## Theorems and acknowledgments

Theorem environments share a counter within each section and support labels:

```typst
#theorem(name: "Topological ordering")[
  Every finite acyclic graph has a topological ordering.
] <topo>

#proof[
  Remove a source vertex and continue by induction.
]

Apply @topo to order the dependencies.
```

Also available: `lemma`, `corollary`, `proposition`, `conjecture`, `definition`, `example`, and `remark`.
Use `#acks[...]` for acknowledgments; anonymous mode suppresses the section.

## Tables

Use `tabular` with the booktabs rule helpers for ACM rule weights and spacing:

```typst
#figure(
  tabular(
    columns: 2,
    toprule(),
    [Method], [Accuracy],
    midrule(),
    [Baseline], [72.1%],
    [Ours], [88.4%],
    bottomrule(),
  ),
  caption: [Results.],
)
```

`tabular` accepts Typst table arguments and treats the first row as a header when it can infer the row safely.
Use `header-rows: 0` for a table without a header, or supply `table.header` explicitly for a more complex table.
Pass `columns` directly to `tabular` so it can determine row boundaries.

## Development and license

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup and validation, and [DESIGN.md](DESIGN.md) for architecture and compatibility limits.
The project was developed with AI coding assistance and human review.

The package is [MIT licensed](LICENSE); the [starter template is MIT-0](template/LICENSE).
The [Creative Commons badges](src/assets/cc/README.md) are trademarks covered by their own usage policy.
The ACM journal logo must be supplied by the user.
