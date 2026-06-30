// TeX-string semantics for the "bst" bibliography backend.
//
// This module is the single home for *TeX text handling*, split by purpose from
// the .bib parser (bibtex.typ) and the .bst formatter (acmref.typ):
//
//   * the LOGIC layer — `purify` and `change-case`, exact ports of BibTeX's
//     `purify$` and `change.case$` built-ins (string -> string, math-blind,
//     brace/special-character aware). BibTeX carries the RAW TeX string through
//     its whole pipeline and only ever applies these two transforms for sort
//     keys and display case; we follow it literally. Verified against the real
//     bibtex binary (see tests/unit/tex.typ), which is a closed, finite spec.
//
//   * the PRESENTATION layer — `tex-to-string` / `tex-to-content`, the default
//     "render this raw TeX as visible text/content" pass (accents + special
//     letters + inline math -> Unicode, ligatures/dashes/quotes, \url/\href ->
//     real links). `tex-to-content` is what the acmart() `tex-render` option
//     overrides; the logic layer is never user-overridable (it would corrupt
//     sorting). [see decode/render section below]
//
// The 13-entry foreign-character table and the brace/special-character rules
// below are quoted from bibtex.web (`x_purify`, `x_change_case`, and the
// `pre_define(... control_seq_ilk)` block) — not guessed.

// ---- character classes (bibtex lex_class) ---------------------------------
// ASCII letters/digits are alpha/numeric; space & tab are white_space; tilde
// (tie) and hyphen are sep_char; everything else (incl. `$ ^ _ { } \`) is other.
#let _lex(c) = {
  if c == " " or c == "\t" or c == "\n" or c == "\r" { "ws" }
  else if c == "~" or c == "-" { "sep" }
  else if c >= "0" and c <= "9" { "num" }
  else if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") { "alpha" }
  else { "other" }
}

// ---- the 13 predefined foreign-character control sequences -----------------
// bibtex.web pre_define(... control_seq_ilk): the ONLY control sequences BibTeX
// recognizes as foreign letters. `purify$` maps each to the first alphabetic
// char of its name, plus the second only for \oe \OE \ae \AE \ss (hence \aa->a
// but \ss->ss). Anything else inside a special character is dropped.
#let _foreign-purify = (
  i: "i", j: "j", o: "o", O: "O", l: "l", L: "L",
  oe: "oe", OE: "OE", ae: "ae", AE: "AE", aa: "a", AA: "A", ss: "ss",
)
// change.case$ flips only the recognized foreign LETTER commands in place
// (backslash + name kept): lowering touches the upper ones, uppercasing the
// lower ones; \i \j \ss are never case-flipped.
#let _foreign-lower = (L: "l", O: "o", OE: "oe", AE: "ae", AA: "aa")
#let _foreign-upper = (l: "L", o: "O", oe: "OE", ae: "AE", aa: "AA")

// ---- purify$ ---------------------------------------------------------------
// `@<Purify a special character@>`: inside `{\...}`, emit the table value for a
// recognized control sequence (nothing for an unknown one), then the trailing
// alphanumerics; whitespace inside a special character is dropped (not spaced).
// `cp` is the codepoint array, `p` sits on the opening brace. Returns the
// appended text and the index of the closing brace (caller advances past it).
#let _purify-special(cp, n, p) = {
  let out = ""
  let bl = 1
  p += 1                                   // skip "{"
  while p < n and bl > 0 {
    p += 1                                 // skip "\"
    let y = p
    while p < n and _lex(cp.at(p)) == "alpha" { p += 1 }
    let cs = cp.slice(y, p).join("")
    if cs in _foreign-purify { out += _foreign-purify.at(cs) }
    while p < n and bl > 0 and cp.at(p) != "\\" {
      let cc = cp.at(p)
      let l = _lex(cc)
      if l == "alpha" or l == "num" { out += cc }
      else if cc == "}" { bl -= 1 } else if cc == "{" { bl += 1 }
      p += 1
    }
  }
  (out, p - 1)                             // decr: leave p on the closing brace
}

// `@<Perform the purification@>`: keep letters/digits; turn each white_space or
// sep_char (`~`,`-`) into a single space; drop everything else (so `$ ^ _` and a
// bare backslash vanish, but a bare `\cmd`'s letters survive as plain text);
// `{` at level 1 followed by `\` enters the special-character branch.
#let purify(s) = {
  let cp = s.codepoints()
  let n = cp.len()
  let out = ""
  let bl = 0
  let p = 0
  while p < n {
    let c = cp.at(p)
    let l = _lex(c)
    if l == "ws" or l == "sep" { out += " " }
    else if l == "alpha" or l == "num" { out += c }
    else if c == "{" {
      bl += 1
      if bl == 1 and p + 1 < n and cp.at(p + 1) == "\\" {
        let (so, sp) = _purify-special(cp, n, p)
        out += so
        p = sp
        bl = 0
      }
    } else if c == "}" { if bl > 0 { bl -= 1 } }
    p += 1
  }
  out
}

