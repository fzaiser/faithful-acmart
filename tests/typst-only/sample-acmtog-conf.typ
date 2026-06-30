// sample-acmtog-conf — port of the upstream acmart sample (acmart/samples,
// docstrip option `all,proceedings,acmtog,conf`). The two-column acmtog format
// used for a sponsored event: conference metadata replaces the journal metadata,
// and the author-year citation style (\citestyle{acmauthoryear}) is in force.
// Diffed against out/latex/acmtog-conf.pdf.
#import "/src/lib.typ": acmart
#import "_sample-common.typ": sample-authors, sample-abstract, sample-ccs, sample-received, sample-body

#show: acmart.with(
  format: "acmtog",
  bibliography-backend: "bst",
  cite-style: "author-year",
  title: "The Name of the Title Is Hope",
  teaser: figure(
    image("/acmart/samples/sampleteaser.jpg", width: 100%,
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
  acm-year: 2018, acm-month: 6,
  copyright: "acmlicensed", copyright-year: 2018,
  short-authors: "Trovato et al.",
  authors: sample-authors,
  abstract: sample-abstract,
  ccs: sample-ccs,
  received: sample-received,
)

#sample-body(documentclass: "acmtog", author-year: true)
