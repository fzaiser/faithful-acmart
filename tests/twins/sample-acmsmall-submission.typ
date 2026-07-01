// sample-acmsmall-submission — port of the upstream acmart sample (acmart/
// samples, docstrip option `all,acmsmall,submission`). The acmsmall journal
// format in double-anonymous review mode (screen+anonymous+review): anonymized
// author strip and margin line numbers. Diffed against
// out/latex/acmsmall-submission.pdf.
#import "/src/lib.typ": acmart
#import "_sample-common.typ": sample-authors, sample-abstract, sample-ccs, sample-received, sample-body

#show: acmart.with(
  format: "acmsmall",
  bib-backend: "bibtex",
  screen: true,
  anonymous: true,
  review: true,
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

#sample-body(documentclass: "acmsmall,screen,anonymous,review")
