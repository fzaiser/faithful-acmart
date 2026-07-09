// Shared approximation of LaTeX's \@addpunct for places where acmart appends
// terminal punctuation without doubling an existing stop.

#let ends-with-punct(c) = {
  if type(c) == str { return c.trim().match(regex("[.!?]$")) != none }
  if type(c) != content { return false }
  if c.has("text") { return ends-with-punct(c.text) }
  if c.has("body") { return ends-with-punct(c.body) }
  if c.has("children") and c.children.len() > 0 { return ends-with-punct(c.children.last()) }
  false
}

#let add-punct(c, mark: [.]) = if ends-with-punct(c) { c } else { [#c#mark] }
