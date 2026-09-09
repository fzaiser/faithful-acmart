#import "/src/lib.typ": acmart

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
     affiliation: (department: "Theory Division", institution: "The Thørväld Group",
                   city: "Hekla", country: "Iceland")),
    (name: "Valerie Béranger",
     affiliation: (
       (institution: "Inria Paris-Rocquencourt", city: "Rocquencourt", country: "France"),
       (institution: "Université de Paris", city: "Paris", country: "France"),
       (institution: "CNRS", city: "Paris", country: "France"),
     )),
  ),
  abstract: [
    A clear and well-documented document is presented as an article formatted for
    publication by ACM. This short sample exercises only the frontmatter: the
    title block, an author list with affiliations, an author note, an ORCID, a
    corresponding author, the abstract, CCS concepts, and keywords.
  ],
  // Keep these long enough to exercise justified wrapping.
  ccs: (
    (500, "Computing methodologies", "Massively parallel algorithms"),
    (300, "Computing methodologies", "Concurrent algorithms"),
    (300, "Human-centered computing", "Human computer interaction (HCI)"),
    (100, "Information systems", "Information retrieval query processing"),
  ),
  keywords: (
    "datasets", "neural networks", "gaze detection", "text tagging",
    "computational linguistics", "human-computer interaction",
    "information retrieval", "probabilistic graphical models",
    "distributed systems", "reproducible research",
  ),
)

This document isolates the article frontmatter so that the title block, author
list, abstract, CCS concepts, and keywords can be compared between the LaTeX and
Typst renderings.
