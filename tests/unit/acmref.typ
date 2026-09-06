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
