// language-test — multilingual paper (acmart `language` option).
// Matched twin: language-test.tex. Main language French, with English secondary
// title/abstract/keywords (the `translations` argument). Exercises the localized
// fixed strings — keywordsname ("Mots Clés et Phrases Supplémentaires"),
// proofname ("Démonstration"), acksname ("Remerciements") — plus French
// hyphenation (text lang "fr").
#import "/src/lib.typ": acmart, proof, acks

#show: acmart.with(
  format: "acmsmall",
  language: "french",
  title: "Une note sur la complexité de calcul",
  journal: "JACM",
  acm-volume: 37, acm-number: 4, acm-article: 111, acm-year: 2018, acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed", copyright-year: 2018,
  short-authors: "Dupont",
  authors: (
    (name: "Jean Dupont", email: "dupont@example.fr",
     affiliation: (institution: "Institut de Recherche",
                   city: "Paris", country: "France")),
  ),
  abstract: [
    Nous présentons une courte note en français afin d'exercer le mode multilingue
    de la classe acmart, avec des chaînes de caractères traduites.
  ],
  keywords: ("complexité", "algorithmes", "calcul"),
  translations: (english: (
    title: "A note on computational complexity",
    abstract: [
      We present a short note, in English, to exercise the multilingual mode of the
      acmart class with translated fixed strings.
    ],
    keywords: ("complexity", "algorithms", "computation"),
  )),
)

= Introduction
Ce document vérifie que les chaînes localisées et le contenu traduit du haut de
page correspondent entre la classe LaTeX et le portage Typst.

#proof[Voici une démonstration qui se termine par un carré CQFD.]

#acks[Nous remercions les relecteurs.]
