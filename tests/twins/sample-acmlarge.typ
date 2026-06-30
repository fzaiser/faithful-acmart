// sample-acmlarge — port of the upstream acmart sample (acmart/samples,
// docstrip option `all,acmlarge`). Single-column journal format acmlarge (used
// by JOCCH/TAP); identical content to acmsmall but the wider acmlarge text
// block and the POMACS journal. Diffed against out/latex/acmlarge.pdf.
#import "/src/lib.typ": acmart
#import "_sample-common.typ": sample-authors, sample-abstract, sample-ccs, sample-received, sample-body

#show: acmart.with(
  format: "acmlarge",
  title: "The Name of the Title Is Hope",
  journal: "POMACS",
  acm-volume: 37, acm-number: 4, acm-article: 111, acm-year: 2018, acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed", copyright-year: 2018,
  short-authors: "Trovato et al.",
  authors: sample-authors,
  abstract: sample-abstract,
  ccs: sample-ccs,
  received: sample-received,
)

#sample-body(documentclass: "acmlarge")
