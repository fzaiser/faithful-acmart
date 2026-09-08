#import "/src/lib.typ": *
#show: acmart.with(format: "acmsmall", nonacm: true, bib-backend: "bibtex")

= Introduction
Native Typst citations @Cohen07, @Kosiur01, and @Harel78 route through the bst engine.
Variants: #cite-text(<Harel78>) #cite-alt(<Harel78>) #cite-yearpar(<Harel78>) #short-cite(<Harel78>) and #cite(<Harel78>, supplement: [p.~5]).
The bare-key shorthand carries the same postnote: @Harel78[p.~5].
Typst's citation forms reach the same natbib commands: #cite(<Harel78>, form: "prose"), #cite(<Harel78>, form: "author"), #cite(<Harel78>, form: "year"), and a silent #cite(<Cohen07>, form: none).

Postnotes: #cite(<Harel78>, form: "prose", supplement: [p.~5]), #cite-alt(<Harel78>, supplement: [p.~5]), #cite-yearpar(<Harel78>, supplement: [p.~5]), and across two keys #cite(<Cohen07>, <Harel78>, form: "prose", supplement: [p.~5]).
In numbers mode natbib drops a postnote from the author and year forms: #cite(<Harel78>, form: "author", supplement: [p.~5]) and #cite(<Harel78>, form: "year", supplement: [p.~5]).

#bibliography("/tests/twins/sample-base.bib")
