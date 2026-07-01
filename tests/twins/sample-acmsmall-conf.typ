// sample-acmsmall-conf — port of the upstream acmart sample (acmart/samples,
// docstrip option `all,proceedings,acmsmall,conf`). The acmsmall journal format
// used for a sponsored event: conference metadata (ISBN/booktitle) replaces the
// journal metadata, so the first page carries the conference copyright block.
// Diffed against out/latex/acmsmall-conf.pdf.
#import "/src/lib.typ": acmart
#import "_sample-common.typ": sample-authors, sample-abstract, sample-ccs, sample-received, sample-body

#show: acmart.with(
  format: "acmsmall",
  bib-backend: "bibtex",
  title: "The Name of the Title Is Hope",
  teaser: figure(
    image("/tests/twins/sampleteaser.jpg", width: 100%,
      alt: "Enjoying the baseball game from the third-base seats. " +
           "Ichiro Suzuki preparing to bat."),
    caption: [Seattle Mariners at Spring Training, 2010.],
  ),
  conference: (
    short: "Conference acronym 'XX",
    name: "Make sure to enter the correct conference title from your rights confirmation email",
    venue: "Woodstock, NY",
    date: "June 03–05, 2018",
  ),
  isbn: "978-1-4503-XXXX-X/2018/06",
  doi: "XXXXXXX.XXXXXXX",
  acm-year: 2018,
  copyright: "acmlicensed", copyright-year: 2018,
  short-authors: "Trovato et al.",
  authors: sample-authors,
  abstract: sample-abstract,
  ccs: sample-ccs,
  received: sample-received,
)

#sample-body(documentclass: "acmsmall")
