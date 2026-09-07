// Model of LaTeX's \@addpunct for the places where acmart appends terminal
// punctuation: \@adddotafter (acmart.dtx:8534), \@setthanks (dtx:7839),
// \@setauthorsaddresses (dtx:7847) and the proof head (dtx:8807).
//
// \@addpunct{X} appends X only when \spacefactor <= 1000, which is NOT the same
// as "the text already ends in punctuation". An uppercase letter sets the space
// factor to 999, and TeX clamps a following sfcode above 1000 back down to 1000
// rather than letting it through, so "...in the UK." still receives a second
// full stop while "...in England." does not. Verified against the class.

// Space factor codes from plain TeX's table: ) ] ' leave the factor unchanged,
// sentence punctuation raises it, uppercase letters lower it to 999. Spaces are
// glue and never touch the factor either.
#let _sfcode(c) = {
  if c == ")" or c == "]" or c == "'" or c.trim() == "" { 0 }
  else if c == "." or c == "?" or c == "!" { 3000 }
  else if c == ":" { 2000 }
  else if c == ";" { 1500 }
  else if c == "," { 1250 }
  else if upper(c) == c and lower(c) != c { 999 }
  else { 1000 }
}

#let _space-factor(s) = {
  let sf = 1000
  for c in s {
    let f = _sfcode(c)
    if f == 0 { continue }
    sf = if f == 1000 or (sf < 1000 and f > 1000) { 1000 } else { f }
  }
  sf
}

// The factor depends only on the last couple of characters, so a short trailing
// window is enough and spares us flattening arbitrary content.
//
// Content we cannot read as text still typesets *something* — a reference's
// number, a citation, an image, a formula — and TeX sets the space factor to
// 1000 after a box or after math, so such content stands in as a digit. Glue
// and metadata put no character on the line and leave the factor alone, so the
// walk carries on past them into the text before.
#let _opaque = "0"

#let _trailing(c, want: 16) = {
  if type(c) == str { return c }
  if type(c) != content { return "" }
  // Several of these element functions aren't exposed, so match on the name,
  // as `_body-starts-with-paragraph` in lib.typ does.
  let name = repr(c.func())
  if name in ("space", "h", "v", "parbreak", "linebreak", "pagebreak", "place",
              "metadata", "state", "counter", "update") { return "" }
  if name in ("equation", "box", "image", "hide") { return _opaque }
  if name == "smartquote" { return "'" }
  if c.has("text") { return c.text }
  if c.has("body") { return _trailing(c.body, want: want) }
  if c.has("children") {
    let out = ""
    for child in c.children.rev() {
      out = _trailing(child, want: want - out.len()) + out
      if out.len() >= want { break }
    }
    return out
  }
  _opaque
}

#let needs-punct(c) = _space-factor(_trailing(c)) <= 1000

#let add-punct(c, mark: [.]) = if needs-punct(c) { [#c#mark] } else { c }
