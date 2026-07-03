// fontsize-9-pages-test — multi-page layout at a non-default base size.
// Matched twin: fontsize-9-pages-test.tex. At acmsmall+9pt geometry rounds
// \textheight to 571pt and the whole ladder rescales; page parity, folios, and
// the continuation head are compared.
#import "/src/lib.typ": acmart

#show: acmart.with(
  format: "acmsmall",
  font-size: 9pt,
  title: "A Nine-Point Continuation Sample",
  short-title: "Nine Point",
  short-authors: "Lovelace",
  journal: "JACM",
  acm-volume: 37, acm-number: 4, acm-article: 111, acm-year: 2018, acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed", copyright-year: 2018,
  authors: (
    (name: "Ada Lovelace", email: "ada@example.com",
     affiliation: (institution: "Analytical Engine Institute", country: "UK")),
  ),
  abstract: [A short abstract for a nine-point continuation test.],
  keywords: ("font size", "heightrounded"),
)

#let fill = [
  This continuation paragraph keeps the document flowing onto the next page so
  the nine-point page geometry can be compared between the LaTeX and Typst
  renderings. The text is deliberately plain and avoids figures, tables, lists,
  and citations.
]

= Continuation
#for _ in range(21) {
  fill
  parbreak()
}
