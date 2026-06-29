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

// TeX accent command -> combining diacritic on the following letter (NFC composes
// downstream; the text gate NFKC-folds). Symbol-named (\"o) and letter-named
// (\H{o}, \v s) accents; letter-named ones need a brace/space argument.
#let symbol-accent = (
  "\"": "\u{0308}", "'": "\u{0301}", "`": "\u{0300}", "^": "\u{0302}",
  "~": "\u{0303}", "=": "\u{0304}", ".": "\u{0307}",
)
#let letter-accent = (
  "H": "\u{030B}", "v": "\u{030C}", "u": "\u{0306}", "r": "\u{030A}",
  "k": "\u{0328}", "c": "\u{0327}", "b": "\u{0331}", "d": "\u{0323}",
)
#let special-letters = (
  "ss": "ß", "SS": "ẞ", "ae": "æ", "AE": "Æ", "oe": "œ", "OE": "Œ",
  "aa": "å", "AA": "Å", "o": "ø", "O": "Ø", "l": "ł", "L": "Ł", "i": "ı", "j": "ȷ",
)

// ---- inline math ($...$) ----
// A curated map of the math commands that turn up in real reference titles
// (\lambda-calculus, \chi^2, \Theta(n)...). We map to the *base* Unicode letter,
// not the math-italic plane that LaTeX renders — both fold to the same thing under
// the text gate's NFKC, and base letters are what a Typst reader expects to copy.
// Arbitrary math (full equations, custom macros) is out of scope; unknown commands
// pass through verbatim, and the user can override/extend this via `tex-macros`.
#let math-symbols = (
  // lowercase greek
  alpha: "α", beta: "β", gamma: "γ", delta: "δ", epsilon: "ε", varepsilon: "ε",
  zeta: "ζ", eta: "η", theta: "θ", vartheta: "ϑ", iota: "ι", kappa: "κ",
  lambda: "λ", mu: "μ", nu: "ν", xi: "ξ", omicron: "ο", pi: "π", varpi: "ϖ",
  rho: "ρ", varrho: "ϱ", sigma: "σ", varsigma: "ς", tau: "τ", upsilon: "υ",
  phi: "φ", varphi: "ϕ", chi: "χ", psi: "ψ", omega: "ω",
  // uppercase greek
  Gamma: "Γ", Delta: "Δ", Theta: "Θ", Lambda: "Λ", Xi: "Ξ", Pi: "Π", Sigma: "Σ",
  Upsilon: "Υ", Phi: "Φ", Psi: "Ψ", Omega: "Ω",
  // relations / operators / symbols
  times: "×", cdot: "·", div: "÷", pm: "±", mp: "∓", ast: "∗", star: "⋆",
  leq: "≤", le: "≤", geq: "≥", ge: "≥", neq: "≠", ne: "≠", approx: "≈",
  equiv: "≡", sim: "∼", simeq: "≃", cong: "≅", propto: "∝", ll: "≪", gg: "≫",
  to: "→", rightarrow: "→", Rightarrow: "⇒", leftarrow: "←", Leftarrow: "⇐",
  leftrightarrow: "↔", mapsto: "↦", infty: "∞", partial: "∂", nabla: "∇",
  forall: "∀", exists: "∃", neg: "¬", "in": "∈", notin: "∉", ni: "∋",
  subset: "⊂", subseteq: "⊆", supset: "⊃", supseteq: "⊇", cup: "∪", cap: "∩",
  setminus: "∖", emptyset: "∅", varnothing: "∅", wedge: "∧", land: "∧",
  vee: "∨", lor: "∨", oplus: "⊕", otimes: "⊗", circ: "∘", bullet: "•",
  sum: "∑", prod: "∏", int: "∫", sqrt: "√", angle: "∠", perp: "⊥",
  parallel: "∥", ell: "ℓ", hbar: "ℏ", Re: "ℜ", Im: "ℑ", aleph: "ℵ",
  ldots: "…", cdots: "⋯", dots: "…", dag: "†", ddag: "‡", prime: "′",
  // text operators (render upright, as their own name)
  log: "log", ln: "ln", exp: "exp", sin: "sin", cos: "cos", tan: "tan",
  cot: "cot", sec: "sec", csc: "csc", lim: "lim", limsup: "lim sup",
  liminf: "lim inf", max: "max", min: "min", sup: "sup", inf: "inf",
  det: "det", dim: "dim", deg: "deg", gcd: "gcd", arg: "arg", ker: "ker", bmod: "mod",
)
// font/grouping commands whose single argument is kept (\mathbb{R} -> R, NFKC of
// LaTeX's blackboard R; \text{...} likewise)
#let math-arg-commands = ("mathbb", "mathcal", "mathbf", "mathrm", "mathit",
  "mathsf", "mathtt", "mathfrak", "boldsymbol", "text", "textrm", "mathnormal", "operatorname")
// digits/letters with Unicode super-/sub-script forms (NFKC-fold to the base char)
#let superscripts = (
  "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶",
  "7": "⁷", "8": "⁸", "9": "⁹", "n": "ⁿ", "i": "ⁱ", "+": "⁺", "-": "⁻",
)
#let subscripts = (
  "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄", "5": "₅", "6": "₆",
  "7": "₇", "8": "₈", "9": "₉", "+": "₊", "-": "₋",
)
#let is-letter(c) = c != "" and lower(c) != upper(c)

// Read an accent's argument starting at i: skip spaces, then a {group} or one char.
// Returns (decoded-argument, next-index).
#let read-accent-arg(cp, i) = {
  i = skip-ws(cp, i)
  if i >= cp.len() { return ("", i) }
  if cp.at(i) == "{" {
    let j = match-brace(cp, i)
    (cp.slice(i + 1, j).join(""), j + 1)   // inner is a single letter (or \i)
  } else {
    (cp.at(i), i + 1)
  }
}

