// Resolve publication identifiers once before any rendering path consumes them.

#import "journals.typ": lookup-journal

#let resolve-publication(journal, doi) = (
  journal: lookup-journal(journal),
  doi: if doi == none {
    none
  } else {
    (bare: doi, url: "https://doi.org/" + doi)
  },
)
