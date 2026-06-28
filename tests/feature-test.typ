// Smoke test for the newly modelled top-matter features: titlenote/subtitlenote,
// teaser, received, badges, and the acks environment. Not a matched twin — just
// exercises every code path so it compiles and renders sensibly.
#import "../src/lib.typ": acmart, acks

#show: acmart.with(
  format: "acmsmall",
  title: "A Title With a Note",
  title-note: [This work was supported by nobody in particular.],
  subtitle: "And a Subtitle With Its Own Note",
  subtitle-note: [The subtitle is also noteworthy.],
  journal: "PACMPL",
  acm-volume: 8, acm-number: 1, acm-article: 1, acm-year: 2026, acm-month: 6,
  doi: "10.1145/3576915.3623999",
  badges: (
    left: rect(width: 36pt, height: 36pt, fill: luma(220))[#align(center + horizon)[AE]],
    right: rect(width: 36pt, height: 36pt, fill: luma(220))[#align(center + horizon)[RA]],
  ),
  received: (
    ("", "20 February 2007"),
    ("revised", "12 March 2009"),
    ("accepted", "5 June 2009"),
  ),
  authors: (
    (name: "Alice Researcher", note: [Contributed equally.], corresponding: true,
     email: "alice@example.edu",
     affiliation: (institution: "Example University", city: "Townsville", country: "USA")),
    (name: "Bob Scientist", note: [Contributed equally.],
     email: "bob@example.edu",
     affiliation: (institution: "Example University", city: "Townsville", country: "USA")),
  ),
  abstract: [A short abstract to anchor the front matter.],
  keywords: ("teaser", "badges", "notes"),
  teaser: figure(
    rect(width: 100%, height: 60pt, fill: luma(235))[#align(center + horizon)[teaser figure]],
    caption: [A wide teaser figure shown between the authors and the abstract.],
  ),
)

= Introduction
Some body text so the document has content. #lorem(40)

#acks[
  We thank the anonymous reviewers and our funding agencies.
]
