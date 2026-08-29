// Localization for the acmart `language` option (acmart.dtx:2847-3339).
//
// acmart loads babel with the languages given by repeated `language=` keys; the
// LAST one is the document's main language, the others are secondary (used only
// for translated top matter). We expose this more safely: `language` names the
// single MAIN language, and secondary languages are the keys of the `translations`
// argument (which carries the translated top matter) — so there is no error-prone
// "last item wins" list.
//
// Only a handful of fixed strings are language-dependent in output, and acmart
// itself renews just two of them per language — \keywordsname and \acksname
// (acmart.dtx:3304-3338). \keywordsname differs between journal and proceedings
// formats; \proofname, \tablename, \abstractname (the proceedings abstract
// heading) and \refname (the bibliography heading, acmart.dtx:3166) come from
// babel; CCS Concepts, the ACM Reference Format block, theorem names (\newtheorem
// ...{Theorem}, never wrapped in a babel caption), \received, the andified author
// lists and the permission text all stay English regardless of language
// (acmart.dtx:1238 — "CCS concepts are always typeset in English"). The strings
// below are verified against a real LaTeX+babel build (tests/twins/language-*).

// Per-language table. `code` is the Typst text-lang code (drives hyphenation).
// `abstract` is babel's \abstractname: the proceedings abstract heading, and the
// heading of each translated abstract in its own language (acmart.dtx:3420).
// `references` is babel's \refname, the bibliography heading.
#let _langs = (
  english: (code: "en",
    keywords: "Additional Key Words and Phrases",
    keywords_proceedings: "Keywords",
    acks: "Acknowledgements", proof: "Proof", table: "Table", abstract: "Abstract",
    references: "References"),
  french: (code: "fr",
    keywords: "Mots Clés et Phrases Supplémentaires",
    keywords_proceedings: "Mots clés",
    acks: "Remerciements", proof: "Démonstration", table: "Table", abstract: "Résumé",
    references: "Références"),
  german: (code: "de",
    keywords: "Zusätzliche Schlagwörter und Phrasen",
    keywords_proceedings: "Schlagwörter",
    acks: "Danksagungen", proof: "Beweis", table: "Tabelle", abstract: "Zusammenfassung",
    references: "Literatur"),
  spanish: (code: "es",
    keywords: "Palabras y Frases Claves Adicionales",
    keywords_proceedings: "Palabras claves",
    acks: "Expresiones de gratitud", proof: "Demostración", table: "Cuadro", abstract: "Resumen",
    references: "Referencias"),
)

// Monolingual default (no `language` option). \keywordsname for journals is set
// unconditionally (acmart.dtx:3294) and \acksname defaults to the American
// "Acknowledgments" (acmart.dtx:8839); only with babel does english become the
// British "Acknowledgements" (acmart.dtx:3310).
#let default-strings = (
  code: "en",
  keywords: "Additional Key Words and Phrases",
  keywords_proceedings: "Keywords",
  acks: "Acknowledgments", proof: "Proof", table: "Table", abstract: "Abstract",
  references: "References",
)

#let supported-languages = _langs.keys()

// Look up one language's full record (used for translated keywords, which carry
// their own \keywordsname in the secondary language; acmart.dtx:5338-5341).
#let lang-record(name) = {
  assert(name in _langs,
    message: "faithful-acmart: unsupported language " + repr(name) + "; supported: "
      + repr(supported-languages))
  _langs.at(name)
}

// Resolve the `language` option into the active string set. `language` is the
// document's single MAIN language (a supported name) or none for the monolingual
// default. Returns a dict with `code` (main Typst lang), the fixed strings, and
// `main` (the name, or none). Secondary languages are declared by the keys of the
// `translations` argument, not here, so no list is needed.
#let resolve-language(language) = {
  if language == none {
    return (..default-strings, main: none)
  }
  assert(type(language) == str, message: "faithful-acmart: `language` must be a single "
    + "language name; secondary languages go in `translations`.")
  (..lang-record(language), main: language)
}
