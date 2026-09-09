// Shared body for the BibLaTeX-backend corrections: inbook attribution, empty
// date parentheses, the opening separator, and DOI resolver normalization.
// DriverInbook supplies a chapter author, a book editor and a distinct book author.
#import "/src/lib.typ": *

#let blx-opts = (
  format: "acmsmall",
  nonacm: true,
  bib-backend: "biblatex",
  title: "BibLaTeX Backend Corrections",
)

#let blx-keys = (
  "DriverInbook", "FxInbookNoEditor", "FxInbookNoAuthor",
  "FxMiscNoDate", "FxMiscNoDateBare",
  "FxCorporate", "FxEditorLed", "FxOrgLed",
  "FxDoiUrl", "FxDoiDx", "FxDoiBare", "DriverBook",
)

#let blx-body = [
  = Drivers, dates, separators and identifiers
  Inbook chapters with and without each name list #cite("DriverInbook", "FxInbookNoEditor", "FxInbookNoAuthor").
  Entries with no date at all, with and without a publisher line #cite("FxMiscNoDate", "FxMiscNoDateBare").
  Openings that already end in a period #cite("FxCorporate", "FxEditorLed", "FxOrgLed").
  DOI fields holding a resolver URL, the legacy resolver, and a bare identifier
  #cite("FxDoiUrl", "FxDoiDx", "FxDoiBare").
  An ordinary dated book as a control #cite("DriverBook").

  #bibliography((
    "/tests/twins/biblatex-driver-test.bib",
    "/tests/typst-only/fix-quirks.bib",
  ))
]
