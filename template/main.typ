#import "@preview/faithful-acmart:0.1.0": *

#show: acmart.with(
  format: "acmsmall",
  title: "The Name of the Title Is Hope",

  journal: "JACM",
  acm-volume: 37,
  acm-number: 4,
  acm-article: 111,
  acm-year: 2018,
  acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed",
  copyright-year: 2018,

  authors: (
    (
      name: "Ben Trovato",
      note: [Both authors contributed equally to this research.],
      email: "trovato@corporation.com",
      orcid: "1234-5678-9012",
      affiliation: (institution: "Institute for Clarity in Documentation",
                    city: "Dublin", state: "Ohio", country: "USA"),
    ),
    (
      name: "G.K.M. Tobin",
      note: [Both authors contributed equally to this research.],
      corresponding: true,
      email: "webmaster@marysville-ohio.com",
      affiliation: (institution: "Institute for Clarity in Documentation",
                    city: "Dublin", state: "Ohio", country: "USA"),
    ),
    (
      name: "Lars Thørväld",
      email: "larst@affiliation.org",
      affiliation: (institution: "The Thørväld Group",
                    city: "Hekla", country: "Iceland"),
    ),
  ),

  abstract: [
    A clear and well-documented Typst document is presented as an article
    formatted for publication by ACM. Based on the acmart class, this template
    provides ACM fonts, page layouts, and document styles while letting you
    write idiomatic Typst. Line and page breaks can differ between the engines.
  ],

  ccs: (
    (500, "Computing methodologies", "Massively parallel algorithms"),
    (300, "Computing methodologies", "Concurrent algorithms"),
  ),

  keywords: ("typesetting", "ACM", "Typst", "templates"),
)

= Introduction
ACM's consolidated article template provides a consistent style across ACM
publications. This Typst port applies acmart's document styles to ordinary
Typst content. You use headings, paragraphs, figures, and
citations @Cohen:1996:EAE @Li:2008:PUC.

A second paragraph is indented, as in the LaTeX original. The package sets fonts
and spacing according to the selected format.

== Using the template
Call `acmart.with(...)` in a show rule and write the body as usual. Sections,
subsections, and run-in headings all follow the acmsmall styling.

=== A finer point
Run-in headings continue inline with the following text, just like LaTeX.

= Results

#figure(
  rect(width: 5cm, height: 3cm, fill: luma(230)),
  caption: [A placeholder figure. Captions are sans-serif and use a period
    separator, as ACM journals require.],
)

Use `tabular` with `toprule`/`midrule`/`bottomrule` for booktabs-style rule weights
and spacing. Pass `columns` directly so the wrapper can infer the header row.

#figure(
  tabular(
    columns: 3,
    toprule(),
    [Method], [Time (s)], [Accuracy],
    midrule(),
    [Baseline], [12.4], [72.1%],
    [Ours], [8.7], [88.4%],
    bottomrule(),
  ),
  caption: [Tables use booktabs rules, as ACM requires.],
)

Theorem-like environments share a counter numbered within the section:

#theorem[
  Every finite directed acyclic graph has a topological ordering.
]

#proof[
  A nonempty finite acyclic graph has a vertex with no incoming edges. Remove
  that vertex, order the remaining graph by induction, and put the vertex first.
]

#definition[
  A _topological ordering_ puts the source of every directed edge before its
  target.
]

We can also use lists:

- Idiomatic Typst source
- acmart-faithful output

+ Pick a format
+ Write your paper
+ Submit

#bibliography("refs.bib")
