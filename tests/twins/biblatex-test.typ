#import "/src/lib.typ": acmart
#show: acmart.with(format: "acmsmall", bibliography-backend: "biblatex")

= BibLaTeX
This sentence cites a journal article @Abril07, an online resource
@Ablamowicz07, and a proceedings article @Andler79.

#bibliography("/tests/twins/sample-base.bib")
