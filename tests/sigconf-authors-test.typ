// sigconf-authors-test — conference author grid with a PARTIAL last row.
// Matched twin: sigconf-authors-test.tex. Five affiliation groups at 3-per-row
// produce a full first row of 3 + a final row of 2; the fix for the partial last
// row centers that final row (acmart centers every row) instead of left-aligning
// it. Isolates make-authors-grid's row chunking/centering.
#import "../src/lib.typ": acmart

#show: acmart.with(
  format: "sigconf",
  title: "Five Authors, Two Rows",
  conference: (short: "Conference'17", venue: "Washington, DC, USA"),
  isbn: "978-1-4503-XXXX-X/2018/06",
  doi: "XXXXXXX.XXXXXXX",
  acm-year: 2018, acm-month: 6,
  copyright: "acmlicensed", copyright-year: 2018,
  authors: (
    (name: "Ben Trovato", email: "trovato@corporation.com",
     affiliation: (institution: "Institute for Clarity", city: "Dublin", country: "USA")),
    (name: "Lars Thørväld", email: "larst@affiliation.org",
     affiliation: (institution: "The Thørväld Group", city: "Hekla", country: "Iceland")),
    (name: "Valerie Béranger", email: "valerie@inria.fr",
     affiliation: (institution: "Inria Paris-Rocquencourt", city: "Rocquencourt", country: "France")),
    (name: "Aparna Patel", email: "aparna@rsc.org",
     affiliation: (institution: "Rajiv Gandhi University", city: "Doimukh", country: "India")),
    (name: "Huifen Chan", email: "huifen@tsinghua.edu",
     affiliation: (institution: "Tsinghua University", city: "Beijing", country: "China")),
  ),
  abstract: [
    A proceedings document with five authors, used to check that the conference
    author grid centers a partial final row of boxes.
  ],
)

= Introduction
This isolates the author grid's row layout. #lorem(40)
