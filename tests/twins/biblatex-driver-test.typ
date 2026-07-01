#import "/src/lib.typ": *
#show: acmart.with(format: "acmsmall", bib-backend: "biblatex", cite-style: "author-year")

#heading(numbering: none, level: 1)[BibLaTeX Driver Cases]
This sentence cites a book #cite("DriverBook"), an in-book chapter
#cite("DriverInbook"), and an in-collection chapter #cite("DriverIncollection").

#bibliography("/tests/twins/biblatex-driver-test.bib")
