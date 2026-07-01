// sample-acmsmall-biblatex — port of the upstream acmart sample (acmart/samples,
// docstrip option `all,acmsmall,biblatex`). The acmsmall journal format with the
// BibLaTeX acmauthoryear style (author-year citations), including the
// biblatex-software artifact entries from software.bib.
// Diffed against out/latex/acmsmall-biblatex.pdf.
#import "/src/lib.typ": acmart
#import "_sample-common.typ": sample-authors, sample-abstract, sample-ccs, sample-received, sample-body

#show: acmart.with(
  format: "acmsmall",
  bibliography-backend: "biblatex",
  cite-style: "author-year",
  title: "The Name of the Title Is Hope",
  short-authors: "Trovato et al.",
  journal: "JACM",
  acm-volume: 37, acm-number: 4, acm-article: 111, acm-year: 2018, acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed", copyright-year: 2018,
  authors: sample-authors,
  abstract: sample-abstract,
  ccs: sample-ccs,
  received: sample-received,
)

#sample-body(documentclass: "acmsmall, natbib=false", author-year: true, biblatex: true)
