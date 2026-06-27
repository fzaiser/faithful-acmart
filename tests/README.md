# tests/ — matched test documents

Each test is a **matched pair**: `NAME.tex` (real LaTeX acmart) and `NAME.typ`
(our template) with identical content, so they can be diffed page-by-page. Build
everything with `make test`, then e.g. `make diff STEM=full-test PAGES=1-2`.

| stem | exercises |
|---|---|
| `body-test` | body typography: font, size, baseline grid, justification, indent |
| `head-test` | section / subsection / subsubsection / paragraph (run-in) headings |
| `body2-test` | figure & table captions, theorems (plain/definition/proof+QED), lists |
| `fn-test` | body footnotes + code/verbatim |
| `full-test` | multi-page cumulative spacing (reveals the `\flushbottom` difference) |
| `title-test` | full frontmatter (Typst only; compared against `out/latex/acmsmall.pdf`) |
| `bib-test` | bibliography via ACM CSL (Typst only) |

`title-test`/`bib-test` have no `.tex` twin — they mirror the upstream
`sample-acmsmall`, so diff them against `tests/out/latex/acmsmall.pdf`
(`make reference`).

## Output (all gitignored, under `tests/out/`)

```
tests/out/latex/   LaTeX builds: acmart.cls, samples, reference PDFs (+ aux)
tests/out/typst/   Typst output PDFs
tests/out/diff/    side-pNN.png / overlay-pNN.png from pdfdiff.py
```

Copyright-mode and option variants are generated on the fly by
`tools/validate-variants.py` (`make validate`), not stored here.
