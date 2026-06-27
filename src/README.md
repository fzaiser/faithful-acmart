# src/ — the acmart Typst package

Entry point: [`lib.typ`](lib.typ) defines `acmart(...)` (applied via `#show:`)
and re-exports the theorem environments. See the repo [DESIGN.md](../DESIGN.md)
for the architecture and the Typst-vs-LaTeX modeling decisions.

## Layout

| file | role |
|---|---|
| `lib.typ` | public `acmart()` entry: page setup, global text/par rules, header/footer, options (review/screen/anonymous), wires up the parts; re-exports `theorem`/`lemma`/…/`proof` |
| `formats/acmsmall.typ` | **all** acmsmall measurements as a data dict (geometry, font-size steps, skips, fonts). Built on `tp = 72/72.27*1pt` (TeX→PS point conversion) |
| `parts/headings.typ` | section / subsection / run-in heading show rule |
| `parts/frontmatter.typ` | title, authors+affiliations, abstract, CCS, keywords, ACM reference format, page-1 footnote stack, journal table |
| `parts/copyright.typ` | permission text + © owner per copyright mode (incl. Creative Commons), transcribed from acmart.dtx |
| `parts/body.typ` | captions, lists, table defaults, code, footnotes, bibliography (ACM CSL) |
| `parts/theorems.typ` | theorem-like environments + shared counter; reads the active format via `state` (`cfg-state`) since users call them in the body |

## Format-as-data

`lib.typ` is format-agnostic; a format is just a dict in `formats/`. Adding a new
format (e.g. `sigconf`) means adding `formats/sigconf.typ` and registering it in
`_formats` in `lib.typ` — plus handling two-column in `lib.typ` for the proceedings
formats. The `parts/` need no changes for single-column formats.

## Gotchas (see DESIGN.md / the `typst-acmart-modeling` memory)

- Build with `../tools/tc` (full Libertinus + Inconsolata fonts), not plain `typst`.
- Leading model: `top-edge: 1em`, `leading = baselineskip - font-size`.
- Section titles are **mixed case** (not uppercased); author names are uppercased.
- `\flushbottom` (full-page vertical justification) is not replicable in Typst.
