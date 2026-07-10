#import "/src/lib.typ": *
#show: acmart.with(format: "acmsmall", nonacm: true, bib-backend: "biblatex", cite-style: "author-year")

#heading(numbering: none, level: 1)[BibLaTeX Driver Cases]
This sentence cites a book #cite("DriverBook"), an in-book chapter
#cite("DriverInbook"), an in-collection chapter #cite("DriverIncollection"), a
translated article #cite("DriverTranslatedArticle"), a translator-led book
#cite("DriverTranslatorBook"), and a patent #cite("DriverPatent").

#bibliography("/tests/twins/biblatex-driver-test.bib")
