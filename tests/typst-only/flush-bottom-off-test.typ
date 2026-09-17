#import "/src/lib.typ": *

#show: acmart.with(format: "acmsmall", nonacm: true, flush-bottom: false)

#for i in range(7) [
  = Section #(i + 1)
  #lorem(70 + 20 * calc.rem(i, 3))

  - A first item.
  - A second item.

  #lorem(60)
]
