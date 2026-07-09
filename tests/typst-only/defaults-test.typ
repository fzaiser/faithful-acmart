// defaults-test — acmart defaults to manuscript and ACM's placeholder DOI.
#import "/src/lib.typ": acmart

#show: acmart.with(
  title: "Default Manuscript Metadata",
  acm-year: 2018,
  acm-month: 8,
  authors: (
    (name: "Ada Lovelace", email: "ada@example.org",
     affiliation: (institution: "Analytical Engine Institute", country: "UK")),
  ),
  abstract: [A short abstract for the default-option smoke test.],
  keywords: ("defaults", "metadata"),
)

= Introduction
This document intentionally omits `format` and `doi` so the LaTeX-compatible
defaults are visible in the rendered output.
