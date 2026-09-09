#import "/src/lib.typ": acmart

#show: acmart.with(
  format: "acmcp",
  print-acm-reference: true,
  acmcp-logo: image("/src/assets/acm-jdslogo.png"),
  title: "An acmcp Reference-Format Override",
  journal: "JACM",
  acm-volume: 37, acm-number: 4, acm-article: 111, acm-year: 2018, acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed", copyright-year: 2018,
  authors: (
    (name: "Ben Trovato", email: "trovato@corporation.com",
     affiliation: (institution: "Institute for Clarity in Documentation",
                   city: "Dublin", state: "Ohio", country: "USA")),
  ),
  abstract: [A short acmcp document that re-enables the ACM Reference Format.],
)

= Introduction
The ACM Reference Format block is rendered because `print-acm-reference: true`
was passed explicitly, overriding acmcp's default suppression.
