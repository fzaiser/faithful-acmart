#import "/src/lib.typ": *
#show: acmart.with(format: "acmsmall", bib-backend: "biblatex")

#heading(numbering: none, level: 1)[BibLaTeX Numeric Driver Cases]
This sentence cites a report #cite("DriverReport") and a legacy techreport
#cite("DriverTechreport"), plus a translated article
#cite("DriverTranslatedArticle"), a translator-only book
#cite("DriverTranslatorBook"), and a patent #cite("DriverPatent").

#bibliography("/tests/twins/biblatex-driver-test.bib")
