#import "/src/lib.typ": acmart, acm-cite
#show: acmart.with(format: "acmsmall", bibliography-backend: "biblatex", cite-style: "author-year")

#heading(numbering: none, level: 1)[BibLaTeX Driver Cases]
This sentence cites a book #acm-cite("DriverBook"), an in-book chapter
#acm-cite("DriverInbook"), and an in-collection chapter #acm-cite("DriverIncollection").

#bibliography("/tests/twins/biblatex-driver-test.bib")
