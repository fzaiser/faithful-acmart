// Pure-Typst BibTeX reader for the "bst" bibliography backend.
//
// Parses a .bib file (via read()) into the field-dict shape the ACM-Reference-
// Format engine consumes:
//   (<key>: (entry-type: str, fields: (name: value), names: (author: (..), editor: (..))))
// where each parsed name is (first:, von:, last:, jr:).
//
// Scope: the constructs the bundled ACM sample bibs use — @string macros (last
// definition wins), "quoted"/{braced} values, `#` concatenation, standard month
// macros, and BibTeX name syntax ("First von Last" / "von Last, Jr, First",
// names joined by " and "). TeX-accent decoding is left to the formatter's tx().
// This is the swappable front-end; the engine only sees the dict above.

// ACM journal-style month macros (full name if <=5 letters, else abbreviated)
#let months = (
  jan: "Jan.", feb: "Feb.", mar: "March", apr: "April", may: "May", jun: "June",
  jul: "July", aug: "Aug.", sep: "Sept.", oct: "Oct.", nov: "Nov.", dec: "Dec.",
)

#let strip-braces(s) = s.replace("{", "").replace("}", "")

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

// ---- @string macros (name -> expansion), last definition wins ----
#let read-strings(text) = {
  let macros = (:)
  for m in text.matches(regex("(?is)@string\s*\{\s*(\w+)\s*=\s*\"([^\"]*)\"\s*\}")) {
    macros.insert(lower(m.captures.at(0)), m.captures.at(1))
  }
  macros
}

// ---- name parsing ----
#let split-and(raw) = {
  // split on " and " at brace depth 0
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
    von = toks.filter(t => lower(t.first()) == t.first() and upper(t.first()) != t.first()).join(" ")
    last = toks.filter(t => not (lower(t.first()) == t.first() and upper(t.first()) != t.first())).join(" ")
    if last == "" { last = toks.join(" ") }
  }
  (first: first, von: von, last: last, jr: jr)
}

#let parse-names(raw) = split-and(raw).map(parse-one-name)

// ---- one entry: "@type{key, f = v, ...}" (block excludes outer braces handled by caller) ----
#let parse-entry(block, macros) = {
  let m = block.match(regex("(?s)^@(\w+)\s*\{\s*([^,]+),"))
  if m == none { return none }
  let etype = lower(m.captures.at(0))
  let key = m.captures.at(1).trim()
  let body = block.slice(m.end)
  let cp = body.codepoints()
  let fields = (:)
  // scan "name = value" pairs
  let i = 0
  while i < cp.len() {
    // find next field name
    let rest = cp.slice(i).join("")
    let fm = rest.match(regex("(?s)^\s*(\w+)\s*=\s*"))
    if fm == none { break }
    let name = lower(fm.captures.at(0))
    i += fm.end
    if i >= cp.len() { break }
    // read (possibly concatenated) value
    let parts = ()
    let more = true
    while more {
      let c = cp.at(i)
      if c == "\"" {
        let j = i + 1
        while j < cp.len() and cp.at(j) != "\"" { j += 1 }
        parts.push(cp.slice(i + 1, j).join(""))
        i = j + 1
      } else if c == "{" {
        let j = match-brace(cp, i)
        parts.push(cp.slice(i + 1, j).join(""))
        i = j + 1
      } else {
        // bare token: macro name or number, up to , } # or whitespace
        let j = i
        while j < cp.len() and not (cp.at(j) in (",", "}", "#") or cp.at(j) == " " or cp.at(j) == "\n" or cp.at(j) == "\t" or cp.at(j) == "\r") { j += 1 }
        let tok = cp.slice(i, j).join("").trim()
        let lt = lower(tok)
        parts.push(macros.at(lt, default: months.at(lt, default: tok)))
        i = j
      }
      // skip whitespace; check for concatenation
      while i < cp.len() and cp.at(i) in (" ", "\n", "\t", "\r") { i += 1 }
      if i < cp.len() and cp.at(i) == "#" {
        i += 1
        while i < cp.len() and cp.at(i) in (" ", "\n", "\t", "\r") { i += 1 }
      } else { more = false }
    }
    // keep nested braces (TeX-significant; tx() resolves them); collapse whitespace
    let val = parts.join("")
    if val == none { val = "" }
    fields.insert(name, val.replace(regex("\s+"), " ").trim())
    // advance past trailing comma
    while i < cp.len() and cp.at(i) in (",", " ", "\n", "\t", "\r") { i += 1 }
  }
  let names = (:)
  for role in ("author", "editor") {
    if role in fields { names.insert(role, parse-names(fields.at(role))) }
  }
  (key: key, entry: (entry-type: etype, fields: fields, names: names))
}

// ---- top-level: split into entries, skip @string/@preamble/@comment ----
#let parse-bib(text) = {
  let macros = read-strings(text)
  let cp = text.codepoints()
  let db = (:)
  let i = 0
  while i < cp.len() {
    if cp.at(i) != "@" { i += 1; continue }
    // brace-match the entry
    let b = i
    while b < cp.len() and cp.at(b) != "{" { b += 1 }
    if b >= cp.len() { break }
    let e = match-brace(cp, b)
    let block = cp.slice(i, e + 1).join("")
    let head = lower(block.slice(0, calc.min(block.len(), 9)))
    if not (head.starts-with("@string") or head.starts-with("@preamble") or head.starts-with("@comment")) {
      let r = parse-entry(block, macros)
      if r != none { db.insert(r.key, r.entry) }
    }
    i = e + 1
  }
  db
}

#let read-bib(path) = parse-bib(read(path))
