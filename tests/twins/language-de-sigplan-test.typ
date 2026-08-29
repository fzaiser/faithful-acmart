// language-de-sigplan-test — German proceedings paper (acmart `language=german` on sigplan).
// Matched twin: language-de-sigplan-test.tex.
// Proceedings formats print the abstract heading ("Zusammenfassung") that journal formats omit, and every format heads the bibliography with babel's refname ("Literatur").
// Also covers keywordsname ("Schlagwörter"), proofname ("Beweis") and acksname ("Danksagungen").
#import "/src/lib.typ": *

#show: acmart.with(
  format: "sigplan",
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
    Eine kurze Notiz auf Deutsch, um die lokalisierten Überschriften eines Tagungsbeitrags zu prüfen.
  ],
  keywords: ("Komplexität", "Algorithmen", "Berechnung"),
)

= Einleitung
Dieses Dokument prüft die lokalisierten Zeichenketten eines Tagungsbeitrags: die Überschrift der Zusammenfassung, die Schlagwörter, den Beweis, die Danksagung und die Überschrift des Literaturverzeichnisses~@Cohen07.

#proof[Ein kurzer Beweis, der mit einem QED-Quadrat endet.]

#acks[Wir danken den Gutachtern.]

#bibliography("/tests/twins/sample-base.bib")
