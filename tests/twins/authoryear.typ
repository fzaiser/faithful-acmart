#import "/src/lib.typ": *
#show: acmart.with(format: "acmsmall", nonacm: true, bib-backend: "bibtex", cite-style: "author-year")

= Introduction
Text #cite("smithA", "smithB"). Also #cite-text("jones") and #cite("green").
Presort a/b grouping #cite("grpA", "grpB", "grpC") and org sort #cite("OrgProc").
The label dispatch reads the literal entry type, so an aliased one takes neither an editor nor an organization #cite("OnlOrg", "ColEd", "DatEd"), where a literal manual takes the organization #cite("ManOrg") and an explicit key outranks it #cite("WebKey").

#bibliography("/tests/twins/authoryear.bib")
