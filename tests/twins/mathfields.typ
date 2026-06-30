#import "/src/lib.typ": acmart, acm-cite, acm-bibliography, default-tex-render
#show: acmart.with(
  format: "acmsmall",
  bibliography-backend: "bst",
  // custom commands LaTeX defines via \newcommand: compose with the default
  // renderer to expand them first (\widget -> W, \RR -> ℝ, which NFKC-folds to R).
  tex-render: s => default-tex-render(s.replace("\\widget", "W").replace("\\RR", "ℝ")),
)

#let keys = ("lam", "greek", "custom", "adv")

= Introduction
Inline math in titles #acm-cite(..keys).

#acm-bibliography("/tests/twins/mathfields.bib")