// ---- change.case$ ----------------------------------------------------------
#let _conv-str(s, ct) = if ct == "u" { upper(s) } else { lower(s) }

// `@<Convert a special character@>`: keep the braces and backslash; case-flip a
// recognized foreign letter command in place; convert the trailing noncontrol
// sequence with lower/upper. `p` sits on the opening brace; returns the
// converted text and the index of the closing brace.
#let _change-special(cp, n, p, ct) = {
  let out = "{"
  let bl = 1
  p += 1                                   // skip "{"
  while p < n and bl > 0 {
    p += 1                                 // skip "\"
    let x = p
    while p < n and _lex(cp.at(p)) == "alpha" { p += 1 }
    let cs = cp.slice(x, p).join("")
    out += "\\"
    if (ct == "t" or ct == "l") and cs in _foreign-lower { out += _foreign-lower.at(cs) }
    else if ct == "u" and cs in _foreign-upper { out += _foreign-upper.at(cs) }
    else { out += cs }
    let x2 = p
    while p < n and bl > 0 and cp.at(p) != "\\" {
      let cc = cp.at(p)
      if cc == "}" { bl -= 1 } else if cc == "{" { bl += 1 }
      p += 1
    }
    out += _conv-str(cp.slice(x2, p).join(""), ct)
  }
  (out, p - 1)
}

// `@<Perform the case conversion@>` + `@<Convert a brace_level = 0 character@>`.
// `ct` is "t" (title: lower all but the first char and the first after ": "),
// "l" (all lower) or "u" (all upper). Only brace-level-0 chars are converted, so
// `{ACM}` is protected; a `{\foreign}` at level 1 is case-flipped in place.
#let change-case(s, ct) = {
  let cp = s.codepoints()
  let n = cp.len()
  let out = ""
  let bl = 0
  let prev-colon = false
  let p = 0
  while p < n {
    let c = cp.at(p)
    if c == "{" {
      bl += 1
      let give-up = bl != 1 or p + 4 > n or cp.at(p + 1) != "\\"
      if ct == "t" and not give-up {
        if p == 0 { give-up = true }
        else if prev-colon and _lex(cp.at(p - 1)) == "ws" { give-up = true }
      }
      if not give-up {
        let (so, sp) = _change-special(cp, n, p, ct)
        out += so
        p = sp
        bl = 0
      } else { out += "{" }
      prev-colon = false
    } else if c == "}" {
      if bl > 0 { bl -= 1 }
      out += "}"
      prev-colon = false
    } else if bl == 0 {
      if ct == "t" {
        if p == 0 or (prev-colon and _lex(cp.at(p - 1)) == "ws") { out += c }
        else { out += lower(c) }
        if c == ":" { prev-colon = true }
        else if _lex(c) != "ws" { prev-colon = false }
      } else { out += _conv-str(c, ct) }
    } else { out += c }
    p += 1
  }
  out
}

// ===========================================================================
// PRESENTATION layer: render raw TeX as visible text / content.
// ===========================================================================
// BibTeX never decodes to Unicode — TeX does, at typeset time. We replicate
// "what TeX renders" here, as the single string->content boundary. Field values
// flow through the pipeline as RAW TeX and only become Unicode/content in this
// pass. `tex-to-content` is what the acmart() `tex-render` option overrides;
// `tex-to-string` (the text-only backbone, used for sort/cite labels) is not.

#let _ws = (" ", "\n", "\t", "\r")
#let _skip-ws(cp, i) = { while i < cp.len() and cp.at(i) in _ws { i += 1 }; i }
// index of the "}" matching the "{" at i (escaped \{ \} skipped)
#let _match-brace(cp, i) = {
  let depth = 0
  let j = i
  while j < cp.len() {
    let c = cp.at(j)
    if c == "\\" { j += 2; continue }
    if c == "{" { depth += 1 } else if c == "}" { depth -= 1; if depth == 0 { return j } }
    j += 1
  }
  j
}
#let _is-letter(c) = c != "" and lower(c) != upper(c)

