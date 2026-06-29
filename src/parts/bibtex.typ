// Pure-Typst BibTeX reader for the "bst" bibliography backend.
//
// Parses a .bib file (via read()) into the field-dict shape the ACM-Reference-
// Format engine consumes:
//   (<key>: (entry-type: str, fields: (name: value), names: (author: (..), editor: (..))))
// where each parsed name is (first:, von:, last:, jr:).
//
// Handles: @string macros (last definition wins; seeded with the .bst's built-in
// month + journal MACROs), "quoted" and {braced} values with correct brace-depth
// nesting, `#` concatenation, and BibTeX name syntax ("First von Last" /
// "von Last, Jr, First", joined by " and "). Nested braces are KEPT in values
// (TeX-significant: {ACM} casing, \url{...}); the formatter's tx() resolves them.

#import "bib-data.typ": journal-macros

// ACM journal-style month macros (full name if <=5 letters, else abbreviated)
#let months = (
  jan: "Jan.", feb: "Feb.", mar: "March", apr: "April", may: "May", jun: "June",
  jul: "July", aug: "Aug.", sep: "Sept.", oct: "Oct.", nov: "Nov.", dec: "Dec.",
)

#let ws = (" ", "\n", "\t", "\r")

// Index of the "}" matching the "{" at position `i` in codepoint array `cp`.
#let match-brace(cp, i) = {
  let depth = 0
  let j = i
  while j < cp.len() {
    let c = cp.at(j)
    if c == "{" { depth += 1 } else if c == "}" {
      depth -= 1
      if depth == 0 { return j }
    }
    j += 1
  }
  j
}

#let skip-ws(cp, i) = {
  while i < cp.len() and cp.at(i) in ws { i += 1 }
  i
}

// Read a (possibly #-concatenated) value starting at `i`; resolve bare tokens via
// `macros`. Returns (value-string, next-index). Quoted values respect brace depth.
#let read-value(cp, i, macros) = {
  i = skip-ws(cp, i)
  let parts = ()
  let more = true
  while more and i < cp.len() {
    let c = cp.at(i)
    if c == "\"" {
      let j = i + 1
      let depth = 0
      while j < cp.len() and not (cp.at(j) == "\"" and depth == 0) {
        if cp.at(j) == "{" { depth += 1 } else if cp.at(j) == "}" { depth -= 1 }
        j += 1
      }
      parts.push(cp.slice(i + 1, j).join(""))
      i = j + 1
    } else if c == "{" {
      let j = match-brace(cp, i)
      parts.push(cp.slice(i + 1, j).join(""))
      i = j + 1
    } else {
      let j = i
      while j < cp.len() and not (cp.at(j) in (",", "}", "#") or cp.at(j) in ws) { j += 1 }
      let tok = cp.slice(i, j).join("").trim()
      parts.push(macros.at(lower(tok), default: tok))
      i = j
    }
    i = skip-ws(cp, i)
    if i < cp.len() and cp.at(i) == "#" { i = skip-ws(cp, i + 1) } else { more = false }
  }
  // return RAW (no collapse/trim): @string fragments rely on exact inner spaces
  // for `#` concatenation ("Tech " # "Press"); whitespace is normalized per-field.
  let v = parts.join("")
  (if v == none { "" } else { v }, i)
}

#let collapse-ws(s) = s.replace(regex("\s+"), " ").trim()

// ---- name parsing ----
#let split-and(raw) = {
  let cp = raw.codepoints()
  let parts = ()
  let cur = ""
  let depth = 0
  let i = 0
  while i < cp.len() {
    let c = cp.at(i)
    if c == "{" { depth += 1 } else if c == "}" { depth -= 1 }
    if depth == 0 and i + 5 <= cp.len() and cp.slice(i, i + 5).join("") == " and " {
      parts.push(cur); cur = ""; i += 5; continue
    }
    cur += c; i += 1
  }
  parts.push(cur)
  parts
}

#let is-lower-tok(t) = t != "" and lower(t.first()) == t.first() and upper(t.first()) != t.first()

