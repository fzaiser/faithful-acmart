// Direct unit tests for BibLaTeX cite-label name disambiguation
// (src/parts/acmref-blxnames.typ).
//
// Every expectation here was read off real LaTeX + biber output with
// acmauthoryear (maxcitenames=2, mincitenames=1, uniquename=full,
// uniquelist=true): the labels are what the citation printed, and the levels /
// visible counts are the `un=` and `ul=` values biber wrote into the .bbl.
//
// The twin `tests/twins/biblatex-uniquename` covers the same ground end to end
// against LaTeX; this file adds the cases whose rendering survives only up to a
// non-breaking space (tied multi-word given names) and the two hashes, which no
// twin can read directly.

#import "/src/parts/acmref-blxnames.typ": name-list, disambiguate, list-label, list-context, list-namehash, name-forms, name-initials
#import "/src/parts/bibtex.typ": parse-names

// One "reference list": each entry is a key and its raw labelname list. Returns
// the printed label per key, so a case reads as its own citation.
#let labels(..entries) = {
  let lists = entries.pos().map(((k, names)) => name-list(k, parse-names(names)))
  let by-key = (:)
  for l in lists { by-key.insert(l.key, l) }
  let out = (:)
  for d in disambiguate(lists) { out.insert(d.key, list-label(by-key.at(d.key), d)) }
  out
}
#let levels-of(..entries) = {
  let lists = entries.pos().map(((k, names)) => name-list(k, parse-names(names)))
  let out = (:)
  for d in disambiguate(lists) { out.insert(d.key, (levels: d.levels, visible: d.visible)) }
  out
}

// ---- initials ------------------------------------------------------------
// biber's gen_initials: the first character of each word, hyphenated parts kept.
#assert.eq(name-initials("John"), "J.")
#assert.eq(name-initials("Jean-Paul"), "J.-P.")
#assert.eq(name-initials("Jo~Ann"), "J. A.")            // BibTeX ties separate words
#assert.eq(name-initials("G.K.M."), "G.")               // an already-initialled given name
#assert.eq(name-initials(""), "")

// ---- uniquename ----------------------------------------------------------
// Distinct initials are enough; identical initials force the whole given name;
// a third namesake still settles for an initial.
#assert.eq(labels(("a", "John Doe"), ("b", "Edward Doe")), (a: "J. Doe", b: "E. Doe"))
#assert.eq(
  labels(("a", "Robert Fox"), ("b", "Rita Fox"), ("c", "Sam Fox")),
  (a: "Robert Fox", b: "Rita Fox", c: "S. Fox"))
// Identical names are not disambiguated at all (the year letter does that job).
#assert.eq(labels(("a", "Alan Brown"), ("b", "Alan Brown")), (a: "Brown", b: "Brown"))
// A name with no given part has nothing to add, so it stays bare and its
// namesake takes the initial that tells them apart.
#assert.eq(labels(("a", "Kaur"), ("b", "Priya Kaur")), (a: "Kaur", b: "P. Kaur"))
// The prefix is not part of the disambiguation base (`useprefix` is off), so
// "von Berg" collides with "Berg" — and once disambiguated the prefix prints,
// initialled at the initials level and whole at the full-name level.
#assert.eq(labels(("a", "Ludwig von Berg"), ("b", "Maria Berg")), (a: "L. v. Berg", b: "M. Berg"))
#assert.eq(labels(("a", "Karl von Yew"), ("b", "Karla Yew")), (a: "Karl von Yew", b: "Karla Yew"))
// With no collision the prefix is dropped along with the given name.
#assert.eq(labels(("a", "Ludwig von Solo"), ("b", "Gerard de la Tour")), (a: "Solo", b: "Tour"))
// Multi-word and hyphenated given names.
#assert.eq(labels(("a", "Jo Ann Kite"), ("b", "Jane Kite")), (a: "J. A. Kite", b: "J. Kite"))
#assert.eq(labels(("a", "G.K.M. Wren"), ("b", "Paula Wren")), (a: "G. Wren", b: "P. Wren"))
// Two namesakes inside one list are disambiguated against each other.
#assert.eq(labels(("a", "John Fig and Mary Fig")), (a: "J. Fig and M. Fig"))
// A repeated identical name is not: only "Bee" is ambiguous here.
#assert.eq(
  labels(("a", "Amy Ant and John Bee"), ("b", "Amy Ant and Jane Bee")),
  (a: "Ant and John Bee", b: "Ant and Jane Bee"))
