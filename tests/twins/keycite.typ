#import "/src/lib.typ": acmart
#show: acmart.with(format: "acmsmall", bibliography-backend: "bst")

= Introduction
Native Typst citations @Cohen07, @Kosiur01, and @Harel78 route through the bst engine.

#bibliography("/tests/twins/sample-base.bib")
