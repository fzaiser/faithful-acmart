#import "/src/lib.typ": acmart, acm-cite, acm-citet, acm-bibliography
#show: acmart.with(format: "acmsmall", bibliography-backend: "bst", cite-style: "author-year")

= Introduction
Text #acm-cite("smithA", "smithB"). Also #acm-citet("jones") and #acm-cite("green").

#acm-bibliography("/tests/twins/authoryear.bib")
