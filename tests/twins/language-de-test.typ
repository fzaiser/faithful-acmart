// language-de-test — German multilingual paper (acmart `language=german`).
// Matched twin: language-de-test.tex. Verifies the German fixed strings —
// keywordsname ("Zusätzliche Schlagwörter und Phrasen"), proofname ("Beweis"),
// acksname ("Danksagungen"), tablename ("Tabelle") — while the figure label
// stays "Fig." (acmart sets it globally, not per language). Includes an English
// translated title/keywords and German (de) hyphenation.
#import "/src/lib.typ": acmart, proof, acks, tabular, toprule, midrule, bottomrule

#show: acmart.with(
  format: "acmsmall",
  language: "german",
  title: "Eine Notiz über Berechnungskomplexität",
  journal: "JACM",
  acm-volume: 37, acm-number: 4, acm-article: 111, acm-year: 2018, acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed", copyright-year: 2018,
  short-authors: "Müller",
  authors: (
    (name: "Hans Müller", email: "mueller@example.de",
     affiliation: (institution: "Forschungsinstitut",
                   city: "Berlin", country: "Germany")),
  ),
  abstract: [
    Eine kurze Notiz auf Deutsch, um den mehrsprachigen Modus der Klasse acmart mit
    übersetzten Zeichenketten zu prüfen.
  ],
  keywords: ("Komplexität", "Algorithmen", "Berechnung"),
  translations: (english: (
    title: "A note on computational complexity",
    keywords: ("complexity", "algorithms", "computation"),
  )),
)

= Einleitung
Dieses Dokument prüft, dass die lokalisierten Zeichenketten zwischen der
LaTeX-Klasse und der Typst-Portierung übereinstimmen.

#figure(
  placement: none,
  rect(width: 4cm, height: 2cm, fill: black),
  caption: [Eine Abbildung; das Etikett bleibt englisch.],
)

#figure(
  placement: none,
  tabular(
    columns: 2,
    toprule(),
    [A], [B],
    midrule(),
    [1], [2],
    bottomrule(),
  ),
  caption: [Eine Tabelle mit lokalisiertem Etikett.],
)

#proof[Ein kurzer Beweis, der mit einem QED-Quadrat endet.]

#acks[Wir danken den Gutachtern.]
