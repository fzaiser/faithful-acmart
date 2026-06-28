// title-test — self-contained frontmatter isolator.
// Matched twin: title-test.tex. Exercises the title block alone (3 authors with
// note / ORCID / corresponding / accented names / optional fields), abstract,
// CCS concepts, and keywords. The full 9-author grid lives in the e2e port
// (sample-acmsmall.typ); keep this minimal so frontmatter issues are isolable.
#import "../src/lib.typ": acmart

#show: acmart.with(
  format: "acmsmall",
  title: "The Name of the Title Is Hope",
  journal: "JACM",
  acm-volume: 37, acm-number: 4, acm-article: 111, acm-year: 2018, acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed", copyright-year: 2018,
  short-authors: "Trovato et al.",
  authors: (
    (name: "Ben Trovato",
     note: [The first author conducted this work during a research visit.],
     orcid: "1234-5678-9012", email: "trovato@corporation.com",
     affiliation: (institution: "Institute for Clarity in Documentation",
                   city: "Dublin", state: "Ohio", country: "USA")),
    (name: "Lars Thørväld", corresponding: true, email: "larst@affiliation.org",
     affiliation: (institution: "The Thørväld Group",
                   city: "Hekla", country: "Iceland")),
    (name: "Valerie Béranger",
     affiliation: (institution: "Inria Paris-Rocquencourt",
                   city: "Rocquencourt", country: "France")),
  ),
  abstract: [
    A clear and well-documented document is presented as an article formatted for
    publication by ACM. This short sample exercises only the frontmatter: the
    title block, an author list with affiliations, an author note, an ORCID, a
    corresponding author, the abstract, CCS concepts, and keywords.
  ],
  ccs: (
    (500, "Computing methodologies", "Massively parallel algorithms"),
    (300, "Computing methodologies", "Concurrent algorithms"),
  ),
  keywords: ("datasets", "neural networks", "gaze detection", "text tagging"),
)

This document isolates the article frontmatter so that the title block, author
list, abstract, CCS concepts, and keywords can be compared between the LaTeX and
Typst renderings.
