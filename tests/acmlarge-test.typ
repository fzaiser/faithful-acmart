// acmlarge-test — large single-column journal format.
// Matched twin: acmlarge-test.tex. Exercises geometry, the journal @i title
// block, and the sans (large, regular) section fonts at the 10pt acmlarge default.
#import "../src/lib.typ": acmart

#show: acmart.with(
  format: "acmlarge",
  title: "An acmlarge-Format Sample",
  journal: "JACM",
  acm-volume: 37, acm-number: 4, acm-article: 111, acm-year: 2018, acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed", copyright-year: 2018,
  authors: (
    (name: "Ben Trovato", email: "trovato@corporation.com",
     affiliation: (institution: "Institute for Clarity in Documentation",
                   city: "Dublin", state: "Ohio", country: "USA")),
    (name: "Valerie Béranger",
     affiliation: (institution: "Inria Paris-Rocquencourt",
                   city: "Rocquencourt", country: "France")),
  ),
  abstract: [
    A short document in the acmlarge format, used to compare the single-column
    draft geometry and section typography between the LaTeX and Typst renderings.
  ],
  keywords: ("datasets", "neural networks", "gaze detection"),
)

= Introduction
This document exercises the acmlarge format's geometry and headings. The body
text is set at the 10pt acmlarge default, with the sans (large, regular-weight) section
headings shared with acmsmall.

== Background
A subsection to check the level-2 heading font and spacing.

=== A subsubsection
A run-in subsubsection heading in sans italic.

= Method
A second top-level section, so the inter-section spacing is visible.
