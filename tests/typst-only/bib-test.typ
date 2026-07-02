#import "/src/lib.typ": acmart
// Typst-only smoke for the opt-in "typst" (native CSL) bibliography backend: it must
// compile and render a reference list via Typst's built-in ACM CSL style. "typst" is a
// documented approximation of LaTeX — the faithful default is the "bibtex" backend (the
// ACM-Reference-Format.bst port), so this is a compile/render smoke, not a diff twin.
#show: acmart.with(format: "acmsmall", bib-backend: "typst")

= Introduction
This sentence cites several works to exercise the bibliography style
@Ablamowicz07 @JCohen96 @Clarkson:1985:ACP:911891 @Hollis:1999:VBD:519964 @Goossens:1999:LWC:553897 @Buss:1987:VTB:897367 @Li:2008:PUC:1358628.1358946 @Conti:2009:DDS:1555009.1555162.

#bibliography("/tests/twins/sample-base.bib")
