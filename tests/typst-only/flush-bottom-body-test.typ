#import "/src/lib.typ": *

#show: acmart.with(format: "acmsmall", nonacm: true, flush-bottom: "body", title: [Body stretch], authors: ((name: "A. Author", affiliation: (institution: "Inst", country: "X")),), abstract: lorem(40))

#for i in range(1, 12) [
  = Section #i
  #lorem(60 + 13 * calc.rem(i, 5))

  #lorem(45)#footnote[Note #i.]
  - item one
  - item two
  #if calc.rem(i, 3) == 0 [
    == Subsection
    #lorem(30)
  ]
]
