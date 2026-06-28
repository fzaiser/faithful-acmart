# tests/ — test documents

Two kinds of test:

- **Matched twins** — `NAME.tex` (real LaTeX acmart) and `NAME.typ` (ours) with
  identical content, diffed page-by-page. Each isolates one feature so failures
  are easy to localize.
- **End-to-end ports** — a full Typst document with *no* hand-written twin,
  compared against the upstream sample reference (so it tracks the real ACM
  sample rather than a duplicate of it).

Build everything with `make test`; gate it with `make check`; eyeball a page with
e.g. `make diff STEM=full-test PAGES=1-2`.

| stem | kind | exercises |
|---|---|---|
| `body-test` | twin | body typography: font, size, baseline grid, justification, indent |
| `head-test` | twin | section / subsection / subsubsection / paragraph (run-in) headings |
| `body2-test` | twin | figure & table captions, theorems (plain/definition/proof+QED), lists |
| `fn-test` | twin | body footnotes + code/verbatim |
| `full-test` | twin | multi-page cumulative spacing (reveals the `\flushbottom` difference) |
| `title-test` | twin | frontmatter in isolation: title block, author fields, abstract, CCS, keywords |
| `notes-test` | twin | top-matter footnotes (title/subtitle/author note symbols), corresponding mark, `received`, `acks` |
| `options-test` | twin | document options with a single-column effect: `nonacm`, `print-ccs`, `print-folios`, plus the no-ops `balance`/`natbib` |
| `authorversion-test` | twin | `author-version` page-1 copyright block (suppressed permission text + "author's version … Version of Record" notice) |
| `language-test` | twin | `language` option: French main language + English translated title/abstract/keywords; localized fixed strings (keywords/acks/proof) + hyphenation |
| `language-de-test` | twin | `language=german`: localized keywords/acks/proof + table label "Tabelle"; figure label stays "Fig." |
| `language-es-test` | twin | `language=spanish`: localized keywords/acks/proof + table label "Cuadro"; figure label stays "Fig." |
| `fontsize-{8,9,11,12}-test` | twin | `font-size` option: non-default base sizes scale the amsart `\@typesizes` ladder + baselineskip-derived heading/skip spacing (10pt is the default, covered by every other test) |
| `bib-test` | twin | bibliography (ACM CSL vs `ACM-Reference-Format.bst` — see note) |
| `sample-acmsmall` | e2e | full port of the upstream `acmsmall` sample, vs `out/latex/acmsmall.pdf` |
| `feature-test` | smoke | compile + golden only (no twin): teaser, badges, title/subtitle notes via synthetic assets |
| `draft-test` | smoke | compile-only (no golden/metrics): author-draft = timestamp footer + watermark + copyright overlay + review line numbers; output embeds the compile date so it can't be hash-pinned |

`sample-acmsmall` has no `.tex`; `make reference` builds its upstream reference,
and `make diff STEM=sample-acmsmall` maps to it automatically. It now uses the
real `received` / `acks` features; remaining documented gaps (`appendix`
lettering, wide floats) are listed in the header of `sample-acmsmall.typ`.

`feature-test` is a *smoke-only* doc (kind `smoke`): it has no LaTeX twin because
badges/teaser use synthetic shapes, so it is compiled (warning-free) and
golden-hashed but not geometry-compared (`metrics = false`). It guards the
title-note / subtitle-note / teaser / badges paths that the text-only twins skip.

**bib note:** the ACM CSL and the LaTeX `.bst` are independent implementations of
the same style and diverge in content (access dates, "Doctoral dissertation" vs
"Ph.D.", `doi:` vs `https://doi.org/`, in-text range collapsing). The twin exists
to make that gap measurable; the reference list reflows, so the metrics gate
reports — but doesn't fail on — line count there.

## Regression gates — `make check`

`tests/manifest.toml` is the single source of truth (per-test kind, reference,
expected page count, Tier 2 tolerances). `make check` runs three tiers with no
manual inspection:

- **Tier 0 (smoke)** — every test compiles with no warnings, page counts match,
  twins keep LaTeX/Typst page-count parity.
- **Tier 1 (golden)** — each Typst page raster is hashed and compared to the
  committed `golden/typst.sha256`; any unintended output change fails. After an
  intended change run `make accept` to refresh it (Typst is deterministic, so
  hashes are stable for a pinned engine version + the bundled fonts).
- **Tier 2 (metrics)** — cross-engine layout geometry (left/top margin, baseline
  pitch) gated against manifest tolerances; right margin & line count reported only.

`golden/typst.sha256` is committed; `tests/out/` is not.

## Output (all gitignored, under `tests/out/`)

```
tests/out/latex/   LaTeX builds: acmart.cls, samples, reference PDFs (+ aux)
tests/out/typst/   Typst output PDFs
tests/out/diff/    side-pNN.png / overlay-pNN.png from pdfdiff.py
```

Copyright-mode and option variants are generated on the fly by
`tools/validate-variants.py` (`make validate`), not stored here.
