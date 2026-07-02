// sample-acmcp — port of the upstream acmart sample (acmart/samples,
// docstrip option `all,acmcp`). The ACM Journal of Data Science (JDS) cover-page
// format: single-column, rotated article-type banner, cover infobox on the right
// with code/data links and author contributions. No abstract, CCS, keywords, or
// bibliography in this variant. Diffed against out/latex/acmcp.pdf.
#import "/src/lib.typ": acmart, latex-logo

#show: acmart.with(
  format: "acmcp",
  // The JDS logo ships with the LaTeX acmart class but is ACM's trademark, so the
  // package no longer bundles it; the twin points at the repo's dev copy.
  acmcp-logo: image("/src/assets/acm-jdslogo.png"),
  title: "The Name of the Title Is Hope",
  short-authors: "Trovato et al.",
  journal: "JDS",
  acm-volume: 37, acm-number: 4, acm-article: 111, acm-year: 2018, acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed", copyright-year: 2018,
  article-type: "Review",
  code-data-link: [
    #link("https://github.com/borisveytsman/acmart") \
    #link("htps://zenodo.org/link")
  ],
  contributions: [BT and GKMT designed the study; LT, VB, and AP
    conducted the experiments, BR, HC, CP and JS analyzed the results,
    JPK developed analytical predictions, all authors participated in
    writing the manuscript.],
  // acmcp omits \authornote / \authornotemark (acmart.dtx:%<!acmcp> guards)
  authors: (
    (name: "Ben Trovato",
     email: "trovato@corporation.com", orcid: "1234-5678-9012"),
    (name: "G.K.M. Tobin", corresponding: true,
     email: "webmaster@marysville-ohio.com",
     affiliation: (institution: "Institute for Clarity in Documentation",
                   city: "Dublin", state: "Ohio", country: "USA")),
    (name: "Lars Thørväld",
     affiliation: (institution: "The Thørväld Group", city: "Hekla", country: "Iceland"),
     email: "larst@affiliation.org"),
    (name: "Valerie Béranger",
     affiliation: (institution: "Inria Paris-Rocquencourt",
                   city: "Rocquencourt", country: "France")),
    (name: "Aparna Patel",
     affiliation: (institution: "Rajiv Gandhi University", city: "Doimukh",
                   state: "Arunachal Pradesh", country: "India")),
    (name: "Huifen Chan",
     affiliation: (institution: "Tsinghua University", city: "Haidian Qu",
                   state: "Beijing Shi", country: "China")),
    (name: "Charles Palmer",
     affiliation: (institution: "Palmer Research Laboratories", city: "San Antonio",
                   state: "Texas", country: "USA"),
     email: "cpalmer@prl.com"),
    (name: "John Smith",
     affiliation: (institution: "The Thørväld Group", city: "Hekla", country: "Iceland"),
     email: "jsmith@affiliation.org"),
    (name: "Julius P. Kumquat", corresponding: true,
     affiliation: (institution: "The Kumquat Consortium", city: "New York", country: "USA"),
     email: "jpkumquat@consortium.net"),
  ),
)

= Problem statement

In this document we discuss how to write an ACM article.

= Methods

This document provides #latex-logo templates for the article. We demonstrate different
versions of ACM styles and show various options and commands. We add extensive
documentation for these commands and show examples of their use.

= Results

We hope the resulting templates and documentation will help the readers to write
submissions for ACM journals and proceedings.

= Significance

This document is important for anybody wanting to comply with the requirements of
ACM publishing.
