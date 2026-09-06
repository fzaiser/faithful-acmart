// Direct unit tests for shared ACM bibliography helpers (src/parts/acmref-*.typ).
//
// These run WITHOUT the LaTeX/pdftotext harness: the file compiles, and a failing
// #assert.eq aborts the Typst compile. Run standalone
//   tools/tc compile tests/unit/acmref.typ /dev/null
// or via the harness as the "unit" tier (tools/test.py unit / test.py check).

#import "/src/parts/acmref-common.typ": year-value

// year-value: prefer `year`, else the leading 4 chars of an ISO `date`, else the
// "[n.\,d.]" fallback (thin space U+2009, matching format.year / calc.basic.label).
#let e(..f) = (fields: f.named())
#let nd = "[n.\u{2009}d.]"
#assert.eq(year-value(e(year: "1999")), (c: "1999", p: false))
#assert.eq(year-value(e(date: "2020-05-01")), (c: "2020", p: false))
#assert.eq(year-value(e(date: "2020")), (c: "2020", p: false))
#assert.eq(year-value(e()), (c: nd, p: false))
// Regression: a `date` shorter than four characters used to panic on .slice(0, 4)
// (index out of bounds); it must now fall back to the n.d. marker like a missing date.
#assert.eq(year-value(e(date: "99")), (c: nd, p: false))
#assert.eq(year-value(e(date: "")), (c: nd, p: false))

// ---- BibLaTeX sort key ----------------------------------------------------
// biber's `nty` template (biblatex.def:1493) and its name key template (:1451).
// The twin pair `tests/twins/biblatex-sort-test{,-numeric-test}` covers this end
// to end against LaTeX; the cases below are the >9-name shapes no twin can
// carry: under acmauthoryear biber widens such lists by uniquelist before
// sorting (the gap recorded in DESIGN.md), so they are asserted under the
// acmnumeric configuration, where biber truncates. Every expectation was read
// off real biber output.
#import "/src/parts/acmref-biblatex.typ": blx-sort-key, blx-np-lengths
#import "/src/parts/bibtex.typ": parse-names

#let entry(authors, title) = (
  entry-type: "article",
  fields: if authors == "" { (title: title) } else { (author: authors, title: title) },
  names: if authors == "" { (:) } else { (author: parse-names(authors)) },
)
#let order(useprefix, ..pairs) = {
  let db = pairs.pos()
  let lens = blx-np-lengths(db.map(((k, en)) => en))
  db.sorted(key: ((k, en)) => blx-sort-key(en, lens: lens, useprefix: useprefix)).map(((k, en)) => k)
}
#let nine(lead, rest) = lead + rest.split(" ").map(p => " and " + p + " " + p).sum(default: "")

// maxsortnames is 9 (biblatex.sty:15008 pulls it to ACM's maxbibnames): past
// that biber sorts on the first name alone plus a marker that outranks every
// character, so the rest of the list stops mattering and the title decides.
// Checked in the acmnumeric configuration, which is the only one that can show
// it: acmauthoryear widens uniquelist over exactly these two lists and sorts on
// the widened count instead (DESIGN.md).
#assert.eq(order(true,
  ("ten-a", entry(nine("Ten Ten", "Bb Bc Bd Be Bf Bg Bh Bi Bj"), "A title")),
  ("ten-b", entry(nine("Ten Ten", "Aa Ab Ac Ad Ae Af Ag Ah Ai"), "Z title"))),
  ("ten-a", "ten-b"))
// Nine names are still all used, so the second name decides instead.
#assert.eq(order(true,
  ("nine-a", entry(nine("Nin Nin", "Bb Bc Bd Be Bf Bg Bh Bi"), "A title")),
  ("nine-b", entry(nine("Nin Nin", "Aa Ab Ac Ad Ae Af Ag Ah"), "Z title"))),
  ("nine-b", "nine-a"))
// A trailing "and others" is not a name: it neither counts toward the limit nor
// marks the list truncated, so it files exactly where the bare name does.
#assert.eq(order(false,
  ("solo", entry("Ozzy Oak", "Oak on its own")),
  ("others", entry("Ozzy Oak and others", "Oak and others"))),
  ("others", "solo"))
// `useprefix` is on under acmnumeric (trad-standard.bbx:18) and off under
// acmauthoryear, which files the same prefixed name in two different places.
#let prefixed = (
  ("bachman", entry("Bo Bachman", "T")),
  ("beethoven", entry("Ludwig van Beethoven", "T")),
  ("berg", entry("Al Berg", "T")),
)
#assert.eq(order(true, ..prefixed), ("bachman", "berg", "beethoven"))
#assert.eq(order(false, ..prefixed), ("bachman", "beethoven", "berg"))
// The name slot falls back from author to editor (useeditor is on) and then to
// the title (usetranslator is off). An editor-led entry cannot go in the twin:
// LaTeX spaces its acmauthoryear lead differently, which is its own gap.
#assert.eq(order(false,
  ("ed", (entry-type: "book", fields: (editor: "Ed Editor", title: "Zzz"),
          names: (editor: parse-names("Ed Editor")))),
  ("tr", (entry-type: "book", fields: (translator: "Aa Aa", title: "Filed under this title"),
          names: (translator: parse-names("Aa Aa"))))),
  ("ed", "tr"))

// ---- BibLaTeX name initials ------------------------------------------------
// gen_initials (Utils.pm:1775) splits a name on the Dash PROPERTY, which is
// wider than the dash punctuation category the noinit and nosort patterns use.
// The twin pair covers the ASCII hyphen; the three below cannot go in one,
// because pdflatex prints them all as an em dash and Typst prints the character
// it was given. Every expectation was read off real biber (the .bbl `giveni`).
#import "/src/parts/acmref-blxnames.typ": name-initials
#assert.eq(name-initials("Jean-Paul"), "J.-P.")
#assert.eq(name-initials("Jean\u{2015}Paul"), "J.-P.")   // horizontal bar, Pd
#assert.eq(name-initials("Jean\u{2212}Paul"), "J.-P.")   // minus sign, Sm
#assert.eq(name-initials("Jean\u{FF0D}Paul"), "J.-P.")   // fullwidth hyphen, Pd

// A brace is only ever consumed with its partner, and biber decides which pairs
// go: the ones protecting an ACCENT leave with it, the ones around a letter
// macro stay. Read off real biber, which parses "M{\"u}ller" as the namepart
// "Müller" and "{\ae}-Paul" as "{æ}-Paul" — and initials the second "æ.-P."
// all the same, because the split at the dash is outside those braces.
#import "/src/parts/tex.typ": decode-chars
#assert.eq(decode-chars("M{\\\"u}ller"), "Mu\u{308}ller")
#assert.eq(decode-chars("{\\ae}-Paul"), "{æ}-Paul")
#assert.eq(name-initials("{\\ae}-Paul"), "æ.-P.")
