// sigconf-pages-test — continuation-page proceedings running heads/folios.
#import "../src/lib.typ": acmart

#let fill = [
  This continuation paragraph keeps the document flowing onto the next page so
  the running page style can be compared between the LaTeX and Typst renderings.
  The text is deliberately plain and avoids figures, tables, lists, and citations.
]

#show: acmart.with(
  format: "sigconf",
  title: "A sigconf Running Head Sample",
  short-title: "Conference Heads",
  short-authors: "Lovelace and Hopper",
  conference: (short: "Conference'17", date: "June 2018", venue: "Washington, DC, USA"),
  booktitle: "Proceedings of ACM Conference (Conference'17)",
  isbn: "978-1-4503-XXXX-X/2018/06",
  doi: "XXXXXXX.XXXXXXX",
  acm-year: 2018, acm-month: 6,
  copyright: "acmlicensed", copyright-year: 2018,
  authors: (
    (name: "Ada Lovelace", email: "ada@example.com",
     affiliation: (institution: "Analytical Engine Institute", country: "UK")),
    (name: "Grace Hopper", email: "grace@example.com",
     affiliation: (institution: "Compiler Laboratory", country: "USA")),
  ),
  abstract: [A short abstract for a continuation-page proceedings test.],
  keywords: ("running heads", "folios"),
)

= Continuation
#for _ in range(34) {
  fill
  parbreak()
}
