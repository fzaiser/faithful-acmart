// Expected labels and disambiguation levels come from LaTeX and Biber with acmauthoryear.
// These assertions also cover hashes and tied names that PDF text comparisons cannot distinguish.

#import "/src/parts/acmref-blxnames.typ": name-list, disambiguate, list-label, list-context, list-namehash, name-forms, name-initials
#import "/src/parts/bibtex.typ": parse-names

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

#assert.eq(name-initials("John"), "J.")
#assert.eq(name-initials("Jean-Paul"), "J.-P.")
#assert.eq(name-initials("Jo~Ann"), "J. A.")
#assert.eq(name-initials("G.K.M."), "G.")
#assert.eq(name-initials(""), "")

#assert.eq(labels(("a", "John Doe"), ("b", "Edward Doe")), (a: "J. Doe", b: "E. Doe"))
#assert.eq(
  labels(("a", "Robert Fox"), ("b", "Rita Fox"), ("c", "Sam Fox")),
  (a: "Robert Fox", b: "Rita Fox", c: "S. Fox"))
#assert.eq(labels(("a", "Alan Brown"), ("b", "Alan Brown")), (a: "Brown", b: "Brown"))
#assert.eq(labels(("a", "Kaur"), ("b", "Priya Kaur")), (a: "Kaur", b: "P. Kaur"))
#assert.eq(labels(("a", "Ludwig von Berg"), ("b", "Maria Berg")), (a: "L. v. Berg", b: "M. Berg"))
#assert.eq(labels(("a", "Karl von Yew"), ("b", "Karla Yew")), (a: "Karl von Yew", b: "Karla Yew"))
#assert.eq(labels(("a", "Ludwig von Solo"), ("b", "Gerard de la Tour")), (a: "Solo", b: "Tour"))
#assert.eq(labels(("a", "Jo Ann Kite"), ("b", "Jane Kite")), (a: "J. A. Kite", b: "J. Kite"))
#assert.eq(labels(("a", "G.K.M. Wren"), ("b", "Paula Wren")), (a: "G. Wren", b: "P. Wren"))
#assert.eq(labels(("a", "John Fig and Mary Fig")), (a: "J. Fig and M. Fig"))
#assert.eq(
  labels(("a", "Amy Ant and John Bee"), ("b", "Amy Ant and Jane Bee")),
  (a: "Ant and John Bee", b: "Ant and Jane Bee"))
#assert.eq(
  labels(("a", "Zed Zulu and Kim Kilo and John Delta"), ("b", "Ella Delta")),
  (a: "Zulu et al.", b: "Delta"))

#assert.eq(
  labels(("a", "Vogel and Beast and Garble"), ("b", "Vogel and Beast and Tremble"),
         ("c", "Vogel and Acid and Squeeze")),
  (a: "Vogel, Beast, and Garble", b: "Vogel, Beast, and Tremble", c: "Vogel, Acid, et al."))
#assert.eq(
  labels(("a", "Pat Prime and Quinn Quartz and Rex Ruby and Sam Slate"),
         ("b", "Pat Prime and Quinn Quartz")),
  (a: "Prime, Quartz, et al.", b: "Prime and Quartz"))
#assert.eq(
  labels(("a", "Ann Ash and Bob Birch and Cara Cedar"), ("b", "Ann Ash and Bob Birch and Cara Cedar"),
         ("c", "Ann Ash and Dan Dogwood")),
  (a: "Ash, Birch, et al.", b: "Ash, Birch, et al.", c: "Ash and Dogwood"))
#assert.eq(
  labels(("a", "Cal Coral and Deb Dune and Eli Elm"), ("b", "Cal Coral and Deb Dune and Eli Elm")),
  (a: "Coral et al.", b: "Coral et al."))
#assert.eq(
  labels(("a", "Ann Ackee and Bo Balsa and Cy Cocoa"), ("b", "Ann Ackee and Bo Balsa and Cy Cocoa"),
         ("c", "Ann Ackee and Bo Balsa and Cy Cocoa and Di Dill")),
  (a: "Ackee, Balsa, and Cocoa", b: "Ackee, Balsa, and Cocoa",
   c: "Ackee, Balsa, Cocoa, and Dill"))
#assert.eq(
  labels(("a", "John Hill and Ann Ivy and Bo Jay"), ("b", "Jane Hill and Ann Ivy and Cy Kite")),
  (a: "John Hill et al.", b: "Jane Hill et al."))
#assert.eq(
  labels(("a", "Ann Oak and Bud Pine and Carl Quill"), ("b", "Ann Oak and Bud Pine and Dana Quill")),
  (a: "Oak, Pine, and C. Quill", b: "Oak, Pine, and D. Quill"))
#assert.eq(
  labels(("a", "Aldo Alpha and Bea Beta and others"), ("b", "Aldo Alpha and Bea Beta")),
  (a: "Alpha, Beta, et al.", b: "Alpha and Beta"))
#assert.eq(
  labels(("a", "Kay Lime and Moe Mint and Nan Nib and others"), ("b", "Ora Nib")),
  (a: "Lime et al.", b: "O. Nib"))

// Biber levels: family alone (0), initials (1), full given name (2).
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
#assert.eq(
  levels-of(("a", "Tim Teal and Uma Umbra and Val Vine"), ("b", "Tim Teal")),
  (a: (levels: (0, 0, 0), visible: 1), b: (levels: (0,), visible: 1)))

#let contexts(..entries) = {
  let lists = entries.pos().map(((k, names)) => name-list(k, parse-names(names)))
  let by-key = (:)
  for l in lists { by-key.insert(l.key, l) }
  disambiguate(lists).map(d => list-context(by-key.at(d.key), d))
}
#assert.eq(contexts(("a", "Tim Teal and Uma Umbra and Val Vine"), ("b", "Tim Teal")),
           ("Teal+", "Teal"))
#assert.eq(contexts(("a", "Alan Brown"), ("b", "Alan Brown")), ("Brown", "Brown"))
#assert.eq(contexts(("a", "John Doe"), ("b", "Edward Doe")), ("DoeJ.", "DoeE."))
// Biber's hash includes prefixes even when useprefix hides them from the label.
#assert.eq(contexts(("a", "Ludwig von Berg"), ("b", "Ludwig Berg")), ("vonBerg", "Berg"))

// namehash controls citation compression independently of the printed label.
#let hashes(..entries) = {
  let lists = entries.pos().map(((k, names)) => name-list(k, parse-names(names)))
  let by-key = (:)
  for l in lists { by-key.insert(l.key, l) }
  disambiguate(lists).map(d => list-namehash(by-key.at(d.key), d))
}
#assert.eq(hashes(("a", "King, Jr., Martin"), ("b", "Martin King")),
           ("KingMartinJr.", "KingMartin"))
#assert.eq(hashes(("a", "Alan Brown"), ("b", "Alan Brown")), ("BrownAlan", "BrownAlan"))
#assert.eq(hashes(("a", "Tim Teal and Uma Umbra and Val Vine"), ("b", "Tim Teal")),
           ("TealTim+", "TealTim"))

#assert.eq(
  name-forms(parse-names("Ludwig von Berg").first()),
  (family: "Berg", prefix: "von", given: "Ludwig", suffix: "",
   giveni: "L.", prefixi: "v.", suffixi: ""))
