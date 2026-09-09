#import "/src/lib.typ": acmart, anon

#show: acmart.with(
  format: "acmsmall",
  title: "An Anonymous Submission",
  journal: "JACM",
  acm-volume: 37, acm-number: 4, acm-article: 111, acm-year: 2018, acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed", copyright-year: 2018,
  anonymous: true,
  submission-id: "123-A56-BU3",
  authors: (
    (name: "Ben Trovato", corresponding: true, email: "trovato@corporation.com",
     affiliation: (institution: "Institute for Clarity in Documentation",
                   city: "Dublin", country: "USA")),
  ),
  abstract: [
    A short journal document compiled in anonymous mode, exercising the anonymized
    author strip with its submission-id line.
  ],
  keywords: ("datasets", "anonymity"),
)

= Introduction
This document checks the anonymized author strip, the suppressed contact-info
footnote, and the anonymized ACM reference block. This work was carried out at
#anon[the Institute for Clarity in Documentation], whose name the anonymous
option replaces with the ACM-Orange substitute.
