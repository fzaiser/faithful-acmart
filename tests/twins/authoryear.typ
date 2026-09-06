#import "/src/lib.typ": *
#show: acmart.with(format: "acmsmall", nonacm: true, bib-backend: "bibtex", cite-style: "author-year")

= Introduction
Text #cite("smithA", "smithB"). Also #cite-text("jones") and #cite("green").
Presort a/b grouping #cite("grpA", "grpB", "grpC") and org sort #cite("OrgProc").
A label year the .bst had to take from a `date` field disambiguates against a plain `year` of the same value #cite("dtYear", "dtDate"), and two entries with no date at all share one label year too #cite("ndOne", "ndTwo").
The label dispatch reads the literal entry type, so an aliased one takes neither an editor nor an organization #cite("OnlOrg", "ColEd", "DatEd"), where a literal manual takes the organization #cite("ManOrg") and an explicit key outranks it #cite("WebKey").

#bibliography("/tests/twins/authoryear.bib")
