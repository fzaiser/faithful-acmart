#import "/src/lib.typ": *
#show: acmart.with(format: "acmsmall", nonacm: true, bib-backend: "bibtex")

#let keys = ("xchild1", "xchild2", "xsolo", "prockey", "durl")

= Introduction
Crossref + small bst features #cite(..keys).

#bibliography("/tests/twins/crossref.bib")
