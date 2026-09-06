#import "/src/lib.typ": *
#show: acmart.with(format: "acmsmall", nonacm: true, bib-backend: "biblatex", cite-style: "author-year")

#heading(numbering: none, level: 1)[Labels]
#cite("LbPlain"): an explicit label stands in for the name, and the title follows it as it always would.

#cite("LbShort"): the label outranks a short title, which then prints nowhere at all.

#cite("LbNamed"): a name outranks the label in turn, and the label prints nowhere.

#cite("LbThesis"): the label is plain where the title beside it is quoted.

#cite("LbEchoA", "LbEchoB"): two entries sharing a label take no letters — an extradate letter counts the title.

#cite("LbMisc"): a driver that leads with something other than a name prints no label, but cites by one.

#heading(numbering: none, level: 1)[Textual cites]
#cite-text("LbPlain"), #cite-text("LbShort"), #cite-text("LbNamed"), #cite-text("LbThesis"), and #cite-text("LbMisc").

#bibliography("/tests/twins/biblatex-label-test.bib")
