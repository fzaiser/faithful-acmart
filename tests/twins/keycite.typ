#import "/src/lib.typ": *
#show: acmart.with(format: "acmsmall", bib-backend: "bibtex")

= Introduction
Native Typst citations @Cohen07, @Kosiur01, and @Harel78 route through the bst engine.
Variants: #cite-text(<Harel78>) #cite-alt(<Harel78>) #cite-yearpar(<Harel78>) #short-cite(<Harel78>) and #cite(<Harel78>, supplement: [p.~5]).

#bibliography("/tests/twins/sample-base.bib")
