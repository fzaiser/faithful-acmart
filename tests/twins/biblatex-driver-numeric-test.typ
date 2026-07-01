#import "/src/lib.typ": acmart, acm-cite
#show: acmart.with(format: "acmsmall", bibliography-backend: "biblatex")

#heading(numbering: none, level: 1)[BibLaTeX Numeric Driver Cases]
This sentence cites a report #acm-cite("DriverReport") and a legacy techreport
#acm-cite("DriverTechreport").

#bibliography("/tests/twins/biblatex-driver-test.bib")