// Only *visible* names count: the Delta hidden past the truncation point leaves
// the visible one alone.
#assert.eq(
  labels(("a", "Zed Zulu and Kim Kilo and John Delta"), ("b", "Ella Delta")),
  (a: "Zulu et al.", b: "Delta"))

// ---- uniquelist ----------------------------------------------------------
// Widen to the first name that separates the lists — no further.
#assert.eq(
  labels(("a", "Vogel and Beast and Garble"), ("b", "Vogel and Beast and Tremble"),
         ("c", "Vogel and Acid and Squeeze")),
  (a: "Vogel, Beast, and Garble", b: "Vogel, Beast, and Tremble", c: "Vogel, Acid, et al."))
// Nothing branches at the third name, so it need not be shown: the "et al."
// already separates the long list from the short one.
#assert.eq(
  labels(("a", "Pat Prime and Quinn Quartz and Rex Ruby and Sam Slate"),
         ("b", "Pat Prime and Quinn Quartz")),
  (a: "Prime, Quartz, et al.", b: "Prime and Quartz"))
// Identical lists widen only as far as a third, similar list demands…
#assert.eq(
  labels(("a", "Ann Ash and Bob Birch and Cara Cedar"), ("b", "Ann Ash and Bob Birch and Cara Cedar"),
         ("c", "Ann Ash and Dan Dogwood")),
  (a: "Ash, Birch, et al.", b: "Ash, Birch, et al.", c: "Ash and Dogwood"))
// …not at all when there is no such list…
#assert.eq(
  labels(("a", "Cal Coral and Deb Dune and Eli Elm"), ("b", "Cal Coral and Deb Dune and Eli Elm")),
  (a: "Coral et al.", b: "Coral et al."))
// …and all the way when one list is a prefix of another.
#assert.eq(
  labels(("a", "Ann Ackee and Bo Balsa and Cy Cocoa"), ("b", "Ann Ackee and Bo Balsa and Cy Cocoa"),
         ("c", "Ann Ackee and Bo Balsa and Cy Cocoa and Di Dill")),
  (a: "Ackee, Balsa, and Cocoa", b: "Ackee, Balsa, and Cocoa",
   c: "Ackee, Balsa, Cocoa, and Dill"))
// uniquename feeds uniquelist: the given names already separate position 1, so
// there is nothing left for uniquelist to widen.
#assert.eq(
  labels(("a", "John Hill and Ann Ivy and Bo Jay"), ("b", "Jane Hill and Ann Ivy and Cy Kite")),
  (a: "John Hill et al.", b: "Jane Hill et al."))
// …and it does so from *every* name, including ones past the truncation point:
// the hidden Quills decide that the lists part at position 3.
#assert.eq(
  labels(("a", "Ann Oak and Bud Pine and Carl Quill"), ("b", "Ann Oak and Bud Pine and Dana Quill")),
  (a: "Oak, Pine, and C. Quill", b: "Oak, Pine, and D. Quill"))
// An "and others" list shows every name it does list, and all of them are
// visible to uniquename — so the Nib inside one disambiguates the Nib outside.
#assert.eq(
  labels(("a", "Aldo Alpha and Bea Beta and others"), ("b", "Aldo Alpha and Bea Beta")),
  (a: "Alpha, Beta, et al.", b: "Alpha and Beta"))
#assert.eq(
  labels(("a", "Kay Lime and Moe Mint and Nan Nib and others"), ("b", "Ora Nib")),
  (a: "Lime et al.", b: "O. Nib"))

