#import "/src/lib.typ": acmart, acm-cite
#show: acmart.with(format: "acmsmall", bibliography-backend: "biblatex", cite-style: "author-year")

#heading(numbering: none, level: 1)[BibLaTeX Edge Cases]
This sentence cites divisible books #acm-cite("Editor00", "Editor00a"),
in-collection chapters #acm-cite("Spector90", "Douglass98"), video entries
#acm-cite("Obama08", "Novak03"), multi-volume books
#acm-cite("MR781536", "MR781537"), a proceedings-in-series article
#acm-cite("Hagerup1993"), and an authorless online resource #acm-cite("TUGInstmem").

#bibliography("/tests/twins/sample-base.bib")
