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
