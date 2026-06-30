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
#import "tex.typ": decode

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
    if c == "\\" { j += 2; continue }    // escaped char: \{ and \} are literal
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

// Like skip-ws, but also swallows `%...\n` line comments between fields (biblatex
// supports them; bibtex doesn't treat `%` specially, so silently dropping the rest
// of an entry — the old behaviour — was the worst of both). Only runs in the
// field-structure scan, never inside a braced/quoted value, so a literal `%` in a
// value is preserved.
#let skip-ws-comment(cp, i) = {
  i = skip-ws(cp, i)
  while i < cp.len() and cp.at(i) == "%" {
    while i < cp.len() and cp.at(i) != "\n" { i += 1 }
    i = skip-ws(cp, i)
  }
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
        if cp.at(j) == "\\" { j += 2; continue }   // escaped char (\" \{ \})
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
// Split a name list on the keyword "and" that sits at brace depth 0 and is
// bounded by whitespace on BOTH sides (any whitespace, incl. newlines — real
// .bib files put "and" on its own line). A leading/trailing "and" is not a
// separator (it has no whitespace on the outer side); two consecutive "and"s
// yield an empty name in between. Matches biblatex's split_token_lists_with_kw.
#let split-and(raw) = {
  let cp = raw.codepoints()
  let n = cp.len()
  let parts = ()
  let cur = ""
  let depth = 0
  let i = 0
  while i < n {
    let c = cp.at(i)
    if c == "{" { depth += 1 } else if c == "}" { depth -= 1 }
    if (depth == 0 and c == "a" and i > 0 and i + 3 < n
        and cp.at(i + 1) == "n" and cp.at(i + 2) == "d"
        and cp.at(i - 1) in ws and cp.at(i + 3) in ws) {
      parts.push(cur); cur = ""; i += 3; continue
    }
    cur += c; i += 1
  }
  parts.push(cur)
  parts
}

// Split `s` at every char in `seps` that sits at brace depth 0; brace groups are
// kept intact, so "{de la}" stays one token and "{Robert and Sons, Inc.}" keeps
// its comma. Matches biblatex's split_at_normal_char (commas/spaces inside braces
// are verbatim, not structural).
#let split-top(s, seps) = {
  let parts = ()
  let cur = ""
  let depth = 0
  for c in s.codepoints() {
    if c == "{" { depth += 1; cur += c }
    else if c == "}" { depth -= 1; cur += c }
    else if depth == 0 and c in seps { parts.push(cur); cur = "" }
    else { cur += c }
  }
  parts.push(cur)
  parts
}

#let is-lower-tok(t) = t != "" and lower(t.first()) == t.first() and upper(t.first()) != t.first()

// indices of the first / last lowercase-initial token (none if all uppercase),
// matching biblatex (brace-verbatim tokens count as uppercase, via is-lower-tok).
#let lower-bounds(toks) = {
  let first = none
  let last = none
  for (i, t) in toks.enumerate() {
    if is-lower-tok(t) { if first == none { first = i }; last = i }
  }
  (first, last)
}

// "von Last" (the part before the first comma). Per biblatex Person::parse:
// von = up to AND INCLUDING the last lowercase word (when any uppercase word
// exists), else all but the final word; last = the remainder.
#let split-von-last(toks) = {
  if toks.len() == 0 { return ("", "") }
  let (_, lastlc) = lower-bounds(toks)
  if toks.any(t => not is-lower-tok(t)) {
    if lastlc == none { ("", toks.join(" ")) }
    else { (toks.slice(0, lastlc + 1).join(" "), toks.slice(lastlc + 1).join(" ")) }
  } else {
    (toks.slice(0, -1).join(" "), toks.at(-1))
  }
}

// "First von Last" (no comma). first = leading uppercase run; von = first..last
// lowercase word; last = the trailing uppercase run (or the final word if none).
#let split-first-von-last(toks) = {
  let (firstlc, lastlc) = lower-bounds(toks)
  if firstlc == none {
    (toks.slice(0, -1).join(" "), "", toks.at(-1, default: ""))
  } else {
    let first = toks.slice(0, firstlc).join(" ")
    if lastlc + 1 >= toks.len() {  // trailing lowercase: take the final word as Last
      (first, toks.slice(firstlc, toks.len() - 1).join(" "), toks.at(-1))
    } else {
      (first, toks.slice(firstlc, lastlc + 1).join(" "), toks.slice(lastlc + 1).join(" "))
    }
  }
}

#let parse-one-name(raw) = {
  let parts = split-top(raw.trim(), (",",)).map(p => p.trim())
  let toks = split-top(parts.at(0), ws).filter(t => t != "")
  let r = if parts.len() == 1 {
    if toks.len() == 0 { (first: "", von: "", last: "", jr: "") }
    else {
      let (first, von, last) = split-first-von-last(toks)
      (first: first, von: von, last: last, jr: "")
    }
  } else {
    let (von, last) = split-von-last(toks)
    let jr = if parts.len() > 2 { parts.at(1) } else { "" }
    let first = if parts.len() > 2 { parts.at(2) } else { parts.at(1) }
    (first: first, von: von, last: last, jr: jr)
  }
  // `().join(" ")` is `none` in Typst, so an empty part can come back as none;
  // coerce to "" so every part is a string (matches the reference; avoids a
  // downstream `string + none` in the sort key for all-lowercase names).
  r.pairs().map(((k, v)) => (k, if v == none { "" } else { v })).to-dict()
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
    let k = skip-ws-comment(cp, i)
    let s = k
    while s < cp.len() and (cp.at(s).match(regex("[A-Za-z0-9_-]")) != none) { s += 1 }
    if s == k { break }                       // no identifier -> done (trailing })
    let name = lower(cp.slice(k, s).join(""))
    let eq = skip-ws(cp, s)
    if eq >= cp.len() or cp.at(eq) != "=" { break }
    let (val, ni) = read-value(cp, eq + 1, macros)
    // store the RAW TeX value (collapse whitespace only); decoding to Unicode and
    // rendering to content happen later, in tex.typ, so the raw TeX survives the
    // pipeline (BibTeX-style). Names are still decoded for tokenization here —
    // decode() leaves the " and " separators and word boundaries intact, so this
    // reproduces the previous split exactly; Stage C will tokenize raw instead.
    fields.insert(name, collapse-ws(val))
    i = skip-ws-comment(cp, ni)
    while i < cp.len() and cp.at(i) == "," { i = skip-ws-comment(cp, i + 1) }
  }
  let names = (:)
  for role in ("author", "editor") {
    if role in fields { names.insert(role, parse-names(decode(fields.at(role)))) }
  }
  (key: key, entry: (entry-type: etype, fields: fields, names: names))
}

// span of every top-level @...{...} block
#let scan-blocks(cp) = {
  let out = ()
  let i = 0
  while i < cp.len() {
    if cp.at(i) == "%" {            // top-level line comment: skip to EOL
      while i < cp.len() and cp.at(i) != "\n" { i += 1 }
      continue
    }
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
    let block = cp.slice(blk.start, calc.min(blk.end + 1, cp.len())).join("")
    let r = parse-entry(block, macros)
    if r != none { db.insert(r.key, r.entry) }
  }
  db
}

#let read-bib(path) = parse-bib(read(path))
