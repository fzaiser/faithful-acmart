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

// Corrected mode: the punctuation set is unchanged, but an uppercase letter no longer
// hides the punctuation behind it.
#for mark in (".", "!", "?", ",", ";", ":") {
  assert(not needs-punct("Label" + mark, fix: true))
  assert(not needs-punct("LABEL" + mark, fix: true), message: "uppercase must not hide " + mark)
}
#assert(needs-punct("Label", fix: true))
#assert(not needs-punct("Written in the UK.", fix: true))
#assert(not needs-punct("Written in the U.S.", fix: true))
#assert(not needs-punct("Written in England.", fix: true))
#assert.eq(add-punct("London, UK.", fix: true), "London, UK.")
#assert.eq(add-punct("London", fix: true), [#"London"#[.]])
#assert(not needs-punct("Label. ", fix: true))
#assert(not needs-punct([#emph[Label:]], fix: true))
#assert(not needs-punct([#link("https://example.com")[Label;]], fix: true))
#assert(not needs-punct([#strong[UK].], fix: true))
#assert(not needs-punct([#strong[England].], fix: true))
#assert(not needs-punct([The case $X$.], fix: true))
#assert(needs-punct([The case $X$], fix: true))
#assert(needs-punct([Proof of Sec. #ref(<punct-target>, supplement: [])], fix: true))
#assert(not needs-punct([Proof of Sec. #h(2pt)], fix: true))
#assert(not needs-punct([The "case."], fix: true))
#assert(needs-punct([The "case"], fix: true))

// A literal closing quotation mark hides the punctuation behind it in corrected mode,
// as a smart quote already did.
#assert(not needs-punct("The \u{201C}UK.\u{201D}", fix: true))
#assert(not needs-punct("The \"UK.\"", fix: true))
#assert(not needs-punct("The \u{201C}case.\u{2019}", fix: true))
#assert.eq(add-punct("The \u{201C}UK.\u{201D}", fix: true), "The \u{201C}UK.\u{201D}")
#assert(needs-punct("The \u{201C}UK\u{201D}", fix: true))
#assert(needs-punct("The \u{201C}", fix: true), message: "an opening quote is still visible")
// The space-factor default keeps its own reading of a literal quotation mark.
#assert(needs-punct("The \u{201C}UK.\u{201D}"))
#assert(needs-punct("The \u{201C}ok.\u{201D}"))
