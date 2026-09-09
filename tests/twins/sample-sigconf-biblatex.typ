#import "/src/lib.typ": acmart
#import "_sample-common.typ": sample-authors, sample-abstract, sample-ccs, sample-received, sample-body

#show: acmart.with(
  format: "sigconf",
  bib-backend: "biblatex",
  title: "The Name of the Title Is Hope",
  short-authors: "Trovato et al.",
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
  teaser: figure(
    image("/tests/twins/sampleteaser.jpg", width: 100%,
      alt: "Enjoying the baseball game from the third-base seats. " +
           "Ichiro Suzuki preparing to bat."),
    caption: [Seattle Mariners at Spring Training, 2010.],
  ),
  authors: sample-authors,
  abstract: sample-abstract,
  ccs: sample-ccs,
  keywords: ("Do", "Not", "Use", "This", "Code", "Put", "the", "Correct",
            "Terms", "for", "Your", "Paper"),
  received: sample-received,
)

#sample-body(documentclass: "sigconf, natbib=false", biblatex: true)
