// Localization for the acmart `language` option (acmart.dtx:2847-3339).
//
// acmart loads babel with the languages given by repeated `language=` keys; the
// LAST one is the document's main language, the others are secondary (used only
// for translated top matter). We model the same: `language` is a babel language
// name or an ordered list whose final entry is the main language.
//
// Only a handful of fixed strings are language-dependent in output, and acmart
// itself renews just two of them per language — \keywordsname and \acksname
// (acmart.dtx:3304-3338). \keywordsname differs between journal and proceedings
// formats; \proofname and \tablename come from babel;
// CCS Concepts, the ACM Reference Format block, theorem names (\newtheorem...
// {Theorem}, never wrapped in a babel caption) and the permission text all stay
// English regardless of language (acmart.dtx:1238 — "CCS concepts are always
// typeset in English"). The strings below are verified against a real
// LaTeX+babel build (tests/language-test).

// Per-language table. `code` is the Typst text-lang code (drives hyphenation).
// `abstract` is babel's \abstractname, used to head each translated abstract
// (acmart's translatedabstract environment, acmart.dtx:3420) — secondary
// -language papers label every translated abstract with that language's name.
#let _langs = (
  english: (code: "en",
    keywords: "Additional Key Words and Phrases",
    keywords_proceedings: "Keywords",
    acks: "Acknowledgements", proof: "Proof", table: "Table", abstract: "Abstract"),
  french: (code: "fr",
    keywords: "Mots Clés et Phrases Supplémentaires",
    keywords_proceedings: "Mots clés",
    acks: "Remerciements", proof: "Démonstration", table: "Table", abstract: "Résumé"),
  german: (code: "de",
    keywords: "Zusätzliche Schlagwörter und Phrasen",
    keywords_proceedings: "Schlagwörter",
    acks: "Danksagungen", proof: "Beweis", table: "Tabelle", abstract: "Zusammenfassung"),
  spanish: (code: "es",
    keywords: "Palabras y Frases Claves Adicionales",
    keywords_proceedings: "Palabras claves",
    acks: "Expresiones de gratitud", proof: "Demostración", table: "Cuadro", abstract: "Resumen"),
)

// Monolingual default (no `language` option). \keywordsname for journals is set
// unconditionally (acmart.dtx:3294) and \acksname defaults to the American
// "Acknowledgments" (acmart.dtx:8839); only with babel does english become the
// British "Acknowledgements" (acmart.dtx:3310).
#let default-strings = (
  code: "en",
  keywords: "Additional Key Words and Phrases",
  keywords_proceedings: "Keywords",
  acks: "Acknowledgments", proof: "Proof", table: "Table",
)

#let supported-languages = _langs.keys()

// Look up one language's full record (used for translated keywords, which carry
// their own \keywordsname in the secondary language; acmart.dtx:5338-5341).
#let lang-record(name) = {
  assert(name in _langs,
    message: "acmart: unsupported language " + repr(name) + "; supported: "
      + repr(supported-languages))
  _langs.at(name)
}

// Resolve the `language` option into the active string set. Returns a dict with
// `code` (main Typst lang), the translated fixed strings, `main` (name or none),
// and `all` (the declared list, for validating translated-* keys).
#let resolve-language(language) = {
  if language == none {
    return (..default-strings, main: none, all: ())
  }
  let given = if type(language) == array { language } else { (language,) }
  assert(given.len() > 0, message: "acmart: `language` list must be non-empty")
  // acmart always seeds the babel list with english (acmart.dtx:2853-2854), so
  // english is a declared (secondary) language even when only another is named.
  let all = ("english",) + given
  let m = lang-record(given.last())
  (..m, main: given.last(), all: all)
}