// ---- the uniquename / uniquelist values biber records --------------------
// 0 = family alone, 1 = given initials, 2 = the whole given name; `visible` is
// the .bbl's `ul` where one is set and mincitenames (1) or the list length
// otherwise.
#assert.eq(
  levels-of(("a", "John Doerr and Allan Johnson and William Jones"),
            ("b", "John Doerr and Edward Johnson and William Jones"),
            ("c", "John Doerr and Jane Smithers and William Jones"),
            ("d", "John Doerr and John Smithers and William Jones"),
            ("e", "John Doerr and John Edwards and William Jones"),
            ("f", "John Doerr and John Edwards and Jack Johnson")),
  (a: (levels: (0, 1, 0), visible: 2),
   b: (levels: (0, 1, 0), visible: 2),
   c: (levels: (0, 2, 0), visible: 2),
   d: (levels: (0, 2, 0), visible: 2),
   e: (levels: (0, 0, 0), visible: 3),
   f: (levels: (0, 0, 1), visible: 3)))
// uniquelist may step all the way back to one name: the "et al." alone tells
// the long list from the short one.
#assert.eq(
  levels-of(("a", "Tim Teal and Uma Umbra and Val Vine"), ("b", "Tim Teal")),
  (a: (levels: (0, 0, 0), visible: 1), b: (levels: (0,), visible: 1)))

// ---- extradate context ---------------------------------------------------
// biber groups year letters by the visible names as printed, plus a marker for
// a truncated list — so a truncated list never shares a group with the shorter
// list it looks like.
#let contexts(..entries) = {
  let lists = entries.pos().map(((k, names)) => name-list(k, parse-names(names)))
  let by-key = (:)
  for l in lists { by-key.insert(l.key, l) }
  disambiguate(lists).map(d => list-context(by-key.at(d.key), d))
}
#assert.eq(contexts(("a", "Tim Teal and Uma Umbra and Val Vine"), ("b", "Tim Teal")),
           ("Teal+", "Teal"))
#assert.eq(contexts(("a", "Alan Brown"), ("b", "Alan Brown")), ("Brown", "Brown"))
// Disambiguated names carry what disambiguated them, so the two Does do not
// share a group even though both print a bare "Doe" in the reference list.
#assert.eq(contexts(("a", "John Doe"), ("b", "Edward Doe")), ("DoeJ.", "DoeE."))
// The prefix counts towards the group even when it is not printed: biber's
// hash walks the uniquename template without applying its `use` test.
#assert.eq(contexts(("a", "Ludwig von Berg"), ("b", "Ludwig Berg")), ("vonBerg", "Berg"))

// ---- namehash ------------------------------------------------------------
// The OTHER hash: what authoryear-comp compresses consecutive cites on. It takes
// every part of every visible name and knows nothing of uniquename, so two
// entries whose labels coincide still cite separately — "[King 2001a; King
// 2001b]", not "[King 2001a,b]" — while a genuinely repeated name list merges.
#let hashes(..entries) = {
  let lists = entries.pos().map(((k, names)) => name-list(k, parse-names(names)))
  let by-key = (:)
  for l in lists { by-key.insert(l.key, l) }
  disambiguate(lists).map(d => list-namehash(by-key.at(d.key), d))
}
#assert.eq(hashes(("a", "King, Jr., Martin"), ("b", "Martin King")),
           ("KingMartinJr.", "KingMartin"))
#assert.eq(hashes(("a", "Alan Brown"), ("b", "Alan Brown")), ("BrownAlan", "BrownAlan"))
// The hash covers only the names a cite makes visible — one here, since
// mincitenames is 1 — but carries the truncation marker, so a truncated list
// never merges with the shorter list it prints as.
#assert.eq(hashes(("a", "Tim Teal and Uma Umbra and Val Vine"), ("b", "Tim Teal")),
           ("TealTim+", "TealTim"))

// ---- name parts ----------------------------------------------------------
#assert.eq(
  name-forms(parse-names("Ludwig von Berg").first()),
  (family: "Berg", prefix: "von", given: "Ludwig", suffix: "",
   giveni: "L.", prefixi: "v.", suffixi: ""))
