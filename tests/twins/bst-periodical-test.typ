#import "/src/lib.typ": *
#show: acmart.with(format: "acmsmall", nonacm: true, bib-backend: "bibtex", cite-style: "author-year")

= Periodicals
A date that opens its block sits one space behind the title #cite("PerBare"), and so does a volume #cite("PerVolNum", "PerJournal").

A title of its own punctuation keeps it #cite("PerBang").

The same block opens an unpublished draft #cite("UnpDraft") and a journal-less article #cite("ArtNoJournal").

#bibliography("/tests/twins/bst-periodical-test.bib")