// TeX accent commands -> combining diacritic on the following letter (NFC
// composes downstream; the text gate NFKC-folds).
#let _symbol-accent = (
  "\"": "\u{0308}", "'": "\u{0301}", "`": "\u{0300}", "^": "\u{0302}",
  "~": "\u{0303}", "=": "\u{0304}", ".": "\u{0307}",
)
#let _letter-accent = (
  "H": "\u{030B}", "v": "\u{030C}", "u": "\u{0306}", "r": "\u{030A}",
  "k": "\u{0328}", "c": "\u{0327}", "b": "\u{0331}", "d": "\u{0323}",
)
#let _special-letters = (
  "ss": "ß", "SS": "ẞ", "ae": "æ", "AE": "Æ", "oe": "œ", "OE": "Œ",
  "aa": "å", "AA": "Å", "o": "ø", "O": "Ø", "l": "ł", "L": "Ł", "i": "ı", "j": "ȷ",
)

// ---- inline math ($...$) ---------------------------------------------------
// Curated map of the math commands that turn up in real reference titles
// (\lambda-calculus, \chi^2, \Theta(n)...), to the BASE Unicode letter, not the
// math-italic plane LaTeX renders — both fold the same under the text gate's
// NFKC, and base letters are what a reader expects to copy. Unknown commands
// pass through verbatim; richer math is the `tex-render` override's job.
#let _math-symbols = (
  alpha: "α", beta: "β", gamma: "γ", delta: "δ", epsilon: "ε", varepsilon: "ε",
  zeta: "ζ", eta: "η", theta: "θ", vartheta: "ϑ", iota: "ι", kappa: "κ",
  lambda: "λ", mu: "μ", nu: "ν", xi: "ξ", omicron: "ο", pi: "π", varpi: "ϖ",
  rho: "ρ", varrho: "ϱ", sigma: "σ", varsigma: "ς", tau: "τ", upsilon: "υ",
  phi: "φ", varphi: "ϕ", chi: "χ", psi: "ψ", omega: "ω",
  Gamma: "Γ", Delta: "Δ", Theta: "Θ", Lambda: "Λ", Xi: "Ξ", Pi: "Π", Sigma: "Σ",
  Upsilon: "Υ", Phi: "Φ", Psi: "Ψ", Omega: "Ω",
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
  log: "log", ln: "ln", exp: "exp", sin: "sin", cos: "cos", tan: "tan",
  cot: "cot", sec: "sec", csc: "csc", lim: "lim", limsup: "lim sup",
  liminf: "lim inf", max: "max", min: "min", sup: "sup", inf: "inf",
  det: "det", dim: "dim", deg: "deg", gcd: "gcd", arg: "arg", ker: "ker", bmod: "mod",
)
#let _math-arg-commands = ("mathbb", "mathcal", "mathbf", "mathrm", "mathit",
  "mathsf", "mathtt", "mathfrak", "boldsymbol", "text", "textrm", "mathnormal", "operatorname")
#let _superscripts = (
  "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶",
  "7": "⁷", "8": "⁸", "9": "⁹", "n": "ⁿ", "i": "ⁱ", "+": "⁺", "-": "⁻",
)
#let _subscripts = (
  "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄", "5": "₅", "6": "₆",
  "7": "₇", "8": "₈", "9": "₉", "+": "₊", "-": "₋",
)

// Read an accent's argument at i: skip spaces, then a {group} or one char.
#let _read-arg(cp, i) = {
  i = _skip-ws(cp, i)
  if i >= cp.len() { return ("", i) }
  if cp.at(i) == "{" { let j = _match-brace(cp, i); (cp.slice(i + 1, j).join(""), j + 1) }
  else { (cp.at(i), i + 1) }
}

// Decode the inside of an inline-math `$...$` span -> base Unicode.
#let _decode-math(inner) = {
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
      if _is-letter(d) {
        let j = i
        while j < n and _is-letter(cp.at(j)) { j += 1 }
        let name = cp.slice(i, j).join(""); i = j
        if name in _math-symbols { out += _math-symbols.at(name) }
        else if name in _math-arg-commands { let (a, ni) = _read-arg(cp, i); out += _decode-math(a); i = ni }
        else if name in _special-letters { out += _special-letters.at(name) }
        else { out += "\\" + name }
      } else {
        if d in ("{", "}", "%", "&", "#", "_", "$") { out += d }
        i += 1
      }
    } else if c == "^" or c == "_" {
      let tbl = if c == "^" { _superscripts } else { _subscripts }
      let (a, ni) = _read-arg(cp, i + 1); i = ni
      for ch in a.codepoints() { out += tbl.at(ch, default: ch) }
    } else if c == "{" or c == "}" { i += 1 }
    else { out += c; i += 1 }
  }
  out
}

