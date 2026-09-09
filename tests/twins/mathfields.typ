#import "/src/lib.typ": *
#show: acmart.with(
  format: "acmsmall", nonacm: true,
  bib-backend: "bibtex",
  tex-render: s => default-tex-render(s.replace("\\widget", "W").replace("\\RR", "ℝ")),
)

#let keys = ("lam", "greek", "custom", "adv", "multi")

= Introduction
Inline math in titles #cite(..keys).

#bibliography("/tests/twins/mathfields.bib")
