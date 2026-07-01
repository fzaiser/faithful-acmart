#import "/src/lib.typ": *
#show: acmart.with(format: "acmsmall", bib-backend: "bibtex")

= Introduction
Native Typst citations @Cohen07, @Kosiur01, and @Harel78 route through the bst engine.

#bibliography("/tests/twins/sample-base.bib")
