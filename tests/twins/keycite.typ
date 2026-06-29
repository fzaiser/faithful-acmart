#import "/src/lib.typ": acmart, acm-bibliography
#show: acmart.with(format: "acmsmall", bibliography-backend: "bst")

= Introduction
Native Typst citations @Cohen07, @Kosiur01, and @Harel78 route through the bst engine.

#acm-bibliography("/acmart/samples/sample-base.bib")