// Decode the inside of an inline-math `$...$` span. `mm` is the merged symbol map
// (built-in math-symbols overlaid with the user's tex-macros). Greek/symbol macros
// -> Unicode; ^x / _x -> Unicode super-/subscripts; \mathbb{R} & friends keep their
// argument; grouping braces and spacing macros drop; unknown macros pass verbatim.
#let decode-math(inner, mm) = {
  let cp = inner.codepoints()
  let n = cp.len()
  let out = ""
  let i = 0
  while i < n {
    let c = cp.at(i)
    if c == "\\" {
      i += 1
      if i >= n { break }
      let d = cp.at(i)
      if is-letter(d) {
        let j = i
        while j < n and is-letter(cp.at(j)) { j += 1 }
        let name = cp.slice(i, j).join("")
        i = j
        if name in mm { out += mm.at(name) }
        else if name in math-arg-commands {
          let (arg, ni) = read-accent-arg(cp, i)
          out += decode-math(arg, mm); i = ni
        } else if name in special-letters { out += special-letters.at(name) }
        else { out += "\\" + name }              // unknown: leave verbatim
      } else {
        if d in ("{", "}", "%", "&", "#", "_", "$") { out += d }  // escaped char
        i += 1                                   // \, \; \! spacing -> drop
      }
    } else if c == "^" or c == "_" {
      let tbl = if c == "^" { superscripts } else { subscripts }
      let (arg, ni) = read-accent-arg(cp, i + 1); i = ni
      for ch in arg.codepoints() { out += tbl.at(ch, default: ch) }
    } else if c == "{" or c == "}" { i += 1 }    // drop grouping
    else { out += c; i += 1 }
  }
  out
}

// Single-pass TeX decoder: on `\`, read the FULL command name and look it up, so
// `\u{a}` (breve) and `\url` (command "url") never collide. Decodes accents and
// special letters; resolves inline math (`$...$`) and any user `tex-macros` (`umac`,
// keyed by bare command name); unknown commands (\url, \emph, \&, …) pass through
// intact for the formatter. Runs in the parser, before name tokenizing, so
// "Stra\ss e" becomes one token "Straße" rather than splitting at the macro.
#let decode-tex(s, umac: (:)) = {
  if not (s.contains("\\") or s.contains("$")) { return s }
  let cp = s.codepoints()
  let n = cp.len()
  let out = ""
  let i = 0
  while i < n {
    let c = cp.at(i)
    if c == "$" {                                // inline math span
      let j = i + 1
      while j < n and cp.at(j) != "$" { j += 1 }
      out += decode-math(cp.slice(i + 1, j).join(""), math-symbols + umac)
      i = if j < n { j + 1 } else { j }
      continue
    }
    if c != "\\" { out += c; i += 1; continue }
    i += 1
    if i >= n { out += "\\"; break }
    let d = cp.at(i)
    if is-letter(d) {
      let j = i
      while j < n and is-letter(cp.at(j)) { j += 1 }
      let name = cp.slice(i, j).join("")
      i = j
      if name in special-letters {
        out += special-letters.at(name)
        if i + 1 < n and cp.at(i) == "{" and cp.at(i + 1) == "}" { i += 2 }
      } else if name in letter-accent {
        let (arg, ni) = read-accent-arg(cp, i)
        out += decode-tex(arg, umac: umac) + letter-accent.at(name)
        i = ni
      } else if name in umac {
        out += umac.at(name)      // user-supplied replacement for an unknown command
      } else {
        out += "\\" + name        // unknown control word: leave for the formatter
      }
    } else if d in symbol-accent {
      let (arg, ni) = read-accent-arg(cp, i + 1)
      out += decode-tex(arg, umac: umac) + symbol-accent.at(d)
      i = ni
    } else {
      out += "\\" + d             // \& \, \% … : leave for the formatter
      i += 1
    }
  }
  out
}

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
  let parts = raw.trim().split(",").map(p => p.trim())
  let toks = parts.at(0).split(regex("\s+")).filter(t => t != "")
  if parts.len() == 1 {
    if toks.len() == 0 { return (first: "", von: "", last: "", jr: "") }
    let (first, von, last) = split-first-von-last(toks)
    (first: first, von: von, last: last, jr: "")
  } else {
    let (von, last) = split-von-last(toks)
    let jr = if parts.len() > 2 { parts.at(1) } else { "" }
    let first = if parts.len() > 2 { parts.at(2) } else { parts.at(1) }
    (first: first, von: von, last: last, jr: jr)
  }
}

#let parse-names(raw) = split-and(raw).map(parse-one-name)

// ---- one entry: "@type{key, f = v, ...}" ----
#let parse-entry(block, macros, umac) = {
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
    fields.insert(name, decode-tex(collapse-ws(val), umac: umac))
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

#let parse-bib(text, umac: (:)) = {
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
    let r = parse-entry(block, macros, umac)
    if r != none { db.insert(r.key, r.entry) }
  }
  db
}

// `tex-macros`: user overrides/extensions for TeX command decoding, keyed by bare
// command name (a leading backslash is tolerated and stripped). Applied in both
// text and inline math; overrides the built-in tables.
#let read-bib(path, tex-macros: (:)) = {
  let umac = (:)
  for (k, v) in tex-macros { umac.insert(if k.starts-with("\\") { k.slice(1) } else { k }, v) }
  parse-bib(read(path), umac: umac)
}
