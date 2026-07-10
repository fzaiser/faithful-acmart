// Shared approximation of LaTeX's \@addpunct for places where acmart appends
// terminal punctuation without doubling an existing stop.

#let ends-with-punct(c) = {
  // TeX's \@addpunct appends only when \spacefactor <= 1000. In the standard
  // sfcode table, comma/semicolon/colon join sentence-ending .!? above that
  // threshold, so none of these marks may acquire an extra full stop.
  if type(c) == str { return c.trim().match(regex("[.!?,;:]$")) != none }
  if type(c) != content { return false }
  if c.has("text") { return ends-with-punct(c.text) }
  if c.has("body") { return ends-with-punct(c.body) }
  if c.has("children") and c.children.len() > 0 { return ends-with-punct(c.children.last()) }
  false
}

#let add-punct(c, mark: [.]) = if ends-with-punct(c) { c } else { [#c#mark] }
