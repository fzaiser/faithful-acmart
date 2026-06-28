// authorversion-test — the author's-version copyright block.
// Matched twin: authorversion-test.tex. author-version suppresses the permission
// text and replaces the ACM bibstrip in the page-1 copyright footnote with the
// "author's version ... Version of Record was published in <journal>, <doi>"
// notice (acmart.dtx:6612/6634).
#import "../src/lib.typ": acmart

#show: acmart.with(
  format: "acmsmall",
  title: "The Author's Version",
  journal: "JACM",
  acm-volume: 37, acm-number: 4, acm-article: 111, acm-year: 2018, acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed", copyright-year: 2018,
  short-authors: "Trovato",
  author-version: true,
  authors: (
    (name: "Ben Trovato", email: "trovato@corporation.com",
     affiliation: (institution: "Institute for Clarity in Documentation",
                   city: "Dublin", country: "USA")),
  ),
  abstract: [
    A short abstract for a document compiled in author-version mode, exercising the
    alternative page-one copyright block.
  ],
)

= Introduction
This document checks that the author-version copyright block at the bottom of the
first page matches between the LaTeX class and the Typst port.
