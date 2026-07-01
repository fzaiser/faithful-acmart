#import "/src/lib.typ": *
#show: acmart.with(format: "acmsmall", bib-backend: "bibtex")

#let keys = (
  "Cohen07", "JCohen96", "Kosiur01", "Editor00", "Editor00a", "Spector90",
  "Andler79", "anisi03", "Clarkson85", "Harel78", "Thornburg01", "CleanManual",
  "Poker06", "Reiser2014", "Baggett2025", "Bornmann2019", "R", "UMassCitations",
  "CleanProc20", "CleanBooklet",
)

= Introduction
Every entry type, exercised through the bst backend #cite(..keys).

#bibliography(("/tests/twins/sample-base.bib", "/tests/twins/bib-all-extra.bib"))
