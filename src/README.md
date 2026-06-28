# src/ — the acmart Typst package

Entry point: [`lib.typ`](lib.typ) defines `acmart(...)` (applied via `#show:`)
and re-exports the theorem environments. See the repo [DESIGN.md](../DESIGN.md)
for the architecture and the Typst-vs-LaTeX modeling decisions.

## Layout

| file | role |
|---|---|
| `lib.typ` | public `acmart()` entry: page setup, global text/par rules, header/footer, document options (review/screen/anonymous/nonacm/print-ccs/print-folios + the full acmart option set, recognized-but-unimplemented ones asserted not silently dropped), wires up the parts; re-exports `theorem`/`lemma`/…/`proof` |
| `formats/acmsmall.typ` | **all** acmsmall measurements as a data dict (geometry, font-size steps, skips, fonts). Built on `tp = 72/72.27*1pt` (TeX→PS point conversion) |
| `parts/spacing.typ` | `comp()` / `tex-skip()` — the TeX→Typst baseline-grid conversion used by every `leading` and vertical gap (see DESIGN.md) |
| `parts/headings.typ` | section / subsection / run-in heading show rule |
| `parts/frontmatter.typ` | title, authors+affiliations, abstract, CCS, keywords, ACM reference format, page-1 footnote stack |
| `parts/journals.typ` | the ACM journal table (key → name/short/issn) + `lookup-journal`, transcribed from acmart.dtx |
| `parts/copyright.typ` | permission text + © owner per copyright mode (incl. Creative Commons), transcribed from acmart.dtx |
| `parts/body.typ` | captions, lists, table defaults, code, footnotes, bibliography (ACM CSL) |
| `parts/theorems.typ` | theorem-like environments + shared counter; reads the active format via `state` (`cfg-state`) since users call them in the body |

## Format-as-data

`lib.typ` is format-agnostic; a format is just a dict in `formats/`. Adding a new
format (e.g. `sigconf`) means adding `formats/sigconf.typ` and registering it in
`_formats` in `lib.typ` — plus handling two-column in `lib.typ` for the proceedings
formats. The `parts/` need no changes for single-column formats.

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
