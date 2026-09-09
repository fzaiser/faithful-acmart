#import "/src/lib.typ": *
#show: acmart.with(format: "acmsmall", title: "Relative Bibliography Path", doi: none, bib-backend: "bibtex")

= Body
A citation of the sibling bibliography @RelKey.

#bibliography("bib-relative.bib")
