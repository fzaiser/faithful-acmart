// Direct unit tests for the pure-Typst .bib reader (src/parts/bibtex.typ).
//
// These run WITHOUT the LaTeX/pdftotext harness: the file simply compiles, and a
// failing #assert.eq aborts the Typst compile with a diagnostic. Run standalone
//   tools/tc compile tests/unit/bibtex.typ /dev/null
// or via the harness as the "unit" tier (tools/test.py unit / test.py check).
//
// The cases are ported from the reference parser biblatex-main/ — specifically the
// Rust unit tests in src/types/person.rs (BibTeX name grammar) and src/raw.rs
// (field/value tokenizing). We match real bibtex (the .bst oracle), which differs
// from the biblatex *crate* in a few documented spots (noted inline).

#import "/src/parts/bibtex.typ": parse-names, parse-bib

// ---- name parsing (port of person.rs) -------------------------------------
// Expected name record, in this parser's (first, von, last, jr) shape. The
// reference names the same fields given / prefix / family / suffix.
#let nm(first: "", von: "", last: "", jr: "") = (first: first, von: von, last: last, jr: jr)

#let chk-name(raw, ..expected) = {
  let got = parse-names(raw)
  let want = expected.pos()
  assert.eq(got, want, message: "parse-names(" + repr(raw) + ")\n  got:  " + repr(got) + "\n  want: " + repr(want))
}

// test_person_comma + test_person_no_comma: the "jean de la fontaine" matrix.
#chk-name("jean de la fontaine,", nm(von: "jean de la", last: "fontaine"))
#chk-name("de la fontaine, Jean", nm(first: "Jean", von: "de la", last: "fontaine"))
#chk-name("De La Fontaine, Jean", nm(first: "Jean", last: "De La Fontaine"))
#chk-name("De la Fontaine, Jean", nm(first: "Jean", von: "De la", last: "Fontaine"))
#chk-name("de La Fontaine, Jean", nm(first: "Jean", von: "de", last: "La Fontaine"))
#chk-name("", nm())
#chk-name("jean de la fontaine", nm(von: "jean de la", last: "fontaine"))
#chk-name("Jean de la fontaine", nm(first: "Jean", von: "de la", last: "fontaine"))
#chk-name("Jean De La Fontaine", nm(first: "Jean De La", last: "Fontaine"))
#chk-name("jean De la Fontaine", nm(von: "jean De la", last: "Fontaine"))
#chk-name("Jean de La Fontaine", nm(first: "Jean", von: "de", last: "La Fontaine"))

// test_person_two_comma: "<Last>, <Suffix>, <First>".
#chk-name("Mudd, Sr., Harcourt Fenton", nm(first: "Harcourt Fenton", last: "Mudd", jr: "Sr."))

// test_list_of_names + the " and " separator (split_token_lists_with_kw).
#chk-name(
  "Johannes Gutenberg and Aldus Manutius and Claude Garamond",
  nm(first: "Johannes", last: "Gutenberg"),
  nm(first: "Aldus", last: "Manutius"),
  nm(first: "Claude", last: "Garamond"),
)
// test_list_of_names_multilines: newlines around "and" are whitespace.
#chk-name(
  "Johannes Gutenberg\nand\nAldus Manutius and\nClaude Garamond",
  nm(first: "Johannes", last: "Gutenberg"),
  nm(first: "Aldus", last: "Manutius"),
  nm(first: "Claude", last: "Garamond"),
)
// test_consecutive_and: "and and" yields an empty name between the two keywords.
#chk-name(
  "Johannes Gutenberg and and Aldus Manutius and Claude Garamond",
  nm(first: "Johannes", last: "Gutenberg"),
  nm(),
  nm(first: "Aldus", last: "Manutius"),
  nm(first: "Claude", last: "Garamond"),
)
// test_leading_and: a leading "and" is part of the first name, not a separator.
#chk-name(
  "and Gutenberg, Johannes and Aldus Manutius",
  nm(first: "Johannes", von: "and", last: "Gutenberg"),
  nm(first: "Aldus", last: "Manutius"),
)
// test_trailing_and: a trailing "and" is kept as a (degenerate) final name.
#chk-name(
  "Johannes Gutenberg and Aldus Manutius and Claude Garamond and",
  nm(first: "Johannes", last: "Gutenberg"),
  nm(first: "Aldus", last: "Manutius"),
  nm(first: "Claude Garamond", last: "and"),
)
// test_name_with_and_inside: "and" only splits as a standalone whitespace-bounded
// word — "Claudeand"/"Aanderson"/"anderson" stay intact.
#chk-name(
  "Johannes anderson Gutenberg and Claudeand Garamond and Aanderson Manutius",
  nm(first: "Johannes", von: "anderson", last: "Gutenberg"),
  nm(first: "Claudeand", last: "Garamond"),
  nm(first: "Aanderson", last: "Manutius"),
)

