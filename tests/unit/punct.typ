// Direct tests for the shared approximation of LaTeX's \@addpunct.

#import "/src/parts/punct.typ": ends-with-punct, add-punct

#for mark in (".", "!", "?", ",", ";", ":") {
  assert(ends-with-punct("Label" + mark), message: "terminal " + mark + " must suppress punctuation")
  assert.eq(add-punct("Label" + mark), "Label" + mark)
}

#assert(not ends-with-punct("Label"))

// Content wrappers are common at the call sites: proof names, links, styled
// headings, thanks, and author-address blocks all reach add-punct as content.
#assert(ends-with-punct([#emph[Label:]]))
#assert(ends-with-punct([#link("https://example.com")[Label;]]))
#assert.eq(add-punct([#strong[Label,]]), [#strong[Label,]])
