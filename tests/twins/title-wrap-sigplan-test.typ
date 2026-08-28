// title-wrap-sigplan-test — a wrapping \Huge serif-bold sigplan title.
// Matched twin: title-wrap-sigplan-test.tex.
// The largest title font shows a leading error most clearly: descenders of the first line collide with capitals of the second.
#import "/src/lib.typ": acmart

#show: acmart.with(
  format: "sigplan",
  title: "Wrapped Titles Keep the Baselineskip on Each Line: Typographic Notes on Descenders Above Capitals",
  conference: (short: "Conference'17", date: "June 2018", venue: "Washington, DC, USA"),
  booktitle: "Proceedings of ACM Conference (Conference'17)",
  isbn: "978-1-4503-XXXX-X/2018/06",
  doi: "XXXXXXX.XXXXXXX",
  acm-year: 2018, acm-month: 6,
  copyright: "acmlicensed", copyright-year: 2018,
  authors: (
    (name: "Ben Trovato", email: "trovato@corporation.com",
     affiliation: (institution: "Institute for Clarity in Documentation",
                   city: "Dublin", state: "Ohio", country: "USA")),
  ),
  abstract: [
    A title that wraps onto a second line must keep the title font's baselineskip between its lines, or the descenders of one line collide with the capitals of the next.
  ],
)

= Introduction
The body only needs to exist so that the page has a first section below the title block.