// ---- brace protection (regression for the audit fix) ----------------------
// Real bibtex treats a brace group as a single verbatim (upper-cased) token, so
// internal spaces/commas are NOT structural. (The biblatex crate splits these
// differently; we follow the .bst oracle.) The braces are kept here and stripped
// later by the formatter.
#chk-name("{Barnes and Noble}", nm(last: "{Barnes and Noble}"))
#chk-name("{de la} Fontaine, Jean", nm(first: "Jean", last: "{de la} Fontaine"))
#chk-name("Haug, {Martin}", nm(first: "{Martin}", last: "Haug"))

// ---- field / value tokenizing (port of raw.rs) ----------------------------
#let fields-of(src, key) = parse-bib(src).at(key).fields

// test_parse_article: type, field order/values, brace escape kept verbatim.
#let a = parse-bib("@article{haug2020,
  title = \"Great proceedings\\{\",
  year=2002,
  author={Haug, {Martin} and Haug, Gregor}}").at("haug2020")
#assert.eq(a.entry-type, "article")
#assert.eq(a.fields.title, "Great proceedings\\{")
#assert.eq(a.fields.year, "2002")
#assert.eq(a.names.author, (nm(first: "{Martin}", last: "Haug"), nm(first: "Gregor", last: "Haug")))

// test_resolve_string + # concatenation across an @string abbreviation. The inner
// spaces of each fragment are preserved before joining ("Tech " # "Press").
#assert.eq(fields-of("@string{BT = \"bibtex\"}@misc{x, note = BT}", "x").note, "bibtex")
#assert.eq(
  fields-of("@string{pub = \"Tech \" # \"Press\"}@misc{x, title = pub}", "x").title,
  "Tech Press",
)

// Quoted value respects brace depth: an inner {"} does not end the string.
#assert.eq(fields-of("@misc{c, note = \"a {\"} b\"}", "c").note, "a {\"} b")

// Entry types and @comment/@preamble are skipped; the entry key is trimmed.
#let db = parse-bib("@comment{ignored}
@preamble{\"\\foo\"}
@Book{ k1 , title={T} }")
#assert.eq(db.keys(), ("k1",))
#assert.eq(db.k1.entry-type, "book")

// ---- % line comments (regression for the audit fix) -----------------------
// biblatex supports `%` line comments; the old reader silently dropped the rest
// of the entry. A `%` after a value, after a comma, or after the key is skipped;
// a literal `%` inside a value is preserved.
#assert.eq(
  fields-of("@article{a, title = {Hello} % trailing\n, year = {2020}}", "a"),
  (title: "Hello", year: "2020"),
)
#assert.eq(
  fields-of("@article{b,  % after key\n title={T}, % after comma\n year={1999}}", "b"),
  (title: "T", year: "1999"),
)
#assert.eq(fields-of("@misc{p, note = {50% done}}", "p").note, "50% done")

// All assertions passed if this renders.
#set page(height: auto, width: auto, margin: 6pt)
*bibtex.typ unit tests: all assertions passed.*
