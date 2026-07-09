// notes-test — frontmatter footnote isolator.
// Matched twin: notes-test.tex. Exercises the shared top-matter footnote-symbol
// counter (title note *, subtitle note †, author notes ‡/§, in acmart's emission
// order) plus the corresponding-author ✉ on the OTHER author, the `received`
// paper-history line (end of document), and the `acks` environment.
#import "/src/lib.typ": acmart, acks

#show: acmart.with(
  thanks: [The authors thank the Example Foundation for supporting this work.],
  format: "acmsmall",
  title: "A Title With a Note",
  title-note: [This funding note is attached to the title.],
  subtitle: "A Subtitle With a Note",
  subtitle-note: [And this one is attached to the subtitle.],
  journal: "JACM",
  acm-volume: 37, acm-number: 4, acm-article: 111, acm-year: 2018, acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed", copyright-year: 2018,
  short-authors: "Researcher and Scientist",
  authors: (
    (name: "Alice Researcher", note: (
       [Alice did the experiments.],
       [Alice wrote the supplemental material.],
     ),
     email: "alice@example.edu",
     affiliation: (institution: "Example University",
                   city: "Townsville", country: "USA")),
    (name: "Bob Scientist", corresponding: true, email: "bob@example.edu",
     affiliation: (institution: "Sample Institute",
                   city: "Metropolis", country: "USA")),
  ),
  abstract: [
    A short abstract anchoring the front matter so the footnote stack, the title
    and subtitle notes, the author notes, and the corresponding-author mark can be
    compared between the LaTeX and Typst renderings.
  ],
  received: (
    ("", "20 February 2007"),
    ("revised", "12 March 2009"),
    ("accepted", "5 June 2009"),
  ),
)

= Introduction
This document isolates the top-matter footnotes so the shared symbol sequence
(title, subtitle, then author notes) can be compared between the LaTeX and Typst
renderings, along with the paper-history line and the acknowledgments section.

#acks[
  We thank the anonymous reviewers for their helpful comments.
]