#let parse-one-name(raw) = {
  let r = raw.trim()
  let parts = r.split(",").map(p => p.trim())
  let first = ""; let von = ""; let last = ""; let jr = ""
  if parts.len() == 1 {
    let toks = r.split(regex("\s+")).filter(t => t != "")
    last = toks.at(-1, default: "")
    first = if toks.len() > 1 { toks.slice(0, -1).join(" ") } else { "" }
  } else {
    let vonlast = parts.at(0)
    if parts.len() == 2 { first = parts.at(1) } else { jr = parts.at(1); first = parts.at(2) }
    let toks = vonlast.split(regex("\s+")).filter(t => t != "")
    von = toks.filter(is-lower-tok).join(" ")
    last = toks.filter(t => not is-lower-tok(t)).join(" ")
    if last == "" { last = toks.join(" ") }
  }
  (first: first, von: von, last: last, jr: jr)
}

#let parse-names(raw) = split-and(raw).map(parse-one-name)

// ---- one entry: "@type{key, f = v, ...}" ----
#let parse-entry(block, macros) = {
  let m = block.match(regex("(?s)^@(\w+)\s*\{\s*([^,]+),"))
  if m == none { return none }
  let etype = lower(m.captures.at(0))
  let key = m.captures.at(1).trim()
  let cp = block.slice(m.end).codepoints()
  let fields = (:)
  let i = 0
  while i < cp.len() {
    // next field name (or end of entry)
    let nm = none
    let k = skip-ws(cp, i)
    let s = k
    while s < cp.len() and (cp.at(s).match(regex("[A-Za-z0-9_-]")) != none) { s += 1 }
    if s == k { break }                       // no identifier -> done (trailing })
    let name = lower(cp.slice(k, s).join(""))
    let eq = skip-ws(cp, s)
    if eq >= cp.len() or cp.at(eq) != "=" { break }
    let (val, ni) = read-value(cp, eq + 1, macros)
    fields.insert(name, collapse-ws(val))
    i = skip-ws(cp, ni)
    while i < cp.len() and cp.at(i) == "," { i = skip-ws(cp, i + 1) }
  }
  let names = (:)
  for role in ("author", "editor") {
    if role in fields { names.insert(role, parse-names(fields.at(role))) }
  }
  (key: key, entry: (entry-type: etype, fields: fields, names: names))
}

// span of every top-level @...{...} block
#let scan-blocks(cp) = {
  let out = ()
  let i = 0
  while i < cp.len() {
    if cp.at(i) != "@" { i += 1; continue }
    let b = i
    while b < cp.len() and cp.at(b) != "{" { b += 1 }
    if b >= cp.len() { break }
    let e = match-brace(cp, b)
    out.push((start: i, brace: b, end: e))
    i = e + 1
  }
  out
}

#let parse-bib(text) = {
  let cp = text.codepoints()
  let blocks = scan-blocks(cp)
  // pass 1: macro table — built-ins first, then @string (later defs win)
  let macros = (:)
  for (k, v) in journal-macros { macros.insert(lower(k), v) }
  for (k, v) in months { macros.insert(k, v) }
  for blk in blocks {
    let head = lower(cp.slice(blk.start, calc.min(blk.start + 8, cp.len())).join(""))
    if head.starts-with("@string") {
      let inner = cp.slice(blk.brace + 1, blk.end)
      let k = skip-ws(inner, 0)
      let s = k
      while s < inner.len() and (inner.at(s).match(regex("\w")) != none) { s += 1 }
      if s > k {
        let name = lower(inner.slice(k, s).join(""))
        let eq = skip-ws(inner, s)
        if eq < inner.len() and inner.at(eq) == "=" {
          let (val, _) = read-value(inner, eq + 1, macros)
          macros.insert(name, val)
        }
      }
    }
  }
  // pass 2: entries
  let db = (:)
  for blk in blocks {
    let head = lower(cp.slice(blk.start, calc.min(blk.start + 9, cp.len())).join(""))
    if head.starts-with("@string") or head.starts-with("@preamble") or head.starts-with("@comment") { continue }
    let block = cp.slice(blk.start, blk.end + 1).join("")
    let r = parse-entry(block, macros)
    if r != none { db.insert(r.key, r.entry) }
  }
  db
}

#let read-bib(path) = parse-bib(read(path))
