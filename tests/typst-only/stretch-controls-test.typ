#import "/src/lib.typ": *

#show: acmart.with(format: "acmsmall", nonacm: true)

#for i in range(7) [
  = Section #(i + 1)
  #lorem(70 + 20 * calc.rem(i, 3))

  #if i == 1 { vspace(0pt, plus: 100pt) }
  #if i == 4 { vspace(6pt) }
  #lorem(60)

  #no-stretch[
    - A first item.
    - A second item.
  ]
]
