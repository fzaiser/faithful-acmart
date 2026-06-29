// acmengage-test — two-column proceedings format (twin).
// Matched twin: acmengage-test.tex. Exercises the two-column layout: the spanning
// centered conference title, the centered author grid, the first-column copyright
// block (conference info + permission + ISBN), and the serif-bold Large sections.
#import "../src/lib.typ": acmart

#show: acmart.with(
  format: "acmengage",
  title: "A Two-Column Conference Sample",
  conference: (short: "Conference'17", venue: "Washington, DC, USA"),
  booktitle: "Proceedings of ACM Conference (Conference'17)",
  isbn: "978-1-4503-XXXX-X/2018/06",
  doi: "XXXXXXX.XXXXXXX",
  acm-year: 2018, acm-month: 6,
  copyright: "acmlicensed", copyright-year: 2018,
  authors: (
    (name: "Ben Trovato", email: "trovato@corporation.com",
     affiliation: (institution: "Institute for Clarity in Documentation",
                   city: "Dublin", state: "Ohio", country: "USA")),
    (name: "Lars Thørväld", email: "larst@affiliation.org",
     affiliation: (institution: "The Thørväld Group",
                   city: "Hekla", country: "Iceland")),
    (name: "Valerie Béranger", email: "valerie@inria.fr",
     affiliation: (institution: "Inria Paris-Rocquencourt",
                   city: "Rocquencourt", country: "France")),
  ),
  abstract: [
    A short proceedings document used to compare the two-column conference layout
    between the LaTeX and Typst renderings: the full-width title and author grid,
    the first-column permission block, and the section typography.
  ],
  ccs: (
    (500, "Computing methodologies", "Massively parallel algorithms"),
    (300, "Computing methodologies", "Concurrent algorithms"),
  ),
  keywords: ("datasets", "neural networks", "gaze detection", "text tagging"),
)

= Introduction
This document exercises the sigconf format's two-column body, the spanning title
block, and the serif-bold Large section headings. #lorem(80)

== Background
A subsection to check the level-2 heading. #lorem(60)

=== A subsubsection
A run-in subsubsection heading. #lorem(40)

= Method
A second top-level section. #lorem(120)
