#import "/src/lib.typ": acmart

#show: acmart.with(
  format: "sigconf",
  title: "Five Authors, Two Rows",
  // Omit booktitle to exercise its derivation from conference metadata.
  conference: (name: "ACM Conference", short: "Conference'17", venue: "Washington, DC, USA"),
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
This isolates the author grid's row layout. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim aeque doleamus animo, cum corpore.
