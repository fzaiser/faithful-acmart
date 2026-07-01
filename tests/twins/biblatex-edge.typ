#import "/src/lib.typ": *
#show: acmart.with(format: "acmsmall", bib-backend: "biblatex", cite-style: "author-year")

#heading(numbering: none, level: 1)[BibLaTeX Edge Cases]
This sentence cites divisible books #cite("Editor00", "Editor00a"),
in-collection chapters #cite("Spector90", "Douglass98"), video entries
#cite("Obama08", "Novak03"), multi-volume books
#cite("MR781536", "MR781537"), a proceedings-in-series article
#cite("Hagerup1993"), and an authorless online resource #cite("TUGInstmem").

#bibliography("/tests/twins/sample-base.bib")
