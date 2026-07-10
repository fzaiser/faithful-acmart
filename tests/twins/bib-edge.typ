#import "/src/lib.typ": *
#show: acmart.with(format: "acmsmall", nonacm: true, bib-backend: "bibtex")

#let keys = ("UnpubX", "MacroJournal", "ConcatTest", "DoiUrl", "ArtPages", "ColonPages", "MiscPages", "BookPages", "TRnoNum", "BookPagesField", "IssueTest", "HowPub", "KeyOnly", "ArtHP", "IpHP", "Accents", "VonNames", "Formatting", "IpArtNo", "IpJournal", "IpEdOnly", "MiscEdIgnore", "PerNoteDoi", "ArtNoJournal", "ArtPrefixed", "QQNote", "DayMonthPer", "UnpubArt", "BracedEd", "OnePage", "URevHP")

= Introduction
Field-level edge cases through the bst backend #cite(..keys).

#bibliography("/tests/twins/bib-all-extra.bib")
