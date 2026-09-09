#import "/src/parts/punct.typ": needs-punct, add-punct

#for mark in (".", "!", "?", ",", ";", ":") {
  assert(not needs-punct("Label" + mark), message: "terminal " + mark + " must suppress punctuation")
  assert.eq(add-punct("Label" + mark), "Label" + mark)
}

#assert(needs-punct("Label"))

// An uppercase letter resets TeX's space factor, allowing the doubled stop.
#assert(needs-punct("Written in the UK."))
#assert(needs-punct("Written in the U.S."))
#assert(not needs-punct("Written in England."))
#assert.eq(add-punct("London, UK."), [#"London, UK."#[.]])

#assert(not needs-punct("Label. "))

#assert(not needs-punct([#emph[Label:]]))
#assert(not needs-punct([#link("https://example.com")[Label;]]))
#assert.eq(add-punct([#strong[Label,]]), [#strong[Label,]])

#assert(needs-punct([#strong[UK].]))
#assert(not needs-punct([#strong[England].]))

#assert(not needs-punct([The case $X$.]))
#assert(needs-punct([The case $X$]))

// A \ref typesets a number, so it still needs terminal punctuation.
#assert(needs-punct([Proof of Sec. #ref(<punct-target>, supplement: [])]))
#assert(not needs-punct([Proof of Sec. #h(2pt)]))

#assert(not needs-punct[The "case."])
#assert(needs-punct[The "case"])

= Target <punct-target>
