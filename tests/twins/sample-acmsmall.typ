// sample-acmsmall — full end-to-end port of the upstream acmart sample
// (acmart/samples/samples.dtx, option `acmsmall`). Unlike the matched twins,
// this has NO hand-written .tex: it is diffed page-by-page against the upstream
// reference PDF that `tools/test.py reference` builds (tests/out/latex/acmsmall.pdf), so
// it tracks the *real* ACM sample rather than a duplicate.
//
// Known gaps vs the LaTeX sample (the lib doesn't model these yet; see CLAUDE.md
// "Not done yet" — they will drift the diff and are expected, not spacing bugs):
//   - \received dates: now modelled via the `received:` argument (end of doc).
//   - \acks: now the real `acks` environment; the Ethics statement is a plain
//     unnumbered heading (\section*), which is byte-identical to acmart's.
//   - \appendix lettering is emulated with `set heading(numbering: "A.1")`.
//   - Wide floats (table*) collapse to normal floats (acmsmall is single-column,
//     so this matches in practice).

#import "/src/lib.typ": acmart
#import "_sample-common.typ": sample-authors, sample-abstract, sample-ccs, sample-received, sample-body

#show: acmart.with(
  format: "acmsmall",
  bib-backend: "bibtex",
  title: "The Name of the Title Is Hope",
  journal: "JACM",
  acm-volume: 37, acm-number: 4, acm-article: 111, acm-year: 2018, acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed", copyright-year: 2018,
  short-authors: "Trovato et al.",
  authors: sample-authors,
  abstract: sample-abstract,
  ccs: sample-ccs,
  received: sample-received,
)

#sample-body(documentclass: "acmsmall")
