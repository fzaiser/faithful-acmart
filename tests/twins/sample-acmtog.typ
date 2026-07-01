// sample-acmtog — port of the upstream acmart sample (acmart/samples, docstrip
// option `all,acmtog`). Two-column journal format acmtog (TOG), which uses the
// author-year citation style (\citestyle{acmauthoryear}). Routed through the bst
// backend (bib-backend "bibtex", cite-style "author-year"); the body's
// citations switch to cite() via `author-year: true`. Diffed against
// out/latex/acmtog.pdf.
#import "/src/lib.typ": acmart
#import "_sample-common.typ": sample-authors, sample-abstract, sample-ccs, sample-received, sample-body

#show: acmart.with(
  format: "acmtog",
  bib-backend: "bibtex",
  cite-style: "author-year",
  title: "The Name of the Title Is Hope",
  journal: "TOG",
  acm-volume: 37, acm-number: 4, acm-article: 111, acm-year: 2018, acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed", copyright-year: 2018,
  short-authors: "Trovato et al.",
  authors: sample-authors,
  abstract: sample-abstract,
  ccs: sample-ccs,
  received: sample-received,
)

#sample-body(documentclass: "acmtog", author-year: true)
