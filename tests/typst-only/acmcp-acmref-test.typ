// acmcp-acmref-test — Fix A4.1: acmcp flips the ACM-reference DEFAULT to false,
// but an explicit `print-acm-reference: true` still WINS (matching a post-\begin
// \settopmatter{printacmref=true} in LaTeX; verified by probe). Package policy:
// explicit arguments override format defaults (see DESIGN.md).
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
