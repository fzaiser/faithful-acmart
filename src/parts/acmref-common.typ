// Shared ACM bibliography rendering primitives.

#import "tex.typ": tex-to-content
#import "theorems.typ": cfg-state

// \nolinkurl: URL text inside an \href whose display text is not the URL itself
// (the .bst's `doi:\nolinkurl{...}`). Takes the format's \urlstyle font like a
// bare \url would; plain text when rendering outside the template.
#let nolinkurl(s) = {
  let cfg = cfg-state.get()
  if cfg != none and cfg.urlstyle-sans { text(font: cfg.fonts.sans, s) } else { s }
}

// ---- render seam ----------------------------------------------------------
// Field values flow through the formatter as RAW TeX (BibTeX-style); the single
// string->content boundary is `render`, the active `tex-render` callback (the
// acmart() option, default tex-to-content). Every helper that emits *visible*
// field text routes through it, so a user override sees the raw TeX of every
// title/journal/note.
#let tex-render-state = state("acmref-texrender", tex-to-content)
#let render(s) = (tex-render-state.get())(s)
#let ends-punct(s) = {
  let t = s.trim()
  t != "" and t.last() in (".", "!", "?")
}
// The punctuation buffer reads the last VISIBLE character: a closing delimiter —
// including a case-protecting brace, which biber keeps in the field — hides the
// mark in front of it.
#let blx-visible-tail(s) = {
  let t = s.trim()
  while t != "" and t.last() in (")", "]", "}", "\"", "\u{201D}", "'", "\u{2019}") {
    t = t.slice(0, -1).trim()
  }
  t
}
#let blx-ends-punct(s) = {
  let t = blx-visible-tail(s)
  t != "" and t.last() in (".", "!", "?")
}
// a value carried through the emitter: rendered content + whether its raw text
// ends in .?! (drives the .bst add.period$ / block separators)
#let V(text, c: none) = (c: render(if c == none { text } else { c }), p: ends-punct(text))
#let it(x) = text(style: "italic", x)

// ---- field access ---------------------------------------------------------
#let fld(e, name, d: none) = e.fields.at(name, default: d)
// A field is present when it is there and not whitespace-only. The .bst reads
// one more value as absent — see `has` in acmref-bst.typ — but that is its own
// convention, so it wraps this rather than the other way round.
#let has(e, name) = {
  if name not in e.fields { return false }
  e.fields.at(name).trim() != ""
}
#let articleno-of(e) = {
  if has(e, "articleno") { fld(e, "articleno") } else if has(e, "eid") { fld(e, "eid") } else { none }
}
// A present field as a rendered value, else none (discarded by the .bst `output`);
// shared by both backends for the many "if has(e, f) { V(fld(e, f)) }" driver sites.
#let fV(e, name) = if has(e, name) { V(fld(e, name)) } else { none }

// ---- names ----------------------------------------------------------------
#let is-others(n) = n.last == "others" and n.first == "" and n.von == "" and n.jr == ""
// BibTeX's format.names writes the name suffix after a comma ("{ff }{vv }{ll}{, jj}");
// biblatex's name:given-family (biblatex.def:1068) separates it with a plain
// \bibnamedelimd space, so the two backends pass different `suffix-comma`.
#let one-name(n, suffix-comma: true) = (n.first, n.von, n.last).filter(p => p != "").join(" ") + (
  if n.jr != "" { (if suffix-comma { ", " } else { " " }) + n.jr } else { "" })

// format.names: list authors/editors in "First von Last, Jr" order
#let join-names(people, suffix-comma: true) = {
  let n = people.len()
  let out = ""
  for (i, person) in people.enumerate() {
    let nm = if is-others(person) { "et al." } else { one-name(person, suffix-comma: suffix-comma) }
    if i == 0 { out = nm }
    else if i < n - 1 { out = out + ", " + nm }
    else {
      if n > 2 { out = out + "," }
      out = out + (if is-others(person) { " " } else { " and " }) + nm
    }
  }
  out
}

// ---- small shared helpers -------------------------------------------------
// n.dashify (bst:1264) + TeX dash ligatures: a lone hyphen is promoted to an
// en-dash, "--" stays an en-dash, and "---" (or longer) is kept as an em-dash.
#let dashify(s) = s.replace(regex("-+"), m => if m.text.len() >= 3 { "\u{2014}" } else { "\u{2013}" })
#let von-last(n) = (n.von, n.last).filter(p => p != "").join(" ")
// ---- year piece -----------------------------------------------------------
// `date` may be shorter than a full YYYY (malformed input); guard the slice
// rather than letting .slice(0, 4) panic.
#let date-year(e) = {
  let date = fld(e, "date", d: "")
  if has(e, "year") { fld(e, "year") } else if date.len() >= 4 { date.slice(0, 4) } else { none }
}
// `nodate` defaults to the .bst's "[n.\,d.]" — a thin space, matching
// format.year (bst:511) and calc.basic.label; BibLaTeX cites pass their own.
#let year-value(e, nodate: "[n.\u{2009}d.]") = {
  let y = date-year(e)
  (c: if y == none { nodate } else { y }, p: false)
}
