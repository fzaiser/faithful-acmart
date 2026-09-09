// Shared document for the corrections that apply outside the bibliography.
// The variants differ only in how they pass `fix-quirks`.
#import "/src/lib.typ": *

#let doc-opts = (
  format: "acmsmall",
  title: "Corrections Outside the Bibliography",
  // A mixed-case scheme and host exercise the case-insensitive resolver match.
  doi: "https://DOI.org/10.1145/1234567.1234568",
  acm-year: 2021,
  acm-month: 5,
  bib-backend: "typst",
  authors: (
    (name: "Ada Ames", email: "ada@example.org",
     affiliation: (institution: "Institute of Corrections", country: "UK")),
  ),
  authors-addresses: [Authors' Contact Information: Ada Ames, Institute of Corrections, London, UK.],
  thanks: [This work was funded by a council in the UK.],
  abstract: [A short abstract for the correction smoke test.],
  keywords: ("corrections", "punctuation"),
)

#let doc-body = [
  = Introduction
  A paragraph so the front matter has a body to precede.

  === Measured in the U.S.
  A run-in heading whose title already ends in an abbreviation.

  ==== Deployed across the EU.
  A deeper run-in heading with the same property.

  === Ordinary subsubsection
  A control heading that still receives its period.

  #proof(name: [Proof of Thm. A.])[The proof body.]
]
