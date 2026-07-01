// language-es-test — Spanish multilingual paper (acmart `language=spanish`).
// Matched twin: language-es-test.tex. Verifies the Spanish fixed strings —
// keywordsname ("Palabras y Frases Claves Adicionales"), proofname
// ("Demostración"), acksname ("Expresiones de gratitud"), tablename ("Cuadro")
// — while the figure label stays "Fig." (acmart sets it globally). Includes an
// English translated title/keywords and Spanish (es) hyphenation.
#import "/src/lib.typ": acmart, proof, acks

#show: acmart.with(
  format: "acmsmall",
  language: "spanish",
  title: "Una nota sobre la complejidad computacional",
  journal: "JACM",
  acm-volume: 37, acm-number: 4, acm-article: 111, acm-year: 2018, acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed", copyright-year: 2018,
  short-authors: "Pérez",
  authors: (
    (name: "Juan Pérez", email: "perez@example.es",
     affiliation: (institution: "Instituto de Investigación",
                   city: "Madrid", country: "Spain")),
  ),
  abstract: [
    Una breve nota en español para ejercitar el modo multilingüe de la clase acmart
    con cadenas de caracteres traducidas.
  ],
  keywords: ("complejidad", "algoritmos", "cómputo"),
  translations: (english: (
    title: "A note on computational complexity",
    keywords: ("complexity", "algorithms", "computation"),
  )),
)

= Introducción
Este documento comprueba que las cadenas localizadas coinciden entre la clase
LaTeX y el porte de Typst.

#figure(
  placement: none,
  rect(width: 4cm, height: 2cm, fill: black),
  caption: [Una figura; la etiqueta permanece en inglés.],
)

#figure(
  placement: none,
  table(
    columns: 2,
    stroke: none,
    table.hline(),
    [A], [B],
    table.hline(),
    [1], [2],
    table.hline(),
  ),
  caption: [Un cuadro con etiqueta localizada.],
)

#proof[Una breve demostración que termina con un cuadrado CQD.]

#acks[Agradecemos a los revisores.]
