#import "/src/parts/acmref-common.typ": year-value

#let e(..f) = (fields: f.named())
#let nd = "[n.\u{2009}d.]"
#assert.eq(year-value(e(year: "1999")), (c: "1999", p: false))
#assert.eq(year-value(e(date: "2020-05-01")), (c: "2020", p: false))
#assert.eq(year-value(e(date: "2020")), (c: "2020", p: false))
#assert.eq(year-value(e()), (c: nd, p: false))
#assert.eq(year-value(e(date: "99")), (c: nd, p: false))
#assert.eq(year-value(e(date: "")), (c: nd, p: false))

// Sort expectations come from Biber with acmnumeric.
// Its name limit remains fixed; acmauthoryear can widen it through uniquelist.
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

#assert.eq(order(true,
  ("ten-a", entry(nine("Ten Ten", "Bb Bc Bd Be Bf Bg Bh Bi Bj"), "A title")),
  ("ten-b", entry(nine("Ten Ten", "Aa Ab Ac Ad Ae Af Ag Ah Ai"), "Z title"))),
  ("ten-a", "ten-b"))
#assert.eq(order(true,
  ("nine-a", entry(nine("Nin Nin", "Bb Bc Bd Be Bf Bg Bh Bi"), "A title")),
  ("nine-b", entry(nine("Nin Nin", "Aa Ab Ac Ad Ae Af Ag Ah"), "Z title"))),
  ("nine-b", "nine-a"))
#assert.eq(order(false,
  ("solo", entry("Ozzy Oak", "Oak on its own")),
  ("others", entry("Ozzy Oak and others", "Oak and others"))),
  ("others", "solo"))
#let prefixed = (
  ("bachman", entry("Bo Bachman", "T")),
  ("beethoven", entry("Ludwig van Beethoven", "T")),
  ("berg", entry("Al Berg", "T")),
)
#assert.eq(order(true, ..prefixed), ("bachman", "berg", "beethoven"))
#assert.eq(order(false, ..prefixed), ("bachman", "beethoven", "berg"))
#assert.eq(order(false,
  ("ed", (entry-type: "book", fields: (editor: "Ed Editor", title: "Zzz"),
          names: (editor: parse-names("Ed Editor")))),
  ("tr", (entry-type: "book", fields: (translator: "Aa Aa", title: "Filed under this title"),
          names: (translator: parse-names("Aa Aa"))))),
  ("ed", "tr"))

// Initials come from Biber's giveni output.
// These Unicode dashes render differently across engines, so PDF comparisons cannot cover them.
#import "/src/parts/acmref-blxnames.typ": name-initials
#assert.eq(name-initials("Jean-Paul"), "J.-P.")
#assert.eq(name-initials("Jean\u{2015}Paul"), "J.-P.") // Horizontal bar (Pd).
#assert.eq(name-initials("Jean\u{2212}Paul"), "J.-P.") // Minus sign (Sm).
#assert.eq(name-initials("Jean\u{FF0D}Paul"), "J.-P.") // Fullwidth hyphen (Pd).

// Biber removes accent-protecting braces but retains braces around letter macros.
#import "/src/parts/tex.typ": decode-chars
#assert.eq(decode-chars("M{\\\"u}ller"), "Mu\u{308}ller")
#assert.eq(decode-chars("{\\ae}-Paul"), "{æ}-Paul")
#assert.eq(name-initials("{\\ae}-Paul"), "æ.-P.")
