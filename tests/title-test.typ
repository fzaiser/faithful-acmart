#import "../src/lib.typ": acmart

#show: acmart.with(
  format: "acmsmall",
  title: "The Name of the Title Is Hope",
  journal: "JACM",
  acm-volume: 37, acm-number: 4, acm-article: 111, acm-year: 2018, acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed", copyright-year: 2018,
  authors: (
    (name: "Ben Trovato", marks: ("*",), email: "trovato@corporation.com", orcid: "1234-5678-9012",
     affiliation: (institution: "Institute for Clarity in Documentation", city: "Dublin", state: "Ohio", country: "USA")),
    (name: "G.K.M. Tobin", marks: ("*",), email: "webmaster@marysville-ohio.com",
     affiliation: (institution: "Institute for Clarity in Documentation", city: "Dublin", state: "Ohio", country: "USA")),
    (name: "Lars Thørväld", email: "larst@affiliation.org",
     affiliation: (institution: "The Thørväld Group", city: "Hekla", country: "Iceland")),
    (name: "Valerie Béranger",
     affiliation: (institution: "Inria Paris-Rocquencourt", city: "Rocquencourt", country: "France")),
    (name: "Aparna Patel",
     affiliation: (institution: "Rajiv Gandhi University", city: "Doimukh", country: "India")),
    (name: "Huifen Chan",
     affiliation: (institution: "Tsinghua University", city: "Haidian Qu", country: "China")),
    (name: "Charles Palmer",
     affiliation: (institution: "Palmer Research Laboratories", city: "San Antonio", state: "Texas", country: "USA")),
    (name: "John Smith",
     affiliation: (institution: "The Thørväld Group", city: "Hekla", country: "Iceland")),
    (name: "Julius P. Kumquat",
     affiliation: (institution: "The Kumquat Consortium", city: "New York", country: "USA")),
  ),
)

A clear and well-documented LaTeX document is presented as an article formatted
for publication by ACM in a conference proceedings or journal publication.
