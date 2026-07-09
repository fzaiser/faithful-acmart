// acmcp-test — ACM cover-page format (best-effort, golden-smoke).
// Single-column, unnumbered sections (secnumdepth -1), no ACM reference format.
#import "/src/lib.typ": acmart

#show: acmart.with(
  format: "acmcp",
  print-acm-reference: true,
  // The ACM JDS logo is ACM's trademark and no longer bundled; point at the repo's dev copy.
  acmcp-logo: image("/src/assets/acm-jdslogo.png"),
  title: "An acmcp Cover Sample",
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
    A short document in the manuscript format, used to compare the single-column
    draft geometry and section typography between the LaTeX and Typst renderings.
  ],
  keywords: ("datasets", "neural networks", "gaze detection"),
  code-data-link: link("https://example.com/data")[https://example.com/data],
  contributions: [BT designed the study; VB performed it.],
)

= Introduction
This document exercises the manuscript format's geometry and headings. The body
text is set at the 9pt manuscript default, with the generic sans-bold section
headings shared with acmsmall.

== Background
A subsection to check the level-2 heading font and spacing.

=== A subsubsection
A run-in subsubsection heading in sans italic.

= Method
A second top-level section, so the inter-section spacing is visible.
