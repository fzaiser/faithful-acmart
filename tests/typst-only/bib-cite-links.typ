#import "/src/lib.typ": *
// Happy path for the in-text cite -> reference-list hyperlinks: numbers `link` to the
// entry labels (see `parts/acmref-cite.typ`). Many `@key`s incl. dotted keys in one
// sentence also guards the resolve path against a `read(none)` regression (the error
// case — citing with no acmart bibliography — is `cite-without-bibliography`).
#show: acmart.with(format: "acmsmall", bib-backend: "bibtex")

= Introduction
This sentence cites several works to exercise the bibliography style
@Ablamowicz07 @JCohen96 @Clarkson:1985:ACP:911891 @Hollis:1999:VBD:519964 @Goossens:1999:LWC:553897 @Buss:1987:VTB:897367 @Li:2008:PUC:1358628.1358946 @Conti:2009:DDS:1555009.1555162.

#bibliography("/tests/twins/sample-base.bib")
