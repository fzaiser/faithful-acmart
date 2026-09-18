#import "/src/lib.typ": *

#show: acmart.with(format: "acmsmall", nonacm: true, title: [Edge stretch], authors: ((name: "A. Author", affiliation: (institution: "Inst", country: "X")),), abstract: lorem(40))

= Introduction
#lorem(80) #cite("Abril07")

// Every section carries a footnote, and the paragraph ending page 4 straddles the break with a widow.
#for i in range(1, 12) [
  = Section #i
  #lorem(60 + 13 * calc.rem(i, 5))

  #lorem(45)#footnote[Note #i.]
  - item one
  - item two
  #if calc.rem(i, 3) == 0 [
    == Subsection
    #lorem(30) #cite("Cohen07")
  ]
]

#bibliography("/tests/twins/sample-base.bib")
