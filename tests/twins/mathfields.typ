#import "/src/lib.typ": *
#show: acmart.with(
  format: "acmsmall",
  bib-backend: "bibtex",
  // custom commands LaTeX defines via \newcommand: compose with the default
  // renderer to expand them first (\widget -> W, \RR -> ℝ, which NFKC-folds to R).
  tex-render: s => default-tex-render(s.replace("\\widget", "W").replace("\\RR", "ℝ")),
)

#let keys = ("lam", "greek", "custom", "adv", "multi")

= Introduction
Inline math in titles #cite(..keys).

#bibliography("/tests/twins/mathfields.bib")
