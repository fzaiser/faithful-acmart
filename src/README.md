# src/ — the acmart Typst package

Entry point: [`lib.typ`](lib.typ) defines `acmart(...)` (applied via `#show:`)
and re-exports the theorem environments. See the repo [DESIGN.md](../DESIGN.md)
for the architecture and the Typst-vs-LaTeX modeling decisions.

## Layout

| file | role |
|---|---|
| `lib.typ` | public `acmart()` signature and orchestration: applies resolved page/global rules, wires up title/body rendering and citation state, and re-exports `theorem`/`lemma`/…/`proof` plus the booktabs helpers |
| `formats/_base.typ` | shared font-size ladder (amsart `\@typesizes`) + `make-format()`, the dict constructor that fills format-independent constants. `tp = 72/72.27*1pt` (TeX→PS point conversion) lives here |
| `formats/<name>.typ` | active format builders (acmsmall, manuscript, acmlarge, acmtog, sigconf, sigplan, acmengage, sigchi-a, acmcp): probed geometry + the format flags, all shared values from `make-format` |
| `parts/spacing.typ` | `comp()` / `tex-skip()` — the TeX→Typst baseline-grid conversion used by every `leading` and vertical gap (see DESIGN.md) |
| `parts/headings.typ` | section / subsection / run-in heading show rule |
| `parts/frontmatter.typ` | title, authors+affiliations, abstract, CCS, keywords, ACM reference format, page-1 footnote stack |
| `parts/options.typ` | format selection, option validation, and effective review/timestamp/folio/language state |
| `parts/metadata.typ` | normalized authors, translations, conference/booktitle, journal/DOI, and PDF metadata fields |
| `parts/page-chrome.typ` | running heads and footers, acmcp label, review ruler, and draft/legacy watermarks |
| `parts/journals.typ` | the ACM journal table (key → name/short/issn) + `lookup-journal`, transcribed from acmart.dtx |
| `parts/strings.typ` | localization for the `language` option: per-language fixed strings (keywords/acks/proof/table/abstract/references) + babel-name→Typst-lang map, transcribed from acmart.dtx |
| `parts/copyright.typ` | permission text + © owner per copyright mode (incl. Creative Commons), transcribed from acmart.dtx |
| `parts/body.typ` | captions, lists, table defaults, code, footnotes, bibliography integration |
| `parts/tables.typ` | booktabs `tabular` wrapper (drop-in for `table`, adds `\aboverulesep`/`\belowrulesep` rule separation) + `toprule`/`midrule`/`bottomrule` helpers; the cell-strut inset is shared with `body.typ`'s `set table` |
| `parts/theorems.typ` | theorem-like environments + shared counter; reads the active format via `state` (`cfg-state`) since users call them in the body |
| `parts/bibtex.typ` | pure-Typst BibTeX reader (`.bib` → field dicts) for the ACM bibliography backends |
| `parts/acmref.typ` | public facade for the pure-Typst ACM bibliography backends; re-exports the cite/bibliography functions and state used by `lib.typ` |
| `parts/acmref-common.typ` | shared bibliography rendering primitives: TeX render state, rendered-value helpers, field/name helpers, date/year helpers |
| `parts/acmref-bst.typ` | pure-Typst port of `ACM-Reference-Format.bst`: output state machine, per-entry handlers, crossref text, trailing DOI/URL/arXiv rendering, BST sort key |
| `parts/acmref-biblatex.typ` | ACM BibLaTeX `acmnumeric`/`acmauthoryear` plus `biblatex-software` visible reference formatting and software data-model inheritance |
| `parts/acmref-cite.typ` | cite registration, BibTeX crossref resolution, BibLaTeX data-model preparation, numeric and author-year labels, and bibliography output |
| `parts/bib-data.typ` | the `.bst`'s built-in journal MACRO table + `journal.canon.abbrev` map, used by the `bibtex` backend and checked exactly against the bundled `ACM-Reference-Format.bst` by `test.py source-data` |
| `assets/` | bundled image assets, addressed root-absolute (`/src/assets/…`): `cc/` (Creative Commons licence badges). The acmcp cover logo is supplied by the user via `acmcp-logo:` (ACM's trademark, not bundled); `acm-jdslogo.png` remains for the acmcp twin only |

## Format-as-data

`lib.typ` is format-agnostic; a format is just a dict in `formats/`, built by
`make-format()` in `formats/_base.typ` (which fills the format-independent
constants). All public acmart formats are accepted; `siggraph` and `sigchi` map
to the `sigconf` builder, because the bundled LaTeX class treats them as obsolete
aliases. Each active `formats/<name>.typ` passes its probed geometry + the
`\ifcase` flags (`columns`, `title-style`, `sec-fonts`, `bibstrip`,
`secnumdepth`, the title/author/affiliation fonts). To add or audit one, run
`tools/test.py probe --format <name>` and register the builder in `formats` in
`parts/options.typ`. Two-column is handled once in `lib.typ` (page columns + the
spanning-title float); frontmatter/title rendering dispatches on
`cfg.title-style`, and `headings.typ` reads `cfg.sec-fonts`.

## Idioms / simplifications to keep the code clean

Recurring cleanups worth applying as you touch this code (all verified against the
golden gate, which must stay byte-identical):

- **Resolve defaults in the signature, not the body.** Typst evaluates a default
  expression lazily per call, so `acm-year: datetime.today().year()` belongs in
  the parameter list — not `acm-year: none` + `if … != none` in the body. The
  only exceptions are defaults that reference *another* parameter (e.g.
  `copyright-year` → `acm-year`), which must stay `none`/`auto` and resolve in the
  body. A closure can default a param to a captured outer value too (theorems'
  `title: default-name`).
- **`none` renders as empty content.** `[#none]` produces nothing, so a `!= none`
  guard around a *bare* value is pointless. Guards are only justified when they
  suppress *surrounding literal text* (the `": "` before a subtitle, the
  `" (note)"` parens) — and those mirror acmart's own `\ifx…\@empty` tests, so
  keep them.
- **Don't `str()` a number that's rendered into content** — ints interpolate
  directly (`[#vol]`). Keep `str()` only for (a) string concatenation with `+`,
  or (b) delimiting a number before a following letter/`-` in markup (e.g.
  `#str(month)-ART`, else `month-ART` parses as one identifier).
- **Assemble with content `[…]`, not string `+`/`str()`,** when the result is only
  ever rendered (see `pub-date`).
- **Centralize optional-field access.** Normalize input dicts once
  (`normalize-author`, `join-fields`/`affil-strings`) so the rest of the code uses
  plain `a.email` and a single absence rule (`none`), not scattered
  `.at(k, default: …)` and mixed `none`/`""` sentinels.
- **Factor repeated styled blocks / joins** into helpers (`fm-block`, `andify`),
  and **keep large static data in its own file** (`journals.typ`, `copyright.typ`).

## Gotchas (see DESIGN.md / the `typst-acmart-modeling` memory)

- Build with `../tools/tc` (full Libertinus + Inconsolata fonts), not plain `typst`.
- Leading model: `top-edge: 1em`, `leading = baselineskip - font-size`.
- Section titles are **mixed case** (not uppercased); author names are uppercased.
- `\flushbottom` (full-page vertical justification) is not replicable in Typst.
