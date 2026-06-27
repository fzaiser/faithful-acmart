#import "../src/lib.typ": acmart

#show: acmart.with(
  format: "acmsmall",
  title: "The Name of the Title Is Hope",
  journal: "JACM",
  acm-volume: 37, acm-number: 4, acm-article: 111, acm-year: 2018, acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed", copyright-year: 2018,
  abstract: [
    A clear and well-documented LaTeX document is presented as an article
    formatted for publication by ACM in a conference proceedings or journal
    publication. Based on the "acmart" document class, this article presents
    and explains many of the common variations, as well as many of the
    formatting elements an author may use in the preparation of the
    documentation of their work.
  ],
  ccs: (
    (500, "Do Not Use This Code", "Generate the Correct Terms for Your Paper"),
    (300, "Do Not Use This Code", "Generate the Correct Terms for Your Paper"),
    (100, "Do Not Use This Code", "Generate the Correct Terms for Your Paper"),
    (100, "Do Not Use This Code", "Generate the Correct Terms for Your Paper"),
  ),
  authors: (
    (name: "Ben Trovato", note: [Both authors contributed equally to this research.], email: "trovato@corporation.com", orcid: "1234-5678-9012",
     affiliation: (institution: "Institute for Clarity in Documentation", city: "Dublin", state: "Ohio", country: "USA")),
    (name: "G.K.M. Tobin", note: [Both authors contributed equally to this research.], corresponding: true, email: "webmaster@marysville-ohio.com",
     affiliation: (institution: "Institute for Clarity in Documentation", city: "Dublin", state: "Ohio", country: "USA")),
    (name: "Lars Thørväld", email: "larst@affiliation.org",
     affiliation: (institution: "The Thørväld Group", city: "Hekla", country: "Iceland")),
    (name: "Valerie Béranger",
     affiliation: (institution: "Inria Paris-Rocquencourt", city: "Rocquencourt", country: "France")),
    (name: "Aparna Patel",
     affiliation: (institution: "Rajiv Gandhi University", city: "Doimukh", state: "Arunachal Pradesh", country: "India")),
    (name: "Huifen Chan",
     affiliation: (institution: "Tsinghua University", city: "Haidian Qu", state: "Beijing Shi", country: "China")),
    (name: "Charles Palmer", email: "cpalmer@prl.com",
     affiliation: (institution: "Palmer Research Laboratories", city: "San Antonio", state: "Texas", country: "USA")),
    (name: "John Smith", email: "jsmith@affiliation.org",
     affiliation: (institution: "The Thørväld Group", city: "Hekla", country: "Iceland")),
    (name: "Julius P. Kumquat", corresponding: true, email: "jpkumquat@consortium.net",
     affiliation: (institution: "The Kumquat Consortium", city: "New York", country: "USA")),
  ),
)

= Introduction
ACM's consolidated article template, introduced in 2017, provides a consistent
LaTeX style for use across ACM publications, and incorporates accessibility and
metadata-extraction functionality necessary for future Digital Library
endeavors. Numerous ACM and SIG-specific LaTeX templates have been examined, and
their unique features incorporated into this single new template.
