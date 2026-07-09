// proceedings-defaults-test — proceedings formats use acmart's conference defaults.
#import "/src/lib.typ": acmart

#show: acmart.with(
  format: "sigconf",
  title: "Default Proceedings Metadata",
  acm-year: 2018,
  acm-month: 8,
  authors: (
    (name: "Ada Lovelace", email: "ada@example.org",
     affiliation: (institution: "Analytical Engine Institute", country: "UK")),
  ),
  abstract: [A short abstract for the proceedings default-option smoke test.],
  keywords: ("defaults", "conference"),
)

= Introduction
This document intentionally omits `conference`, `booktitle`, and `doi` so the
LaTeX-compatible proceedings placeholders are visible in the rendered output.

#pagebreak()

= Continuation
This second page makes the default conference line visible in the running head.