// Single-pass TeX decoder: accents (\"o), special letters (\ss), inline math
// ($...$) -> Unicode. Reads the FULL command name so `\u{a}` (breve) and `\url`
// never collide; unknown control words (\url, \emph, \&, \LaTeX) pass through
// for tex-to-string / tex-to-content to handle.
#let decode(s) = {
  if type(s) != str or not (s.contains("\\") or s.contains("$")) { return s }
  let cp = s.codepoints()
  let n = cp.len()
  let out = ""
  let i = 0
  while i < n {
    let c = cp.at(i)
    if c == "$" {
      let j = i + 1
      while j < n and cp.at(j) != "$" { j += 1 }
      out += _decode-math(cp.slice(i + 1, j).join(""))
      i = if j < n { j + 1 } else { j }
      continue
    }
    if c != "\\" { out += c; i += 1; continue }
    i += 1
    if i >= n { out += "\\"; break }
    let d = cp.at(i)
    if _is-letter(d) {
      let j = i
      while j < n and _is-letter(cp.at(j)) { j += 1 }
      let name = cp.slice(i, j).join(""); i = j
      if name in _special-letters {
        out += _special-letters.at(name)
        if i + 1 < n and cp.at(i) == "{" and cp.at(i + 1) == "}" { i += 2 }
      } else if name in _letter-accent {
        let (a, ni) = _read-arg(cp, i); out += decode(a) + _letter-accent.at(name); i = ni
      } else { out += "\\" + name }
    } else if d in _symbol-accent {
      let (a, ni) = _read-arg(cp, i + 1); out += decode(a) + _symbol-accent.at(d); i = ni
    } else { out += "\\" + d; i += 1 }
  }
  out
}

// ---- raw TeX -> plain Unicode string (sort/cite labels, text backbone) ------
#let tex-to-string(s) = {
  if type(s) != str { return s }
  s = decode(s)
  s = s.replace(regex("\\\\(?:url|href|emph|textit|textbf|textsc|textrm)\s*\{([^}]*)\}"), m => m.captures.at(0))
  s = s.replace("\\LaTeX", "LaTeX").replace("\\TeX", "TeX").replace("\\BibTeX", "BibTeX")
  s = s.replace("~", " ").replace("\\&", "&").replace("\\ ", " ").replace("\\,", "\u{2009}")
  s = s.replace("{", "").replace("}", "")
  s = s.replace("---", "\u{2014}").replace("--", "\u{2013}")
  s = s.replace("``", "\u{201C}").replace("''", "\u{201D}")
  s = s.replace("`", "\u{2018}").replace("'", "\u{2019}")
  s
}

// ---- raw TeX -> content (the default `tex-render`) --------------------------
// Brace-matched scan turning \emph/\textit -> emph and \url/\href -> real links
// (acmart loads hyperref); plain runs go through tex-to-string. \url targets and
// display text stay verbatim (URLs keep ~ etc.); \href display text is decoded.
#let _cmd-at(cp, i, word) = {
  let w = ("\\" + word).codepoints()
  if i + w.len() > cp.len() { return false }
  for k in range(w.len()) { if cp.at(i + k) != w.at(k) { return false } }
  // must be followed by an (optionally space-led) "{", and not be a longer name
  let a = i + w.len()
  if a < cp.len() and _is-letter(cp.at(a)) { return false }
  let b = _skip-ws(cp, a)
  b < cp.len() and cp.at(b) == "{"
}
#let tex-to-content(s) = {
  if type(s) != str { return s }
  let cp = s.codepoints()
  let n = cp.len()
  let out = []
  let buf = ""
  let i = 0
  while i < n {
    let c = cp.at(i)
    if c == "\\" and (_cmd-at(cp, i, "href") or _cmd-at(cp, i, "url")
                      or _cmd-at(cp, i, "emph") or _cmd-at(cp, i, "textit")) {
      out += tex-to-string(buf); buf = ""
      let href = _cmd-at(cp, i, "href")
      let url = _cmd-at(cp, i, "url")
      let word = if href { "href" } else if url { "url" } else if _cmd-at(cp, i, "emph") { "emph" } else { "textit" }
      let b1 = _skip-ws(cp, i + 1 + word.len())
      let e1 = _match-brace(cp, b1)
      let a1 = cp.slice(b1 + 1, e1).join("")
      if href {
        let b2 = _skip-ws(cp, e1 + 1)
        let e2 = _match-brace(cp, b2)
        let a2 = cp.slice(b2 + 1, e2).join("")
        out += link(a1)[#tex-to-content(a2)]
        i = e2 + 1
      } else if url {
        out += link(a1)[#a1]
        i = e1 + 1
      } else {
        out += emph(tex-to-content(a1))
        i = e1 + 1
      }
    } else { buf += c; i += 1 }
  }
  out += tex-to-string(buf)
  out
}
