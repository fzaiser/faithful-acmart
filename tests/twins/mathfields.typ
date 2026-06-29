#import "/src/lib.typ": acmart, acm-cite, acm-bibliography
#show: acmart.with(
  format: "acmsmall",
  bibliography-backend: "bst",
  // custom commands LaTeX defines via \newcommand; \RR -> ℝ (NFKC-folds to R)
  tex-macros: (widget: "W", RR: "ℝ"),
)

#let keys = ("lam", "greek", "custom")

= Introduction
Inline math in titles #acm-cite(..keys).

#acm-bibliography("/tests/twins/mathfields.bib")
