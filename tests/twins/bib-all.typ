#import "/src/lib.typ": acmart, acm-cite, acm-bibliography
#show: acmart.with(format: "acmsmall", bibliography-backend: "bst")

#let keys = (
  "Cohen07", "JCohen96", "Kosiur01", "Editor00", "Editor00a", "Spector90",
  "Andler79", "anisi03", "Clarkson85", "Harel78", "Thornburg01", "CleanManual",
  "Poker06", "Reiser2014", "Baggett2025", "Bornmann2019", "R", "UMassCitations",
  "CleanProc20", "CleanBooklet",
)

= Introduction
Every entry type, exercised through the bst backend #acm-cite(..keys).

#acm-bibliography(("/acmart/samples/sample-base.bib", "/tests/twins/bib-all-extra.bib"))
