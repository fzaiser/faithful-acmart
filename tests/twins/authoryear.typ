#import "/src/lib.typ": *
#show: acmart.with(format: "acmsmall", bib-backend: "bibtex", cite-style: "author-year")

= Introduction
Text #cite("smithA", "smithB"). Also #cite-text("jones") and #cite("green").
Presort a/b grouping #cite("grpA", "grpB", "grpC") and org sort #cite("OrgProc").

#bibliography("/tests/twins/authoryear.bib")
