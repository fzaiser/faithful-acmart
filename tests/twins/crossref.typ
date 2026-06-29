#import "/src/lib.typ": acmart, acm-cite, acm-bibliography
#show: acmart.with(format: "acmsmall", bibliography-backend: "bst")

#let keys = ("xchild1", "xchild2", "xsolo", "prockey", "durl")

= Introduction
Crossref + small bst features #acm-cite(..keys).

#acm-bibliography("/tests/twins/crossref.bib")
