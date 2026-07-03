// startpage-test — \startPage seeds the page counter.
// Matched twin: startpage-test.tex. Folios ("111:7"), running-head parity, and
// the journal footer must follow the counter, not the physical sheet index
// (acmart.dtx:6822-6825).
#import "/src/lib.typ": acmart

#let fill = [
  This continuation paragraph keeps the document flowing onto the next page so
  the running page style can be compared between the LaTeX and Typst renderings.
  The text is deliberately plain and avoids figures, tables, lists, and citations.
]

#show: acmart.with(
  format: "acmsmall",
  title: "A Start-Page Sample",
  short-title: "Start Page",
  short-authors: "Lovelace and Hopper",
  journal: "JACM",
  acm-volume: 37, acm-number: 4, acm-article: 111, acm-year: 2018, acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed", copyright-year: 2018,
  start-page: 7,
  authors: (
    (name: "Ada Lovelace", email: "ada@example.com",
     affiliation: (institution: "Analytical Engine Institute", country: "UK")),
    (name: "Grace Hopper", email: "grace@example.com",
     affiliation: (institution: "Compiler Laboratory", country: "USA")),
  ),
  abstract: [A short abstract for a start-page continuation test.],
  keywords: ("running heads", "folios"),
)

= Continuation
#for _ in range(22) {
  fill
  parbreak()
}
