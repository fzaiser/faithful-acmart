// Direct tests for the model of LaTeX's \@addpunct.

#import "/src/parts/punct.typ": needs-punct, add-punct

// A lowercase letter leaves the space factor at 1000, so the punctuation that
// follows raises it past the \@addpunct threshold and nothing is appended.
#for mark in (".", "!", "?", ",", ";", ":") {
  assert(not needs-punct("Label" + mark), message: "terminal " + mark + " must suppress punctuation")
  assert.eq(add-punct("Label" + mark), "Label" + mark)
}

#assert(needs-punct("Label"))

// An uppercase letter drops the factor to 999, which clamps the following
// sfcode back to 1000 — so acmart really does print the doubled stop here.
#assert(needs-punct("Written in the UK."))
#assert(needs-punct("Written in the U.S."))
#assert(not needs-punct("Written in England."))
#assert.eq(add-punct("London, UK."), [#"London, UK."#[.]])

// Trailing space is glue and never touches the space factor.
#assert(not needs-punct("Label. "))

// Content wrappers are common at the call sites: proof names, links, styled
// headings, thanks, and author-address blocks all reach add-punct as content.
#assert(not needs-punct([#emph[Label:]]))
#assert(not needs-punct([#link("https://example.com")[Label;]]))
#assert.eq(add-punct([#strong[Label,]]), [#strong[Label,]])

// The factor has to be read across sibling runs, not just the last one.
#assert(needs-punct([#strong[UK].]))
#assert(not needs-punct([#strong[England].]))

// Math resets the space factor to 1000, so a period after a formula is the
// author's own and no second one is added — even after an uppercase variable.
#assert(not needs-punct([The case $X$.]))
#assert(needs-punct([The case $X$]))

// Content we cannot read as text still puts a character on the line: a \ref
// typesets its number, so the terminal stop is still owed.
#assert(needs-punct([Proof of Sec. #ref(<punct-target>, supplement: [])]))
#assert(not needs-punct([Proof of Sec. #h(2pt)]))

// A closing quote leaves the factor untouched, like TeX's sfcode 0.
#assert(not needs-punct[The "case."])
#assert(needs-punct[The "case"])

= Target <punct-target>
