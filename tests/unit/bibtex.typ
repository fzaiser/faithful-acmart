// Name and tokenization cases adapted from the biblatex Rust crate (src/types/person.rs and src/raw.rs).
// Expected values follow the BibTeX binary where its behavior differs.

#import "/src/parts/bibtex.typ": parse-names, parse-bib

#let nm(first: "", von: "", last: "", jr: "") = (first: first, von: von, last: last, jr: jr)

#let chk-name(raw, ..expected) = {
  let got = parse-names(raw)
  let want = expected.pos()
  assert.eq(got, want, message: "parse-names(" + repr(raw) + ")\n  got:  " + repr(got) + "\n  want: " + repr(want))
}

#chk-name("jean de la fontaine,", nm(von: "jean de~la", last: "fontaine"))
#chk-name("de la fontaine, Jean", nm(first: "Jean", von: "de~la", last: "fontaine"))
#chk-name("De La Fontaine, Jean", nm(first: "Jean", last: "De La~Fontaine"))
#chk-name("De la Fontaine, Jean", nm(first: "Jean", von: "De~la", last: "Fontaine"))
#chk-name("de La Fontaine, Jean", nm(first: "Jean", von: "de", last: "La~Fontaine"))
#chk-name("", nm())
#chk-name("jean de la fontaine", nm(von: "jean de~la", last: "fontaine"))
#chk-name("Jean de la fontaine", nm(first: "Jean", von: "de~la", last: "fontaine"))
#chk-name("Jean De La Fontaine", nm(first: "Jean De~La", last: "Fontaine"))
#chk-name("jean De la Fontaine", nm(von: "jean De~la", last: "Fontaine"))
#chk-name("Jean de La Fontaine", nm(first: "Jean", von: "de", last: "La~Fontaine"))

#chk-name("Mudd, Sr., Harcourt Fenton", nm(first: "Harcourt~Fenton", last: "Mudd", jr: "Sr."))

#chk-name(
  "Johannes Gutenberg and Aldus Manutius and Claude Garamond",
  nm(first: "Johannes", last: "Gutenberg"),
  nm(first: "Aldus", last: "Manutius"),
  nm(first: "Claude", last: "Garamond"),
)
#chk-name(
  "Johannes Gutenberg\nand\nAldus Manutius and\nClaude Garamond",
  nm(first: "Johannes", last: "Gutenberg"),
  nm(first: "Aldus", last: "Manutius"),
  nm(first: "Claude", last: "Garamond"),
)
#chk-name(
  "Johannes Gutenberg and and Aldus Manutius and Claude Garamond",
  nm(first: "Johannes", last: "Gutenberg"),
  nm(),
  nm(first: "Aldus", last: "Manutius"),
  nm(first: "Claude", last: "Garamond"),
)
#chk-name(
  "and Gutenberg, Johannes and Aldus Manutius",
  nm(first: "Johannes", von: "and", last: "Gutenberg"),
  nm(first: "Aldus", last: "Manutius"),
)
#chk-name(
  "Johannes Gutenberg and Aldus Manutius and Claude Garamond and",
  nm(first: "Johannes", last: "Gutenberg"),
  nm(first: "Aldus", last: "Manutius"),
  nm(first: "Claude~Garamond", last: "and"),
)
#chk-name(
  "Johannes anderson Gutenberg and Claudeand Garamond and Aanderson Manutius",
  nm(first: "Johannes", von: "anderson", last: "Gutenberg"),
  nm(first: "Claudeand", last: "Garamond"),
  nm(first: "Aanderson", last: "Manutius"),
)

#chk-name("{Barnes and Noble}", nm(last: "{Barnes and Noble}"))
#chk-name("{de la} Fontaine, Jean", nm(first: "Jean", last: "{de la}~Fontaine"))
#chk-name("Haug, {Martin}", nm(first: "{Martin}", last: "Haug"))

