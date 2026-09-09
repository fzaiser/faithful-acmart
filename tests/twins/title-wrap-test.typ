#import "/src/lib.typ": acmart

#show: acmart.with(
  format: "acmsmall",
  title: "Wrapped Titles Should Keep Their Baselineskip on Every Line: Typographic Notes on Descenders Above Capitals",
  journal: "JACM",
  acm-volume: 37, acm-number: 4, acm-article: 111, acm-year: 2018, acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed", copyright-year: 2018,
  short-authors: "Trovato",
  authors: (
    (name: "Ben Trovato", email: "trovato@corporation.com",
     affiliation: (institution: "Institute for Clarity in Documentation",
                   city: "Dublin", state: "Ohio", country: "USA")),
  ),
  abstract: [
    A title that wraps onto a second line must keep the title font's baselineskip between its lines, or the descenders of one line collide with the capitals of the next.
  ],
)

= Introduction
The body only needs to exist so that the page has a first section below the title block.
