#import "/src/lib.typ": *
#show: acmart.with(format: "acmsmall", nonacm: true, bib-backend: "biblatex")

= BibLaTeX
This sentence cites a journal article @Abril07, an online resource
@Ablamowicz07, and a proceedings article @Andler79.

Postnotes: #cite(<Abril07>, supplement: [p.~5]), #cite(<Abril07>, form: "prose", supplement: [p.~5]), #cite(<Abril07>, form: "author", supplement: [p.~5]), and #cite(<Abril07>, form: "year", supplement: [p.~5]) — BibLaTeX keeps the postnote on the author and year forms where natbib's numbers mode drops it.

#bibliography("/tests/twins/sample-base.bib")