// Expected name boundaries come from BibTeX's format.name$ on the raw TeX input.
#chk-name("Stra\\ss e, Joe", nm(first: "Joe", last: "Stra\\ss~e"))
#chk-name("De la Fontaine, Jean", nm(first: "Jean", von: "De~la", last: "Fontaine"))
#chk-name("De La Fontaine, Jean", nm(first: "Jean", last: "De La~Fontaine"))
#chk-name("Charles Louis Xavier Joseph de la Vall\\'ee Poussin",
  nm(first: "Charles Louis Xavier~Joseph", von: "de~la", last: "Vall\\'ee~Poussin"))
#chk-name("van der Berg, Jan", nm(first: "Jan", von: "van~der", last: "Berg"))
#chk-name("Ludwig van Beethoven", nm(first: "Ludwig", von: "van", last: "Beethoven"))
#chk-name("Jones, Jr., John Paul", nm(first: "John~Paul", last: "Jones", jr: "Jr."))

#let fields-of(src, key) = parse-bib(src).at(key).fields

#let a = parse-bib("@article{haug2020,
  title = \"Great proceedings\\{\",
  year=2002,
  author={Haug, {Martin} and Haug, Gregor}}").at("haug2020")
#assert.eq(a.entry-type, "article")
#assert.eq(a.fields.title, "Great proceedings\\{")
#assert.eq(a.fields.year, "2002")
#assert.eq(a.names.author, (nm(first: "{Martin}", last: "Haug"), nm(first: "Gregor", last: "Haug")))

#assert.eq(fields-of("@string{BT = \"bibtex\"}@misc{x, note = BT}", "x").note, "bibtex")
#assert.eq(
  fields-of("@string{pub = \"Tech \" # \"Press\"}@misc{x, title = pub}", "x").title,
  "Tech Press",
)

#let ordered = parse-bib("@string{label = \"First\"}
@misc{early, title = label}
@string{label = \"Second\"}
@misc{late, title = label}")
#assert.eq(ordered.early.fields.title, "First")
#assert.eq(ordered.late.fields.title, "Second")

#let undefined = parse-bib("@misc{before, title = future, note = \"pre\" # missing # \"post\", year = 2026}
@string{future = \"Now defined\"}
@misc{after, title = future}")
#assert.eq(undefined.before.fields.title, "")
#assert.eq(undefined.before.fields.note, "prepost")
#assert.eq(undefined.before.fields.year, "2026")
#assert.eq(undefined.after.fields.title, "Now defined")

#assert.eq(
  fields-of("@string{publisher-name = \"Hyphen Press\"}@book{x, publisher = publisher-name}", "x").publisher,
  "Hyphen Press",
)

#assert.eq(fields-of("@misc{c, note = \"a {\"} b\"}", "c").note, "a {\"} b")

#let db = parse-bib("@comment{ignored}
@preamble{\"\\foo\"}
@Book{ k1 , title={T} }")
#assert.eq(db.keys(), ("k1",))
#assert.eq(db.k1.entry-type, "book")

#let paren-db = parse-bib("@string(monthname = \"May\")
@misc(p1, title = {Paren ) Entry}, note = \"quoted ) value\", month = monthname, year = 2026)")
#assert.eq(paren-db.p1.fields, (title: "Paren ) Entry", note: "quoted ) value", month: "May", year: "2026"))

#assert.eq(
  fields-of("@article{a, title = {Hello} % trailing\n, year = {2020}}", "a"),
  (title: "Hello", year: "2020"),
)
#assert.eq(
  fields-of("@article{b,  % after key\n title={T}, % after comma\n year={1999}}", "b"),
  (title: "T", year: "1999"),
)
#assert.eq(fields-of("@misc{p, note = {50% done}}", "p").note, "50% done")

#set page(height: auto, width: auto, margin: 6pt)
*bibtex.typ unit tests: all assertions passed.*
