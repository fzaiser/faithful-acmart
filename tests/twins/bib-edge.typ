#import "/src/lib.typ": acmart, acm-cite, acm-bibliography
#show: acmart.with(format: "acmsmall", bibliography-backend: "bst")

#let keys = ("UnpubX", "MacroJournal", "ConcatTest", "DoiUrl", "ArtPages", "ColonPages", "MiscPages", "BookPages", "TRnoNum", "BookPagesField", "IssueTest", "HowPub", "KeyOnly", "ArtHP", "IpHP", "Accents", "VonNames")

= Introduction
Field-level edge cases through the bst backend #acm-cite(..keys).

#acm-bibliography("/tests/twins/bib-all-extra.bib")
