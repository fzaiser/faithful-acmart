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
  keywords: ("Do", "Not", "Use", "This", "Code", "Put", "the", "Correct",
            "Terms", "for", "Your", "Paper"),
  received: sample-received,
)

#sample-body(documentclass: "acmsmall")
