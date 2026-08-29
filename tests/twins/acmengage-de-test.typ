// acmengage-de-test — acmengage with a German main language.
// Matched twin: acmengage-de-test.tex.
// acmengage renames the abstract "Synopsis", but only inside babel's captionsenglish; under a German main language babel's "Zusammenfassung" wins.
#import "/src/lib.typ": acmart

#show: acmart.with(
  format: "acmengage",
  language: "german",
  title: "Eine Notiz über Berechnungskomplexität",
  conference: (short: "Conference'17", date: "June 2018", venue: "Washington, DC, USA"),
  booktitle: "Proceedings of ACM Conference (Conference'17)",
  isbn: "978-1-4503-XXXX-X/2018/06",
  doi: "XXXXXXX.XXXXXXX",
  acm-year: 2018, acm-month: 6,
  copyright: "acmlicensed", copyright-year: 2018,
  authors: (
    (name: "Hans Müller", email: "mueller@example.de",
     affiliation: (institution: "Forschungsinstitut", city: "Berlin", country: "Germany")),
  ),
  abstract: [
    Eine kurze Notiz auf Deutsch, um die Überschrift der Zusammenfassung unter acmengage zu prüfen.
  ],
  keywords: ("Komplexität", "Algorithmen", "Berechnung"),
)

= Einleitung
Unter einer deutschen Hauptsprache heißt die Zusammenfassung nicht „Synopsis“.
