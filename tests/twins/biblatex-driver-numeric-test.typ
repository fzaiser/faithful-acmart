#import "/src/lib.typ": *
#show: acmart.with(format: "acmsmall", bib-backend: "biblatex")

#heading(numbering: none, level: 1)[BibLaTeX Numeric Driver Cases]
This sentence cites a report #cite("DriverReport") and a legacy techreport
#cite("DriverTechreport").

#bibliography("/tests/twins/biblatex-driver-test.bib")
