#import "/src/lib.typ": *
// Regression for the `bibtex` cite-path convergence edge (crash: `read(none)` when
// a cite laid out on an early introspection pass read `bib-path-state.final()` as
// its `none` init before `#bibliography` registered the path). Many `@key`s incl.
// dotted keys in one sentence is the shape that used to trip it. Also exercises the
// in-text cite -> reference-list hyperlinks (numbers `link` to the entry labels).
#show: acmart.with(format: "acmsmall", bib-backend: "bibtex")

= Introduction
This sentence cites several works to exercise the bibliography style
@Ablamowicz07 @JCohen96 @Clarkson:1985:ACP:911891 @Hollis:1999:VBD:519964 @Goossens:1999:LWC:553897 @Buss:1987:VTB:897367 @Li:2008:PUC:1358628.1358946 @Conti:2009:DDS:1555009.1555162.

#bibliography("/tests/twins/sample-base.bib")
