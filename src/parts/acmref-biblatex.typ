// ACM BibLaTeX renderer and software driver port.

#import "bibtex.typ": parse-names
#import "scan.typ": match-brace, split-list-and, remove-outer
#import "tex.typ": foreign-purify, decode-chars, _special-letters as special-letters
#import "tex.typ": _accent-cs as accent-symbols, _cs-literal as visible-symbols
#import "tex.typ": _noop-cw as noop-words
#import "acmref-common.typ": render, blx-ends-punct, blx-visible-tail, it, fld, has, articleno-of, is-others, join-names, dashify
// A value's "already punctuated" flag is biblatex's own, and it reads through a
// closing bracket or quote to the stop behind it: a note of "(see below.)" ends
// the block on its own, where the .bst would add a second period.
#let V(text, c: none) = (c: render(if c == none { text } else { c }), p: blx-ends-punct(text))
#let fV(e, name) = if has(e, name) { V(fld(e, name)) } else { none }

// ---- BibLaTeX ACM driver port ---------------------------------------------
// Source files mirrored here:
//   * acmnumeric.bbx / acmauthoryear.bbx (ACM's BibLaTeX drivers/macros),
//   * software.bbx (driver extension loaded by both ACM styles),
//   * software.dbx (software-family datamodel + inheritance),
//   * english-software.lbx (visible software labels/strings).
//
// This is a visible-output port rather than a TeX macro interpreter: the functions
// below are named after the source macros/drivers where practical, but they emit
// Typst content directly and share the parser, TeX renderer, sort/cite state, and
// hyperlink machinery with the ACM-Reference-Format.bst port above.
// maxbibnames is 9 under both ACM styles and minbibnames is the biblatex default
// 1, so a reference-list name list longer than nine shows its first name and
// "et al." (Biber.pm:2924). An explicit "and others" is not one of the counted
// names, so a list of nine plus "and others" still prints all nine.
#let blx-maxbibnames = 9
#let blx-minbibnames = 1
#let blx-join-names(people) = {
  let real = people.filter(n => not is-others(n))
  let shown = if real.len() > blx-maxbibnames {
    real.slice(0, blx-minbibnames) + ((first: "", von: "", last: "others", jr: ""),)
  } else { people }
  join-names(shown, suffix-comma: false)
}
// \MakeSentenceCase* (blx-case-*.sty), which trad-standard.bbx:92 applies to
// every title it does not preserve: the FIRST character of the field is
// uppercased and every other letter is lowercased. "First character" is literal —
// a digit, a bracket or a quote takes that slot and nothing is uppercased at all
// ("3D rendering" -> "3d rendering"), and a sentence-ending period does not start
// a new one. A brace group is protected and passes through untouched, taking the
// slot with it; an accent command does not, so the letter it accents is cased.
// The letter-named accent commands. Like the symbol ones, they are not a
// character themselves: the letter behind them is what gets cased.
#let blx-accent-words = ("b", "c", "d", "H", "k", "r", "t", "u", "v")
// The letter-named commands that ARE a character, in the form each slot needs:
// uppercased as the first character of a title, lowercased anywhere else. "\ss"
// has no single uppercase — biblatex writes "SS" and the rest-rule then lowers
// the second letter — and dotless "\j" has no uppercase at all.
#let blx-case-macros = (
  ae: ("\\AE", "\\ae"), AE: ("\\AE", "\\ae"),
  oe: ("\\OE", "\\oe"), OE: ("\\OE", "\\oe"),
  o: ("\\O", "\\o"), O: ("\\O", "\\o"),
  aa: ("\\AA", "\\aa"), AA: ("\\AA", "\\aa"),
  l: ("\\L", "\\l"), L: ("\\L", "\\l"),
  ss: ("Ss", "\\ss"),
  i: ("I", "\\i"),
  j: ("\\j", "\\j"),
)
#let blx-sentence-case(raw) = {
  let cp = raw.codepoints()
  let n = cp.len()
  let letter = c => (c >= "A" and c <= "Z") or (c >= "a" and c <= "z")
  // a backslash followed by one of the seven accent symbols, or by an accent
  // command's name. Every OTHER control symbol — "\\&", "\\%" — is a character
  // of its own, so it fills the first-character slot instead of passing it on.
  let accent-at = j => j + 1 < n and cp.at(j) == "\\" and (
    cp.at(j + 1) in accent-symbols or {
      let k = j + 1
      while k < n and letter(cp.at(k)) { k += 1 }
      cp.slice(j + 1, k).join("") in blx-accent-words
    })
  let out = ""
  let first = true
  let after-accent = false
  let i = 0
  while i < n {
    let c = cp.at(i)
    if c == "\\" {
      let at = i + 1
      let k = at
      while k < n and letter(cp.at(k)) { k += 1 }
      if k > at {
        let name = cp.slice(at, k).join("")
        if name in blx-accent-words {
          // an accent spelled as a word: the letter behind it takes the slot
          out += "\\" + name
          after-accent = true
        } else if name in blx-case-macros {
          // a character of its own, so it takes the slot AND is cased. Its
          // delimiter whitespace belongs to the command, so it goes with it —
          // and a replacement that is itself a control word needs "{}" put back
          // in the delimiter's place ("\\ae sop" -> "\\AE{}sop", not "\\AE sop",
          // which would keep the space as text once the command name changed).
          let form = blx-case-macros.at(name).at(if first { 0 } else { 1 })
          out += form
          let ws = k
          while k < n and cp.at(k) in (" ", "\t", "\n", "\r") { k += 1 }
          if k > ws and form.starts-with("\\") { out += "{}" }
          first = false
          after-accent = false
        } else {
          // …and a command that prints nothing at all leaves the slot alone
          out += "\\" + name
          if name not in noop-words { first = false }
          after-accent = false
        }
        i = k
      } else {
        // only a control symbol that IS a visible character takes the slot. An
        // accent passes it to the letter behind it, and one that prints nothing
        // or a space ("\ ", "\,", "\/", "\-") passes it on like whitespace.
        let sym = if at < n { cp.at(at) } else { "" }
        out += c + sym
        i = if at < n { at + 1 } else { at }
        after-accent = sym in accent-symbols
        if sym in visible-symbols { first = false }
      }
    } else if after-accent and c in (" ", "\t", "\n", "\r") {
      // TeX scans past the whitespace that delimits an accent command from its
      // argument, so the letter behind it is still the character being cased.
      out += c
      i += 1
    } else if c == "{" and (after-accent or accent-at(i + 1)) {
      // the braces around an accent, or around its argument, are transparent —
      // biblatex cases the accented letter either way
      out += c
      i += 1
      after-accent = false
    } else if c == "{" {
      let j = match-brace(cp, i)
      out += cp.slice(i, calc.min(j + 1, n)).join("")
      first = false
      after-accent = false
      i = j + 1
    } else if lower(c) != upper(c) {
      out += if first { upper(c) } else { lower(c) }
      first = false
      after-accent = false
      i += 1
    } else {
      // whitespace is not a character to be cased, so it never takes the slot
      out += c
      if c not in (" ", "\t", "\n", "\r") { first = false }
      after-accent = false
      i += 1
    }
  }
  out
}

// A biblatex list field prints with the list's own punctuation: two items joined
// by "and", more by commas with a final "and" (the patent driver's parenthesized
// country list is the exception, and joins with bare commas).
#let blx-list-join(parts) = {
  if parts.len() == 0 { return [] }
  let out = []
  for (i, p) in parts.enumerate() {
    if i > 0 {
      if parts.len() == 2 { out += " and " }
      else if i == parts.len() - 1 { out += ", and " }
      else { out += ", " }
    }
    out += p
  }
  out
}
#let blx-list-content(raw) = blx-list-join(
  split-list-and(raw, trim: true, filter-empty: true).map(render))
// biblatex.def:641 prints each language item through the localization string
// `lang<identifier>` (english.lbx:472); an identifier with no string of its own
// prints literally, in the case it was given.
#let blx-language-strings = (
  american: "American", basque: "Basque", brazilian: "Brazilian",
  bulgarian: "Bulgarian", catalan: "Catalan", croatian: "Croatian", czech: "Czech",
  danish: "Danish", dutch: "Dutch", english: "English", estonian: "Estonian",
  finnish: "Finnish", french: "French", galician: "Galician", german: "German",
  greek: "Greek", hungarian: "Hungarian", italian: "Italian", japanese: "Japanese",
  latin: "Latin", latvian: "Latvian", lithuanian: "Lithuanian", marathi: "Marathi",
  norwegian: "Norwegian", polish: "Polish", portuguese: "Portuguese",
  romanian: "Romanian", russian: "Russian", serbian: "Serbian", slovak: "Slovak",
  slovene: "Slovene", spanish: "Spanish", swedish: "Swedish", turkish: "Turkish",
  ukrainian: "Ukrainian",
)
#let blx-language-items(raw) = {
  let parts = split-list-and(raw, trim: true, filter-empty: true)
  parts.map(v => if v in blx-language-strings { blx-language-strings.at(v) } else { v })
}
#let blx-language-value(raw) = {
  let parts = blx-language-items(raw)
  (c: blx-list-join(parts.map(render)), p: parts.len() > 0 and blx-ends-punct(parts.last()))
}
// The punctuation buffer sees the last item printed, not the whole field.
#let blx-list-last(raw) = {
  let parts = split-list-and(raw, trim: true, filter-empty: true)
  if parts.len() == 0 { raw } else { parts.last() }
}
#let blx-list-value(raw) = {
  let parts = split-list-and(raw, trim: true, filter-empty: true)
  (c: blx-list-content(raw), p: parts.len() > 0 and blx-ends-punct(parts.last()))
}
#let blx-list-field(e, ..names) = {
  for name in names.pos() {
    if has(e, name) { return blx-list-value(fld(e, name)) }
  }
  none
}
#let blx-months = (
  "1": "Jan.", "01": "Jan.", jan: "Jan.", january: "Jan.",
  "2": "Feb.", "02": "Feb.", feb: "Feb.", february: "Feb.",
  "3": "Mar.", "03": "Mar.", mar: "Mar.", march: "Mar.",
  "4": "Apr.", "04": "Apr.", apr: "Apr.", april: "Apr.",
  "5": "May", "05": "May", may: "May",
  "6": "June", "06": "June", jun: "June", june: "June",
  "7": "July", "07": "July", jul: "July", july: "July",
  "8": "Aug.", "08": "Aug.", aug: "Aug.", august: "Aug.",
  "9": "Sept.", "09": "Sept.", sep: "Sept.", sept: "Sept.", september: "Sept.",
  "10": "Oct.", oct: "Oct.", october: "Oct.",
  "11": "Nov.", nov: "Nov.", november: "Nov.",
  "12": "Dec.", dec: "Dec.", december: "Dec.",
  // EDTF season months, which biber accepts in the month position
  "21": "Spr.", "22": "Sum.", "23": "Aut.", "24": "Win.",
)
#let blx-month(raw) = {
  let parts = raw.replace(".", "").split(regex("[\\s,/-]+")).filter(p => p != "")
  let k = if parts.len() > 0 { lower(parts.first()) } else { lower(raw.replace(".", "")) }
  blx-months.at(k, default: raw)
}
// A `day` FIELD is not part of the date: biber's driver sourcemap nulls it
// (biblatex.def:1341), so only a `date` field can carry day precision.
//
// And a `date` OUTRANKS the legacy fields component by component: biber parses
// it and overwrites `year` and `month` with what it found, warning as it goes,
// so a legacy field only survives where the date says nothing. A range fills the
// end parts too, and an empty half — "2025-05-06/" — is an open end.
// Biber's date grammar is EDTF-flavoured, and more than a plain YYYY[-MM[-DD]]:
// an uncertainty ("2005?") or approximation ("2005~") marker is accepted and
// leaves no visible trace, trailing unspecified digits stand for the span they
// cover ("200X" IS 2000-2009), and months 21-24 are the seasons. A day is
// checked against the real calendar, leap years included — "2005-02-29" is
// rejected where "2004-02-29" is not. Anything biber rejects leaves the entry as
// undated as one with no date field, so nothing is materialized from it and
// inheritance flows past it.
#let blx-no-date-parts = (
  year: none, month: none, day: none,
  end-year: none, end-month: none, end-day: none, span: false,
)
#let blx-days-in-month(year, month) = {
  let year = calc.abs(year)
  let leap = calc.rem(year, 4) == 0 and (calc.rem(year, 100) != 0 or calc.rem(year, 400) == 0)
  if month == 2 and leap { 29 } else { (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31).at(month - 1) }
}
// One half of a date. EXACTLY ONE trailing marker is allowed — "?" uncertain,
// "~" approximate, "%" both — and it leaves no trace; two of them ("2005??") are
// invalid and reject the value. Unspecified digits stand for the span they
// cover, whether trailing in the year ("200X" is 1990-1999's neighbour decade),
// in the month ("2005-XX" is January to December) or in the day ("2005-05-XX" is
// the first to the last of May). A day is checked against the real calendar.
#let blx-iso-parts(raw) = {
  let t = raw.trim()
  if t.ends-with(regex("[?~%]")) { t = t.slice(0, -1) }
  if t.ends-with(regex("[?~%]")) { return blx-no-date-parts }
  let span = (y, m, d, ey, em, ed) => (
    year: y, month: m, day: d, end-year: ey, end-month: em, end-day: ed, span: true,
  )
  let plain = (y, m, d) => (
    year: y, month: m, day: d, end-year: none, end-month: none, end-day: none, span: false,
  )
  let unspecified = t.match(regex("^(-?\d{1,3})(X+)$"))
  if unspecified != none {
    let head = unspecified.captures.at(0)
    let xs = unspecified.captures.at(1)
    if head.len() + xs.len() != 4 { return blx-no-date-parts }
    return span(head + "0" * xs.len(), none, none, head + "9" * xs.len(), none, none)
  }
  if t.match(regex("^-?\d{4}$")) != none { return plain(t, none, none) }
  let mx = t.match(regex("^(-?\d{4})-XX$"))
  if mx != none {
    let y = mx.captures.at(0)
    return span(y, "01", none, y, "12", none)
  }
  let ym = t.match(regex("^(-?\d{4})-(0[1-9]|1[0-2]|2[1-4])$"))
  if ym != none { return plain(ym.captures.at(0), ym.captures.at(1), none) }
  let dx = t.match(regex("^(-?\d{4})-(0[1-9]|1[0-2])-XX$"))
  if dx != none {
    let y = dx.captures.at(0)
    let m = dx.captures.at(1)
    return span(y, m, "01", y, m, str(blx-days-in-month(int(y), int(m))))
  }
  let ymd = t.match(regex("^(-?\d{4})-(0[1-9]|1[0-2])-(\d{2})$"))
  if ymd != none {
    let y = ymd.captures.at(0)
    let m = ymd.captures.at(1)
    let d = ymd.captures.at(2)
    if int(d) >= 1 and int(d) <= blx-days-in-month(int(y), int(m)) { return plain(y, m, d) }
  }
  blx-no-date-parts
}
#let blx-date-parts(e) = {
  let raw = if has(e, "date") { fld(e, "date").trim() } else { "" }
  let halves = raw.split("/")
  let iso = t => if halves.len() > 2 { blx-no-date-parts } else { blx-iso-parts(t) }
  let legacy = name => if has(e, name) { fld(e, name) } else { none }
  let head = halves.first().trim()
  let start = iso(head)
  let tail = if halves.len() > 1 { halves.at(1).trim() } else { none }
  let far = if tail != none { iso(tail) } else { blx-no-date-parts }
  // A malformed START rejects the whole value, where a malformed END — or one
  // that is a span of its own — only costs the range: what biber could read of
  // the start stands alone. An EMPTY second half is the open end.
  let rejected = (head != "" and start.year == none) or halves.len() > 2
  let open-end = not rejected and tail == "" and start.year != none
  let use-end = not rejected and tail != none and tail != "" and far.year != none and not far.span
  let ranged = not rejected and (open-end or use-end or start.span)
  // an open START ("/2025-05-06") parses on the strength of its end alone
  let parsed = not rejected and (start.year != none or use-end)
  if not parsed {
    // No date of its own: every component is a field, whether the entry carried
    // it as a legacy `year`/`month` or inherited the parts biber materialized —
    // an empty one is the sentinel for an end (or a start) that is unknown.
    return (
      year: legacy("year"), month: legacy("month"), day: legacy("day"),
      end-year: legacy("endyear"), end-month: legacy("endmonth"), end-day: legacy("endday"),
      open: legacy("endyearunknown") != none,
      start-open: legacy("year") == none and legacy("endyear") != none,
      ranged: legacy("endyear") != none or legacy("endyearunknown") != none,
      parsed: false,
    )
  }
  // The legacy fields fill the start in as they fill in any other component, so
  // they answer the open-start question too: "/2026-06-14" beside year = 1999 is
  // the range 1999-2026, not an open one, and biber writes that year rather than
  // the empty field an unanswered start leaves.
  let year = if start.year != none { start.year } else { legacy("year") }
  let end = if use-end { far } else { blx-no-date-parts }
  (
    year: year,
    month: if start.month != none { start.month } else { legacy("month") },
    day: start.day,
    // …and a single value can be a span of its own: "200X" is the decade it
    // names, and it outranks whatever stands on the other side of the slash
    end-year: if start.span { start.end-year } else { end.year },
    end-month: if start.span { start.end-month } else { end.month },
    end-day: if start.span { start.end-day } else { end.day },
    open: open-end,
    // …and the mirror image: "/2025-05-06" is a range whose start nothing
    // supplies, which biber records as an EMPTY `year` field beside the end parts
    start-open: ranged and year == none and end.year != none,
    ranged: ranged,
    parsed: true,
  )
}
// A year prints without the zeros that pad it in the source and with a real
// MINUS SIGN where it is negative — "-0100" prints as "\u{2212}100". A cite label
// keeps the padding it was given ("0100"), and ACM's numeric `year` macro prints
// the digits alone, unsigned.
#let blx-year-digits(y) = {
  if y == none { return none }
  let digits = y.trim("-", at: start).trim("0", at: start)
  if digits == "" { "0" } else { digits }
}
#let blx-year-text(y) = {
  if y == none { return none }
  let shown = blx-year-digits(y)
  if y.starts-with("-") { "\u{2212}" + shown } else { shown }
}
#let blx-year-label(y) = if y == none { none } else { y.replace("-", "\u{2212}") }
// One end of a date, at whatever precision it was given: a comma goes in only
// behind a day ("June 14, 2026", but "June 2026").
#let blx-date-piece(m, d, y) = {
  let c = if m != none { blx-month(m) } else { "" }
  if d != none {
    let day = d.trim(regex("^0+"))
    c += (if c != "" { " " } else { "" }) + (if day == "" { "0" } else { day })
  }
  if y != none { c += (if d != none { ", " } else if c != "" { " " } else { "" }) + blx-year-text(y) }
  c
}
// \printdate — the date at its own precision, and *nothing at all* when the
// entry has none. The two visible stand-ins for a missing date are the `year`
// and `date+extradate` bibmacros below, never this one.
// A range prints both ends around an en dash, each end dropping what it shares
// with the other: the START gives up a year both ends carry, and the END gives
// up a month the start already named ("Jan. 2-Mar. 4, 2024", "Jan. 2-2, 2024").
// An open end is the dash with nothing behind it.
// The range rendering itself, over a set of components: each end drops what it
// shares with the other, and an open end is the dash with nothing behind it.
#let blx-render-date(p) = {
  if p.start-open {
    // only the YEAR is unknown: a month the legacy fields still name is printed,
    // and the space that would have carried the year stays with it
    let head = blx-date-piece(p.month, p.day, none)
    let tail = blx-date-piece(p.end-month, p.end-day, p.end-year)
    return head + (if head == "" { "" } else { " " }) + "\u{2013}" + tail
  }
  if p.year == none { return "" }
  let start-with = y => blx-date-piece(p.month, p.day, y)
  if p.open { return start-with(p.year) + "\u{2013}" }
  if p.end-year == none { return start-with(p.year) }
  let same-year = p.end-year == p.year
  let end-month = if same-year and p.end-month == p.month { none } else { p.end-month }
  let end = blx-date-piece(end-month, p.end-day, p.end-year)
  // a negative end needs a space of its own, or its minus would run into the dash
  let gap = if p.end-year != none and p.end-year.starts-with("-") { " " } else { "" }
  start-with(if same-year { none } else { p.year }) + "\u{2013}" + gap + end
}
#let blx-printdate(e) = blx-render-date(blx-date-parts(e))
// The label year a cite prints: the two ends collapse when they share it, and an
// open end keeps its dash ("[Open 2025-]", "[Year 2020-2022]").
#let blx-label-year(e) = {
  let p = blx-date-parts(e)
  let y = blx-year-label(p.year)
  let ey = blx-year-label(p.end-year)
  if p.start-open { return "\u{2013}" + ey }
  if y == none { return none }
  if p.open { return y + "\u{2013}" }
  // …and the same space a negative end needs behind the range dash
  if ey != none and ey != y {
    return y + "\u{2013}" + (if p.end-year.starts-with("-") { " " } else { "" }) + ey
  }
  y
}
// \usebibmacro{date} (acmnumeric.bbx:77) is \printtext[parens]{\printdate}: the
// parentheses are printed even when the date inside them comes out empty, so an
// undated entry whose driver reaches this macro shows a bare "()".
#let blx-date-macro(e) = (c: "(" + blx-printdate(e) + ")", p: false)
// \usebibmacro{date-ifmonth} (acmnumeric.bbx:212) gates that on the month alone.
#let blx-date-ifmonth(e) = if blx-date-parts(e).month != none { blx-date-macro(e) } else { none }
// ACM's own `year` bibmacro (acmnumeric.bbx:71 / acmauthoryear.bbx:91): the bare
// year field, or the literal "[n. d.]" — whose trailing period the punctuation
// tracker sees, so no block separator follows it.
#let blx-year-macro(e) = {
  let p = blx-date-parts(e)
  // an unknown start leaves that field EMPTY, and this macro prints the field —
  // so nothing is printed, and the lead's own separator stands, where an entry
  // with no date at all prints the "[n. d.]" stand-in below
  if p.start-open { return (c: "", p: true) }
  if p.year == none { (c: "[n. d.]", p: true) } else { (c: blx-year-digits(p.year), p: false) }
}
// authoryear.bbx's `date+extradate` (:58), with acmauthoryear.bbx:871 stripping
// its parentheses. When the entry has no date at all biber resolves labeldate to
// \literal{nodate} (biblatex.def:1391) and this prints biblatex's `nodate` string
// (english.lbx:389), capitalized here at the start of a reference entry. The
// extradate letter arrives already parenthesized for that case (blx-extras).
#let blx-labeldate(e, suffix: "") = {
  let d = blx-printdate(e)
  if d == "" { (c: "N.d." + suffix, p: suffix == "") } else { (c: d + suffix, p: false) }
}
// The date a driver's name lead prints: ACM's `year` macro under acmnumeric,
// the label date under acmauthoryear (which has no `year` macro in its drivers).
#let blx-lead-date(e, style: "numeric", suffix: "") = {
  if style == "author-year" { blx-labeldate(e, suffix: suffix) } else { blx-year-macro(e) }
}

// The punctuation buffer counts a comma, semicolon or colon as punctuation just
// as it counts a stop: a unit ending in one takes no separator of its own.
#let blx-punctuated(raw) = {
  let t = blx-visible-tail(raw)
  t != "" and t.last() in (".", "!", "?", ":", ";", ",")
}
// \usebibmacro{booktitle}. The proceedings drivers follow it with the series,
// number and article number of the volume; the other container drivers print the
// title alone, which is what `blx-booktitle-simple` is.
#let blx-booktitle(e, with-in: false, style: "numeric", volume-tail: true) = {
  // \usebibmacro{in:} is printed by the driver, not by the booktitle: an
  // entry with no booktitle still opens its container block with it.
  let pre = if not with-in { [] } else if style == "author-year" { [In: ] } else { [In ] }
  // With nothing behind it the macro's own colon (or its bare "In") is the last
  // punctuation of the block — no separator period follows it, and the space that
  // would have led into the title belongs to the block break instead.
  let has-book = has(e, "booktitle") or has(e, "booksubtitle") or has(e, "booktitleaddon")
  if not has-book {
    if not with-in { return none }
    return (c: if style == "author-year" { [In:] } else { [In] }, p: true, ends-colon: true)
  }
  // \mkbibemph wraps the container title AND its subtitle, with the same unit
  // between them the entry title uses; the addon sits outside the emphasis.
  let inner = ""
  if has(e, "booktitle") { inner = fld(e, "booktitle") }
  if has(e, "booksubtitle") {
    if inner != "" { inner += if blx-punctuated(inner) { " " } else { ". " } }
    inner += fld(e, "booksubtitle")
  }
  let c = if inner == "" { [] } else { it(render(inner)) }
  // \printfield{booktitleaddon} follows with no unit between it and the title —
  // the ACM styles leave the separator out, so the two run together.
  let last = inner
  if has(e, "booktitleaddon") {
    c += render(fld(e, "booktitleaddon"))
    last = fld(e, "booktitleaddon")
  }
  if volume-tail {
    if has(e, "series") {
      c += " (" + render(fld(e, "series")) + ")"
      last = "(" + fld(e, "series") + ")"
    }
    if has(e, "number") {
      c += " " + render(fld(e, "number"))
      last = fld(e, "number")
    }
    if articleno-of(e) != none {
      c += " Article " + articleno-of(e)
      last = articleno-of(e)
    }
  }
  // the container title keeps its own terminal punctuation, and \DeclareFieldFormat
  // {booktitle} (biblatex.def:564) adds no \isdot, so that stop is a sentence one
  (c: pre + c, p: blx-punctuated(last), sentence-punct: true)
}
#let blx-booktitle-simple(e, with-in: false, style: "numeric") = blx-booktitle(
  e, with-in: with-in, style: style, volume-tail: false)
#let blx-title-format(e, style: "numeric") = {
  let t = e.entry-type
  if style == "author-year" {
    // acmauthoryear.bbx inherits biblatex's standard title formats: article,
    // inbook, incollection, inproceedings, patent, thesis, and unpublished are
    // quoted; all other title fields use the default emphasized title format.
    if t in ("article", "inbook", "incollection", "inproceedings", "conference",
             "patent", "thesis", "mastersthesis", "phdthesis", "unpublished") {
      "quoted"
    } else { "emph" }
  } else {
    // acmnumeric.bbx inherits trad-standard.bbx: most titles are plain and
    // sentence-cased; book, inbook, manual, thesis, and proceedings titles are
    // emphasized.
    if t in ("book", "collection", "inbook", "manual", "thesis", "mastersthesis",
             "phdthesis", "proceedings") {
      "emph"
    } else { "plain" }
  }
}
// trad-standard.bbx:78 \MakeTitleCase leaves these entry types' titles alone.
#let blx-numeric-preserve-titlecase-types = (
  "book", "mvbook", "bookinbook", "booklet", "suppbook", "collection",
  "mvcollection", "suppcollection", "manual", "periodical", "suppperiodical",
  "proceedings", "mvproceedings", "reference", "mvreference", "report",
  "techreport", "thesis", "mastersthesis", "phdthesis",
)
#let blx-title-field(e, style: "numeric", format: auto, sentence: auto, omit-title: false) = {
  // `omit-title` is authoryear.bbx's \clearfield{title}: a lead that already
  // printed the title leaves the rest of the family to this stage.
  let use-title = has(e, "title") and not omit-title
  if not use-title and not has(e, "subtitle") and not has(e, "titleaddon") { return none }
  let sentence = if sentence == auto {
    // trad-standard.bbx MakeTitleCase sentence-cases article/chapter/paper-like
    // titles in numeric style. Whole-volume/report/thesis titles preserve the
    // supplied case; authoryear-comp/standard keeps supplied title case too.
    style == "numeric" and e.entry-type not in blx-numeric-preserve-titlecase-types
  } else { sentence }
  // the `title` bibmacro casts title and subtitle through `titlecase`
  // SEPARATELY before joining them with \subtitlepunct, so the subtitle gets a
  // capital of its own.
  let cased = t => if sentence { blx-sentence-case(t) } else { t }
  // each component of the family stands on its own: an entry with a subtitle or
  // an addon and no title prints what it has.
  // \subtitlepunct is a unit like any other: a title that ends in punctuation of
  // its own — a colon — takes a space where another takes a period.
  let comps = ()
  if use-title { comps.push(cased(fld(e, "title"))) }
  if has(e, "subtitle") { comps.push(cased(fld(e, "subtitle"))) }
  let shown = ""
  for (i, comp) in comps.enumerate() {
    if i > 0 { shown += if blx-punctuated(comps.at(i - 1)) { " " } else { ". " } }
    shown += comp
  }
  let fmt = if format == auto { blx-title-format(e, style: style) } else { format }
  let p = blx-punctuated(shown)
  let out = if shown == "" { (c: [], p: false) } else if fmt == "quoted" {
    let inner = render(shown) + if p { [] } else { [.] }
    (c: "\u{201C}" + inner + "\u{201D}", p: true)
  } else if fmt == "emph" {
    (c: it(render(shown)), p: p)
  } else {
    (c: render(shown), p: p)
  }
  // \printfield{titleaddon} is a unit of the `title` bibmacro itself, so it
  // travels with the title wherever a driver prints one.
  if not has(e, "titleaddon") { return out }
  let addon = fld(e, "titleaddon")
  if shown == "" { return (c: render(addon), p: blx-punctuated(addon)) }
  let joined = if out.p or blx-punctuated(shown) { " " } else { ". " }
  (c: out.c + joined + render(addon), p: blx-punctuated(addon))
}
#let blx-ordinal-edition(n) = {
  let suf = if n.ends-with("11") or n.ends-with("12") or n.ends-with("13") { "th" }
    else if n.ends-with("1") { "st" }
    else if n.ends-with("2") { "nd" }
    else if n.ends-with("3") { "rd" }
    else { "th" }
  n + suf
}
#let blx-edition(e) = if has(e, "edition") {
  let ed = fld(e, "edition")
  if ed.match(regex("^\d+$")) != none { (c: "(" + blx-ordinal-edition(ed) + " ed.)", p: false) }
  else { (c: "(" + render(ed) + " ed.)", p: false) }
} else { none }
// \DeclareFieldFormat{type} (biblatex.def:586) resolves a `type` field that
// names a localization string to that string. These are every string english.lbx
// puts in the type position — the four theses (:419), the two reports (:423), the
// three media (:425) and the twelve patent and patent-request ones (:548) — in
// their abbreviated forms, since both ACM styles set abbreviate=true. ACM
// redefines two of the theses (acmnumeric.bbx:13/14) and biblatex-software takes
// `software` over. Every driver prints the field at a sentence start, so the
// punctuation tracker capitalizes whatever comes back.
#let blx-type-strings = (
  bathesis: "BA thesis",
  mathesis: "Master\u{2019}s thesis",
  phdthesis: "Ph.D. Dissertation",
  candthesis: "Cand. thesis",
  resreport: "research rep.",
  techreport: "tech. rep.",
  software: "[SW]",
  datacd: "CD-ROM",
  audiocd: "audio CD",
  patent: "pat.",
  patentde: "German pat.",
  patenteu: "European pat.",
  patentfr: "French pat.",
  patentuk: "British pat.",
  patentus: "U.S. pat.",
  patreq: "pat. req.",
  patreqde: "German pat. req.",
  patreqeu: "European pat. req.",
  patreqfr: "French pat. req.",
  patrequk: "British pat. req.",
  patrequs: "U.S. pat. req.",
)
#let blx-type(e) = if has(e, "type") {
  let raw = fld(e, "type")
  let s = blx-type-strings.at(lower(raw.trim()), default: none)
  if s == none { V(raw) }
  else { (c: upper(s.first()) + s.slice(1), p: blx-ends-punct(s)) }
} else { none }
#let blx-pages(e) = {
  if has(e, "pages") { (c: dashify(fld(e, "pages")), p: false) }
  else if has(e, "numpages") { (c: fld(e, "numpages") + " pages", p: false) }
  else { none }
}
#let blx-chapter-pages(e) = {
  let ch = if has(e, "chapter") { render(fld(e, "chapter")) } else { none }
  let pg = blx-pages(e)
  if ch != none and pg != none { (c: "Chap. " + ch + ", " + pg.c, p: false) }
  else if ch != none { (c: "Chap. " + ch, p: false) }
  else { pg }
}
#let blx-series-number(e, style: "numeric", lower-strings: false, emph-cond: false) = {
  if not has(e, "series") and not has(e, "number") { return none }
  let series = if has(e, "series") {
    // trad-standard.bbx emphasizes series for book/inproceedings/proceedings
    // but not inbook/incollection; standard.bbx leaves it plain.
    // series+number:emphcond (trad-standard.bbx:703) emphasizes the series only
    // where a VOLUME stands with it; on its own the series prints [noformat].
    let emph-types = ("book", "inproceedings", "conference", "proceedings")
    let emphasized = style == "numeric" and e.entry-type in emph-types and (not emph-cond or has(e, "volume"))
    if emphasized {
      it(render(fld(e, "series")))
    } else {
      render(fld(e, "series"))
    }
  } else { none }
  if style == "numeric" {
    // trad-standard.bbx \series+number: \printfield{number} "in"
    // \printfield{series}. The "Number N" number format is declared for
    // book/incollection/inproceedings/proceedings only (trad-standard.bbx:65);
    // every other entry type falls through to ACM's bare format
    // (acmnumeric.bbx:29), which is declared later and so wins.
    let num = if has(e, "number") {
      let n = render(fld(e, "number"))
      if e.entry-type in ("book", "incollection", "inproceedings", "conference", "proceedings") {
        (if lower-strings { "number " } else { "Number " }) + n
      } else { n }
    }
    if has(e, "series") and has(e, "number") {
      (c: num + " in " + series, p: blx-punctuated(fld(e, "series")))
    } else if has(e, "number") {
      (c: num, p: blx-punctuated(fld(e, "number")))
    } else {
      (c: series, p: blx-ends-punct(fld(e, "series")))
    }
  } else {
    // standard.bbx \series+number: \printfield{series} [space]
    // \printfield{number}.
    let c = []
    let last = ""
    if has(e, "series") { c += series; last = fld(e, "series") }
    if has(e, "number") {
      if c != [] { c += " " }
      c += render(fld(e, "number"))
      last = fld(e, "number")
    }
    (c: c, p: blx-ends-punct(last))
  }
}
#let blx-volumes(e) = if has(e, "volumes") {
  (c: render(fld(e, "volumes")) + " vols.", p: true)
} else { none }
#let blx-bookauthor(e) = if has(e, "bookauthor") and fld(e, "bookauthor") != fld(e, "author", d: "\u{0}") {
  if "bookauthor" in e.names {
    let raw = blx-join-names(e.names.bookauthor)
    (c: render(raw), p: blx-ends-punct(raw))
  }
  else { V(fld(e, "bookauthor")) }
} else { none }
#let blx-publisher-location-date(e) = {
  let parts = ()
  if has(e, "publisher") { parts.push(blx-list-content(fld(e, "publisher"))) }
  if has(e, "location") { parts.push(blx-list-content(fld(e, "location"))) }
  let d = blx-date-ifmonth(e)
  if d != none { parts.push(d.c) }
  let raw = ()
  if has(e, "publisher") { raw.push(blx-list-last(fld(e, "publisher"))) }
  if has(e, "location") { raw.push(blx-list-last(fld(e, "location"))) }
  if d != none { raw.push(d.c) }
  if parts.len() == 0 { none } else { (c: parts.join(", "), p: blx-ends-punct(raw.join(", "))) }
}
// standard.bbx:871 \organization+location+date — the misc driver's tail. The
// location leads, a colon (not a comma) introduces the organization, and the
// `date` macro closes it, so a misc entry always shows a parenthesized date.
#let blx-organization-location-date(e) = {
  let loc = if has(e, "location") { fld(e, "location") }
  let c = []
  if loc != none { c += blx-list-content(loc) }
  if has(e, "organization") {
    if c != [] { c += ": " }
    c += blx-list-content(fld(e, "organization"))
  }
  if c != [] { c += ", " }
  (c: c + blx-date-macro(e).c, p: false)
}
// The pages as their own unit: with no chapter ahead of them, \bibpagespunct
// overrides whatever break the driver left pending (see `blx-blocks`).
#let blx-pages-unit(e) = {
  let pg = blx-chapter-pages(e)
  if pg == none { return () }
  if has(e, "chapter") { return (pg,) }
  ((c: pg.c, p: pg.p, join: "comma"),)
}
// A date field other than `date` — `eventdate` is the one a driver prints —
// rendered exactly as \printdate renders the entry's own, ranges included.
#let blx-field-date(e, name) = {
  if not has(e, name) { return "" }
  let halves = fld(e, name).trim().split("/")
  if halves.len() > 2 { return "" }
  let head = halves.first().trim()
  let start = blx-iso-parts(head)
  // the same halves rules as the entry's own date: a malformed START rejects the
  // value, a malformed or span END costs only the range
  if head != "" and start.year == none { return "" }
  let tail = if halves.len() > 1 { halves.at(1).trim() } else { none }
  let far = if tail != none and tail != "" { blx-iso-parts(tail) } else { blx-no-date-parts }
  let use-end = tail != none and tail != "" and far.year != none and not far.span
  let open-end = tail == "" and start.year != none
  if start.year == none and far.year == none { return "" }
  blx-render-date((
    year: start.year, month: start.month, day: start.day,
    end-year: if start.span { start.end-year } else if use-end { far.year } else { none },
    end-month: if start.span { start.end-month } else if use-end { far.month } else { none },
    end-day: if start.span { start.end-day } else if use-end { far.day } else { none },
    open: open-end,
    start-open: start.year == none and far.year != none,
  ))
}


// \newunit then \usebibmacro{chapter+pages}: a chapter opens that unit, so the
// pending block break stands ahead of it ("Boston. Chap. Nine, 71-100"), while
// pages alone leave the break pending until \bibpagespunct overrides it with its
// own comma ("Bern, 5-9"). Returned as the list of values the driver blocks over.
#let blx-publisher-pages(e) = {
  let pub = blx-publisher-location-date(e)
  let pg = blx-chapter-pages(e)
  if pg == none { return (pub,) }
  if has(e, "chapter") { return (pub, pg) }
  // The comma is the pages' own \bibpagespunct, which overrides the pending
  // block break whether or not a publisher block stands in front of them.
  if pub == none { return ((c: pg.c, p: pg.p, join: "comma"),) }
  ((c: pub.c + ", " + pg.c, p: false),)
}
#let blx-volume(e) = if has(e, "volume") { (c: "Vol. " + fld(e, "volume"), p: false) } else { none }
// biblatex capitalizes "Ed. by" at the start of a sentence and leaves it
// lowercase mid-sentence. The container macro's colon is what decides it: with
// nothing behind the "In:" the editor follows the colon and stays lowercase,
// where a booktitle would have closed the block and started a new sentence.
#let blx-ed-by(e, sentence-start: true) = if has(e, "editor") {
  let raw = blx-join-names(e.names.editor)
  (c: (if sentence-start { "Ed. by " } else { "ed. by " }) + render(raw), p: blx-ends-punct(raw))
} else { none }
#let blx-editor-block(e, style: "numeric", sentence-start: true) = if not has(e, "editor") {
  none
} else if style == "author-year" {
  blx-ed-by(e, sentence-start: sentence-start)
} else {
  let suffix = if e.names.editor.len() > 1 { ", (Eds.)" } else { ", (Ed.)" }
  (c: render(blx-join-names(e.names.editor)) + suffix, p: true)
}
#let blx-bytranslator(e) = if has(e, "translator") {
  let raw = blx-join-names(e.names.translator)
  (c: "Trans. by " + render(raw), p: blx-ends-punct(raw))
} else { none }
#let blx-isbn(e) = if has(e, "isbn") { (c: "isbn: " + fld(e, "isbn"), p: false) } else { none }
// biblatex's own name for the field is `journaltitle`; `journal` is the alias it
// keeps for BibTeX's spelling (biblatex.def field alias), and the `periodical`
// inheritance rule above writes the parent's title into the former.
// biblatex's own name for the field; the sourcemap above renames BibTeX's
// `journal` to it before any driver looks.
#let blx-journal-title(e) = if has(e, "journaltitle") { fld(e, "journaltitle") } else { none }
#let blx-journal(e) = {
  let jt = blx-journal-title(e)
  if jt == none { return none }
  let parts = (it(render(jt)),)
  if has(e, "series") { parts.push(render(fld(e, "series"))) }
  if has(e, "volume") { parts.push(fld(e, "volume")) }
  if has(e, "number") { parts.push(fld(e, "number")) }
  if has(e, "articleno") { parts.push("Article " + fld(e, "articleno").replace("~", " ")) }
  let d = blx-date-ifmonth(e)
  if d != none { parts.push(d.c) }
  if has(e, "eid") { parts.push(fld(e, "eid")) }
  let pg = blx-pages(e)
  if pg != none { parts.push(pg.c) }
  (c: parts.join(", "), p: false)
}
#let blx-periodical-journal(e) = {
  let jt = blx-journal-title(e)
  if jt == none { return none }
  let c = it(render(jt))
  if has(e, "volume") { c += " " + fld(e, "volume") }
  if has(e, "number") { c += ", " + fld(e, "number") }
  let d = blx-date-ifmonth(e)
  if d != none { c += " " + d.c }
  (c: c, p: false)
}
#let blx-note(e) = if has(e, "note") { V(fld(e, "note")) } else { none }
#let blx-url-urldate(e) = {
  let u = if has(e, "url") { fld(e, "url") } else if has(e, "urls") { fld(e, "urls") } else { none }
  if u == none { return none }
  let c = if has(e, "lastaccessed") { [Retrieved #render(fld(e, "lastaccessed")) from #link(u)[#u]] } else { link(u)[#u] }
  (c: c, p: false)
}
#let blx-eprint(e) = if has(e, "eprint") {
  let ep = fld(e, "eprint")
  let prefix = fld(e, "eprinttype", d: "arXiv")
  let arxiv = lower(prefix) == "arxiv"
  // \DeclareFieldFormat{eprint:arxiv} brackets the class; the generic eprint
  // format parenthesizes it behind the archive's own name.
  let cls = if not has(e, "eprintclass") { "" }
    else if arxiv { " [" + fld(e, "eprintclass") + "]" }
    else { " (" + fld(e, "eprintclass") + ")" }
  // \DeclareFieldFormat{eprint:arxiv} links to arxiv.org/abs; biblatex's generic
  // eprint format has no archive to build a URL from and links the identifier
  // itself, so an eprint is a hyperlink either way.
  let num = if arxiv { link("https://arxiv.org/abs/" + ep)[#ep] } else { link(ep)[#ep] }
  (c: prefix + ": " + num + cls, p: false)
} else { none }
#let blx-doi(e) = if has(e, "doi") {
  let d = fld(e, "doi")
  // BibLaTeX's \printfield{doi} prepends the https://doi.org/ resolver unconditionally
  // (even when the field is already a full URL, which double-wraps it) — mirror that
  // so the link targets match LaTeX. The bst backend strips the prefix instead.
  // The bundled ACM .bbx field format uses a tight `doi:` prefix. Staging that
  // file matters: TeX Live's installed version can differ here.
  (c: link("https://doi.org/" + d)[doi:#d], p: false)
} else { none }
// ACM's doi+eprint+url (acmnumeric.bbx:269 / acmauthoryear.bbx:283).
#let blx-tail(e) = {
  let items = ()
  // print url when no doi, OR when the per-entry `distinctURL` field is set and not
  // "0" (matches the .bst's `distinctURL empty.or.zero not`; field keys are lowercased
  // at parse time, so only "distincturl" can occur).
  let distinct-url = has(e, "distincturl") and fld(e, "distincturl") != "0"
  let u = if (not has(e, "doi")) or distinct-url { blx-url-urldate(e) } else { none }
  let ep = blx-eprint(e)
  // The \newunit that separates the URL from the eprint never fires: the line
  // break after \usebibmacro{url+urldate} inside the macro's \iffieldundef
  // branch already typeset a space, and the unit punctuation is dropped. Only
  // this one pair loses its period — a doi one unit further on keeps its own.
  if u != none { items.push(if ep == none { u } else { u + (p: true) }) }
  if ep != none { items.push(ep) }
  let doi = blx-doi(e)
  if doi != none { items.push(doi) }
  items
}

// `dot` records whether the lead already ends in a full stop of its own — an
// "et al." or ACM's "(Eds.)" — which the punctuation tracker then reads as the
// separator that would otherwise follow.
#let blx-person-label(e, editor-ok: true, org-ok: true, key-ok: true) = {
  if has(e, "author") {
    let raw = blx-join-names(e.names.author)
    return (c: render(raw), kind: "author", dot: blx-ends-punct(raw))
  }
  if editor-ok and has(e, "editor") {
    let suffix = if e.names.editor.len() > 1 { ", (Eds.)" } else { ", (Ed.)" }
    return (c: render(blx-join-names(e.names.editor)) + suffix, kind: "editor", dot: true)
  }
  if org-ok and has(e, "organization") {
    let org = blx-list-value(fld(e, "organization"))
    return (c: org.c, kind: "organization", dot: org.p)
  }
  if key-ok and has(e, "key") { return (c: render(fld(e, "key")), kind: "key", dot: false) }
  none
}
#let blx-lead(e, style: "numeric", suffix: "", editor-ok: true, org-ok: true, key-ok: true,
              editor-others: false) = {
  let who = blx-person-label(e, editor-ok: editor-ok, org-ok: org-ok, key-ok: key-ok)
  let dt = blx-lead-date(e, style: style, suffix: suffix)
  if who == none { return if style == "numeric" { dt } else { none } }
  // acmauthoryear.bbx:874 patches a LITERAL period into `date+extradate`, so the
  // separator is printed whatever precedes it ("… et al.. 2005"). acmnumeric
  // keeps \labelnamepunct, which the tracker drops after a lead of its own.
  // A lead that came through acmauthoryear's `editor+others` (:153) also carries
  // a stray space: line 163 of that macro ends without a `%`, so the newline
  // between the organization branch and `date+extradate` is typeset. Only that
  // one macro has the typo — the `editor` macro the periodical driver leads with
  // (authoryear.bbx:228) is `%`-terminated throughout.
  let sep = if style == "numeric" { if who.dot { " " } else { ". " } }
    else if editor-others and who.kind != "author" { " . " }
    else { ". " }
  (c: who.c + sep + dt.c, p: dt.p)
}
#let blx-inbook-lead(e, style: "numeric", suffix: "") = {
  // Both inbook drivers (acmnumeric.bbx:382, acmauthoryear.bbx:401) branch on
  // \iffieldundef{author}, not \ifnameundef{author}. author is a name list, and
  // a name list never defines the like-named field, so the "author undefined"
  // branch — \usebibmacro{byeditor+others} — runs even for entries that do have
  // an author: the editor is the only name lead this driver ever prints.
  // The two styles inherit different byeditor+others, which is why the editor
  // is typeset differently: acmauthoryear (via authoryear-comp -> standard.bbx)
  // keeps biblatex.def:2710, "Ed. by" ahead of the names, while acmnumeric (via
  // trad-plain -> trad-standard.bbx:675) puts the names first and appends the
  // ACM `editor`/`editors` strings "(Ed.)"/"(Eds.)" (acmnumeric.bbx:10) — the
  // same lead blx-editor-block builds. Their \adddot swallows the following
  // \labelnamepunct, so only a space separates the lead from the year that
  // acmnumeric.bbx then prints; acmauthoryear.bbx prints no year here.
  let ed = blx-editor-block(e, style: style)
  if ed == none { return if style == "numeric" { blx-year-macro(e) } else { none } }
  if style != "numeric" { return ed }
  let dt = blx-year-macro(e)
  (c: ed.c + " " + dt.c, p: dt.p)
}
// a rendered value carries visible text (drives block/swids filtering)
#let blx-nonempty(v) = v != none and v.c != none and v.c != [] and v.c != ""
#let blx-blocks(..vals) = {
  let pieces = vals.pos().filter(blx-nonempty)
  let out = []
  for (i, v) in pieces.enumerate() {
    // A value may carry its own join, which overrides the block break the driver
    // left pending: \bibpagespunct's comma ahead of pages, or the plain space an
    // event's parentheses take. \DeclarePunctuationPairs{comma} (biblatex.sty:2015)
    // still governs it: a comma survives an abbreviation dot — which is what every
    // name and list format leaves behind (\isdot, biblatex.def:624) — but not a
    // sentence period or a colon, so behind those the comma gives way to a space.
    let prev = if i == 0 { none } else { pieces.at(i - 1) }
    let after-stop = prev != none and (prev.at("ends-colon", default: false)
      or (prev.p and prev.at("sentence-punct", default: false)))
    let join = if i == 0 { none } else if after-stop and v.at("join", default: none) == "comma" {
      "space"
    } else { v.at("join", default: none) }
    if i > 0 { out += if join == "comma" { ", " } else { " " } }
    out += v.c
    let next-join = if i + 1 < pieces.len() and not v.at("ends-colon", default: false) {
      pieces.at(i + 1).at("join", default: none)
    } else { none }
    if not v.p and next-join == none { out += "." }
  }
  out
}
// \DeclareFieldFormat{version} (biblatex.def:589), which neither ACM .bbx
// overrides: the `version` bibstring (english.lbx:428) then a tie then the
// value. Every driver that prints it does so right after a \newunit, so the
// punctuation tracker always capitalizes the string here — unlike the software
// drivers, which print the same field mid-sentence (blx-sw-version).
#let blx-version(e) = if has(e, "version") {
  (c: "Version " + render(fld(e, "version")), p: false)
} else { none }

// misc, online, dataset and book lead with author/editor+others/translator+others:
// an editor can lead, and after that the macro falls through to the *translator*
// and then to an empty `key` (biber remaps key -> sortkey, biblatex.def:1368), so
// it never reaches the `\printlist{organization}` fallback inside editor+others.
// The manual driver's author/editor+others does reach it, which is why manual
// calls blx-lead directly with the organization left enabled.
#let blx-misc-lead(e, style: "numeric", suffix: "") = blx-lead(
  e, style: style, suffix: suffix, org-ok: false, key-ok: false, editor-others: true)

// The article, inbook, incollection and inproceedings drivers lead with
// `author/translator+others` (acmnumeric.bbx:295 and friends), which falls
// through to the translator and then to an empty `key` — so unlike the misc and
// book drivers they never lead with an editor or an organization. Their editor
// is printed later, by `byeditor+others`.
#let blx-author-lead(e, style: "numeric", suffix: "") = blx-lead(
  e, style: style, suffix: suffix, editor-ok: false, org-ok: false, key-ok: false)

#let blx-article-like(e, style: "numeric", suffix: "") = blx-blocks(
  blx-author-lead(e, style: style, suffix: suffix),
  blx-title-field(e, style: style),
  blx-bytranslator(e),
  blx-version(e),
  blx-journal(e),
  blx-editor-block(e, style: style),
  blx-note(e),
  ..blx-tail(e),
)
#let blx-inproceedings(e, style: "numeric", suffix: "") = {
  blx-blocks(
    blx-author-lead(e, style: style, suffix: suffix),
    blx-title-field(e, style: style),
    blx-bytranslator(e),
    blx-booktitle(e, with-in: true, style: style),
    blx-editor-block(e, style: style, sentence-start: has(e, "booktitle")),
    blx-volume(e),
    blx-list-field(e, "organization"),
    ..blx-publisher-pages(e),
    blx-isbn(e),
    ..blx-tail(e),
  )
}
#let blx-incollection(e, style: "numeric", suffix: "") = blx-blocks(
  blx-author-lead(e, style: style, suffix: suffix),
  blx-title-field(e, style: style),
  blx-bytranslator(e),
  blx-booktitle-simple(e, with-in: true, style: style),
  blx-series-number(e, style: style),
  blx-edition(e),
  blx-volume(e),
  blx-volumes(e),
  blx-editor-block(e, style: style, sentence-start: has(e, "booktitle")),
  blx-note(e),
  ..blx-publisher-pages(e),
  blx-isbn(e),
  ..blx-tail(e),
)
#let blx-inbook(e, style: "numeric", suffix: "") = {
  let lead = blx-inbook-lead(e, style: style, suffix: suffix)
  blx-blocks(
    lead,
    blx-title-field(e, style: style),
    blx-bytranslator(e),
    blx-bookauthor(e),
    blx-booktitle-simple(e, with-in: false, style: style),
    blx-edition(e),
    blx-volume(e),
    blx-volumes(e),
    blx-series-number(e, style: style),
    blx-note(e),
    ..blx-publisher-pages(e),
    blx-isbn(e),
    ..blx-tail(e),
  )
}
// @proceedings has a driver of its own in both styles, and neither is the book
// one. standard.bbx:569 and trad-standard.bbx:298, stage for stage:
//
//   author-year  editor lead . title . event+venue+date . volume(.part) .
//                volumes . series+number . note . organization .
//                publisher+location+date . chapter+pages . pagetotal . isbn …
//   numeric      editor lead . title . event+venue+date , vol(.part) of
//                number-in-series , volumes . location , edition , (date) .
//                organization , publisher . chapter+pages . pagetotal . isbn …
//                … and the note LAST, behind doi/eprint/url.
//
// The numeric branch's commas are trad-standard's \newcommaunit; ACM prints no
// year beside the editor there, and the date arrives parenthesized after the
// location instead.
#let blx-event(e) = {
  // \usebibmacro{event+venue+date}: the event title and its addon are units of
  // their own — an addon behind a title that already ends in a period takes no
  // second one — and the venue and event date follow in parentheses.
  let head = ()
  for name in ("eventtitle", "eventtitleaddon") {
    if has(e, name) { head.push((raw: fld(e, name), c: render(fld(e, name)))) }
  }
  let inner = ()
  if has(e, "venue") { inner.push(render(fld(e, "venue"))) }
  let d = blx-field-date(e, "eventdate")
  if d != "" { inner.push(d) }
  if head.len() == 0 and inner.len() == 0 { return none }
  let c = []
  for (i, h) in head.enumerate() {
    if i > 0 { c += if blx-punctuated(head.at(i - 1).raw) { " " } else { ". " } }
    c += h.c
  }
  let bare = head.len() == 0
  if inner.len() > 0 {
    if c != [] { c += " " }
    c += "(" + inner.join(", ") + ")"
  }
  // punctuated only when the text really ends that way — a parenthesized venue
  // does not, a title that ends in a period does
  // the punctuation buffer counts a colon and a semicolon too, not only a stop
  let ends = if inner.len() > 0 or head.len() == 0 { false } else {
    blx-punctuated(head.last().raw)
  }
  // with no event title ahead of them the parentheses follow the entry title
  // with a space, not a block break of their own
  if bare { return (c: c, p: ends, join: "space") }
  (c: c, p: ends)
}
// \printfield{volume} then \printfield{part}, and the part's own format is
// ".#1" — so a part standing without a volume prints as ".B", dot and all.
#let blx-volume-part(e, lower-case: false) = {
  let vol = if has(e, "volume") {
    (if lower-case { "vol. " } else { "Vol. " }) + render(fld(e, "volume"))
  } else { none }
  let part = if has(e, "part") { "." + render(fld(e, "part")) } else { none }
  if vol == none and part == none { return none }
  (c: (if vol == none { [] } else { vol }) + (if part == none { [] } else { part }), p: false)
}
// \mkpagetotal (biblatex.sty:3464): a NUMERAL takes the page string — singular
// for exactly one, leading zeros and all, since the value is read as an integer
// — and anything else (a range, a word) prints bare with no string at all.
#let blx-pagetotal(e) = if has(e, "pagetotal") {
  let raw = fld(e, "pagetotal").trim()
  if raw.match(regex("^\\d+$")) == none { return (c: render(fld(e, "pagetotal")), p: false) }
  (c: render(fld(e, "pagetotal")) + (if int(raw) == 1 { " p." } else { " pp." }), p: true)
} else { none }
// \printlist{organization}: a list, joined the way biblatex joins one.
#let blx-organization-list(e) = blx-list-field(e, "organization")
// trad-standard's unit model, which the numeric proceedings driver needs and the
// block model cannot express: \newunit and \newcommaunit SET the pending
// separator — the last one before something actually prints wins, so a run of
// absent stages passes the comma the series stage left on to the date. A starred
// \newcommaunit* is the exception: it applies only when the stage just before it
// printed. A value that already ends in punctuation keeps it and takes a space.
#let blx-units(..stages) = {
  let out = []
  let pending = none
  let pending-starred = false
  let emitted = false
  let last-punct = false
  for stage in stages.pos() {
    let (sep, v) = (stage.at(0), stage.at(1))
    let starred = stage.len() > 2 and stage.at(2)
    if not (starred and not emitted) { pending = sep; pending-starred = starred }
    emitted = false
    if not blx-nonempty(v) { continue }
    if out != [] {
      // \blx@addpunct drops a separator that would follow punctuation already
      // standing — but a STARRED unit is not routed through that test, which is
      // why an organization ending in an abbreviation dot still takes its comma.
      // A value carrying its own join (an event's parentheses) overrides both.
      let own = v.at("join", default: none)
      out += if own == "space" { " " }
        else if own == "comma" { ", " }
        else if pending == "." and not last-punct { ". " }
        else if pending == "," and (pending-starred or not last-punct) { ", " }
        else { " " }
    }
    out += v.c
    last-punct = v.p
    emitted = true
    pending = none
  }
  if out == [] { none } else { (c: out, p: last-punct) }
}
// \usebibmacro{maintitle+title}: with a maintitle the hierarchy leads, its addon
// rides with it, and the VOLUME belongs to it — "Main. Vol. 2: Component", where
// the colon is the volume's own unit and a hierarchy without one simply takes a
// period. A part with no volume beside it is dropped here. When the maintitle
// and the title are the same string biblatex prints it once, and the volume goes
// back to the driver's own stage.
#let blx-maintitle-same(e) = {
  has(e, "maintitle") and has(e, "title") and fld(e, "maintitle") == fld(e, "title")
}
#let blx-maintitle-takes-volume(e) = has(e, "maintitle") and not blx-maintitle-same(e)
#let blx-maintitle-title(e, style: "numeric") = {
  let title = blx-title-field(e, style: style)
  if not has(e, "maintitle") or blx-maintitle-same(e) { return title }
  // the maintitle carries the emphasis a container title does; the volume and
  // the title behind it do not
  let main = fld(e, "maintitle")
  let last = main
  if has(e, "mainsubtitle") {
    main += (if blx-punctuated(main) { " " } else { ". " }) + fld(e, "mainsubtitle")
    last = fld(e, "mainsubtitle")
  }
  let c = it(render(main))
  if has(e, "maintitleaddon") {
    c += (if blx-punctuated(last) { " " } else { ". " }) + render(fld(e, "maintitleaddon"))
    last = fld(e, "maintitleaddon")
  }
  let vol = if has(e, "volume") { blx-volume-part(e) }
  if vol != none {
    c += (if blx-punctuated(last) { " " } else { ". " }) + vol.c
    last = fld(e, "volume")
  }
  if title == none { return (c: c, p: blx-punctuated(last)) }
  let join = if vol != none { ": " } else if blx-punctuated(last) { " " } else { ". " }
  (c: c + join + title.c, p: title.p)
}
#let blx-proceedings(e, style: "numeric", suffix: "") = {
  if style != "numeric" {
    return blx-blocks(
      blx-misc-lead(e, style: style, suffix: suffix),
      blx-maintitle-title(e, style: style),
      if has(e, "language") { blx-language-value(fld(e, "language")) },
      blx-event(e),
      blx-bytranslator(e),
      if has(e, "author") { blx-editor-block(e, style: style) },
      if not blx-maintitle-takes-volume(e) { blx-volume-part(e) },
      blx-volumes(e),
      blx-series-number(e, style: style),
      blx-note(e),
      blx-organization-list(e),
      blx-publisher-location-date(e),
      ..blx-pages-unit(e),
      blx-pagetotal(e),
      blx-isbn(e),
      ..blx-tail(e),
    )
  }
  // Stage for stage, each with the separator that precedes it.
  let vol = if blx-maintitle-takes-volume(e) { none } else { blx-volume-part(e, lower-case: true) }
  let ser = blx-series-number(e, style: style, lower-strings: true, emph-cond: true)
  let series-vol = if vol != none and ser != none { (c: vol.c + " of " + ser.c, p: false) }
    else if vol != none { vol } else { ser }
  let pages = blx-pages-unit(e)
  let location = if has(e, "location") { blx-list-value(fld(e, "location")) }
  let publisher = if has(e, "publisher") {
    (c: blx-list-content(fld(e, "publisher")), p: blx-punctuated(blx-list-last(fld(e, "publisher"))))
  }
  let run = blx-units(
    (none, blx-editor-block(e, style: style)),
    (" ", blx-maintitle-title(e, style: style)),
    (".", if has(e, "language") { blx-language-value(fld(e, "language")) }),
    // trad-standard's guard tests venue/eventtitle/eventyear, so an event that
    // is nothing but an addon is skipped here where author-year prints it
    (".", if has(e, "eventtitle") or has(e, "venue") or blx-field-date(e, "eventdate") != "" {
      blx-event(e)
    }),
    (".", blx-bytranslator(e)),
    (",", series-vol),
    (",", blx-volumes(e)),
    (".", location),
    (",", blx-edition(e)),
    (",", blx-date-macro(e)),
    (".", blx-organization-list(e)),
    (",", publisher, true),
    (if has(e, "chapter") { "." } else { "," }, if pages.len() > 0 { pages.first() }),
    (".", blx-pagetotal(e)),
  )
  blx-blocks(run, blx-isbn(e), ..blx-tail(e), blx-note(e))
}
#let blx-book-like(e, style: "numeric", suffix: "") = blx-blocks(
  blx-misc-lead(e, style: style, suffix: suffix),
  blx-title-field(e, style: style),
  blx-bytranslator(e),
  // the name lead consumed the editor unless the entry also has an author
  if has(e, "author") { blx-editor-block(e, style: style) },
  blx-edition(e),
  blx-series-number(e, style: style),
  blx-volume(e),
  blx-volumes(e),
  blx-note(e),
  ..blx-publisher-pages(e),
  blx-isbn(e),
  ..blx-tail(e),
)
// misc (acmnumeric.bbx:597 / acmauthoryear.bbx:608), which every entry type
// without a driver of its own aliases to (standard.bbx:752). Its tail is
// organization+location+date, so a misc entry always shows a parenthesized
// date, and doi+eprint+url, which drops the URL when a DOI is present.
#let blx-misc(e, style: "numeric", suffix: "") = blx-blocks(
  blx-misc-lead(e, style: style, suffix: suffix),
  blx-title-field(e, style: style),
  blx-bytranslator(e),
  fV(e, "howpublished"),
  blx-type(e),
  blx-version(e),
  blx-note(e),
  blx-organization-location-date(e),
  ..blx-tail(e),
)

// online (acmnumeric.bbx:636 / acmauthoryear.bbx:645). Unlike misc it prints no
// howpublished and no type, dates only when the entry has a month, and ends in
// a bare eprint + url+urldate rather than doi+eprint+url — so an online entry
// never shows a DOI, and shows its URL even when it has one.
#let blx-online(e, style: "numeric", suffix: "") = blx-blocks(
  blx-misc-lead(e, style: style, suffix: suffix),
  blx-title-field(e, style: style),
  blx-bytranslator(e),
  blx-version(e),
  blx-note(e),
  blx-list-field(e, "organization"),
  blx-date-ifmonth(e),
  blx-eprint(e),
  blx-url-urldate(e),
)

// manual (acmnumeric.bbx:546 / acmauthoryear.bbx:559).
#let blx-manual(e, style: "numeric", suffix: "") = blx-blocks(
  blx-lead(e, style: style, suffix: suffix, key-ok: false, editor-others: true),
  blx-title-field(e, style: style),
  blx-edition(e),
  blx-series-number(e, style: style),
  blx-type(e),
  blx-version(e),
  blx-note(e),
  blx-list-field(e, "organization"),
  blx-publisher-location-date(e),
  blx-chapter-pages(e),
  blx-isbn(e),
  ..blx-tail(e),
)
// standard.bbx:348 is the only definition of the `dataset` driver: neither ACM
// .bbx redefines it, so — unlike the ACM-authored drivers next door, online
// (acmnumeric.bbx:636) and misc (:597) — it never calls acmnumeric.bbx's `year`
// macro (:71). A numeric dataset entry therefore carries no year at all. An
// author-year one still shows its date because authoryear.bbx prints the label
// date from the name macro, for every driver alike. The only date this driver
// prints itself arrives through publisher+location+date (acmnumeric.bbx:203),
// which defers to date-ifmonth (:212) and so emits a parenthesized date only
// when the entry has a month. Unlike the online driver this one also prints
// type/edition/series+number, drops howpublished, and routes its URL through
// ACM's doi+eprint+url (:269), which suppresses the URL when a DOI is present.
#let blx-dataset(e, style: "numeric", suffix: "") = {
  let lead = if style == "author-year" {
    blx-misc-lead(e, style: style, suffix: suffix)
  } else {
    let who = blx-person-label(e, org-ok: false, key-ok: false)
    if who != none { (c: who.c, p: who.dot) }
  }
  blx-blocks(
    lead,
    blx-title-field(e, style: style),
    // the name lead consumed the editor unless the entry has an author
    if has(e, "author") { blx-editor-block(e, style: style) },
    blx-bytranslator(e),
    blx-type(e),
    blx-edition(e),
    blx-version(e),
    blx-series-number(e, style: style),
    blx-note(e),
    blx-list-field(e, "organization"),
    blx-publisher-location-date(e),
    ..blx-tail(e),
  )
}
// acmnumeric.bbx:219 institution+location+date — like publisher+location+date,
// it closes with date-ifmonth.
#let blx-institution-location(e) = {
  let parts = ()
  for v in (blx-list-field(e, "institution"),
            blx-list-field(e, "location"),
            blx-date-ifmonth(e)) {
    if v != none { parts.push(v.c) }
  }
  if parts.len() == 0 { none } else { (c: parts.join(", "), p: false) }
}
// authoryear.bbx:202 — report, thesis and patent lead with biblatex's own `author`
// macro, which prints the LABEL title where a name would go when the entry has no
// author, and the date behind it. labeltitle (:285) prints `shorttitle` if there is
// one and otherwise the title, which it then clears, so the driver's own title
// stage prints only what is left of the family. The separator is acmauthoryear's
// literal ". " (its `date+extradate` patch), and csquotes pulls that whole unit
// inside a quoted title, leaving the year flush against the closing quote.
#let blx-labeltitle-lead(lead, title, e, style: "numeric", suffix: "") = {
  if style != "author-year" or lead != none { return (lead, title) }
  // an explicit `label` outranks both (authoryear.bbx:286) and prints through its
  // own field format, which no style declares — so plainly, with no quotes and no
  // emphasis — and leaves the whole title family to the driver's title stage.
  let explicit = has(e, "label")
  let short = has(e, "shorttitle")
  let raw = if explicit { fld(e, "label") } else if short { fld(e, "shorttitle") } else if has(e, "title") { fld(e, "title") } else { "" }
  if raw == "" { return (lead, title) }
  let fmt = if explicit { "plain" } else { blx-title-format(e, style: style) }
  let head = if fmt == "quoted" { "\u{201C}" + render(raw) + ". \u{201D}" }
    else if fmt == "emph" { it(render(raw)) + ". " }
    else { render(raw) + ". " }
  let dt = blx-labeldate(e, suffix: suffix)
  ((c: head + dt.c, p: dt.p), blx-title-field(e, style: style, omit-title: not (explicit or short)))
}
#let blx-report(e, style: "numeric", suffix: "", thesis: false) = {
  // report prints the type and the number as one unit (acmnumeric.bbx:767);
  // the thesis driver (:799) prints no number at all.
  let ty = blx-type(e)
  if ty != none and not thesis and has(e, "number") {
    ty = (c: ty.c + " " + render(fld(e, "number")), p: false)
  }
  let (lead, title) = blx-labeltitle-lead(
    blx-lead(e, style: style, suffix: suffix, editor-ok: false, org-ok: false),
    blx-title-field(e, style: style), e, style: style, suffix: suffix)
  blx-blocks(
    lead,
    title,
    ty,
    // report prints a version (acmnumeric.bbx:771); the thesis driver (:799) does not
    if not thesis { blx-version(e) },
    blx-institution-location(e),
    blx-note(e),
    blx-chapter-pages(e),
    ..blx-tail(e),
  )
}

#let blx-patent(e, style: "numeric", suffix: "") = {
  let locations = if has(e, "location") {
    split-list-and(fld(e, "location"), trim: true, filter-empty: true).map(render).join(", ")
  } else { none }
  let identification = []
  let ty = blx-type(e)
  if ty != none { identification += ty.c }
  if has(e, "number") {
    if identification != [] { identification += " " }
    identification += "Patent No. " + render(fld(e, "number"))
  }
  if locations != none and locations != [] {
    identification += " (" + locations + ")"
  }
  let holder = if has(e, "holder") {
    let raw = blx-join-names(e.names.holder)
    (c: render(raw), p: blx-ends-punct(raw))
  } else { none }
  let (lead, title) = blx-labeltitle-lead(
    blx-lead(e, style: style, suffix: suffix, editor-ok: false, org-ok: false, key-ok: false),
    blx-title-field(e, style: style), e, style: style, suffix: suffix)
  blx-blocks(
    lead,
    title,
    blx-date-macro(e),
    if identification == [] { none } else { (c: identification, p: false) },
    holder,
    blx-note(e),
    ..blx-tail(e),
  )
}

// ---- BibLaTeX software.dbx + software.bbx port ----------------------------
#let blx-software-types = ("software", "softwareversion", "softwaremodule", "codefragment")
#let blx-software-labels = (
  software: "[SW]",
  softwareversion: "[SW Rel.]",
  softwaremodule: "[SW Mod.]",
  codefragment: "[SW exc.]",
)

// acmnumeric.bbx:846/acmauthoryear.bbx:861 DeclareStyleSourcemap, plus the two
// steps of biblatex's own driver sourcemap (biblatex.def:1348-1358) that matter
// here: remapping a thesis or techreport also stamps the `type` field with the
// localization string naming what it was, unless the entry already has one.
#let blx-typed-remaps = (
  techreport: "techreport", phdthesis: "phdthesis", mastersthesis: "mathesis",
)
// The name lists our parser keeps; an inherited one has to reach `names` too,
// because sorting, labels and disambiguation all read the parsed form.
#let blx-name-roles = ("author", "editor", "bookauthor", "translator", "holder", "sortname")
// …and the rest of that same driver sourcemap: the entry types BibTeX spells
// differently, and the fields it does. Both are renames, not fallbacks, and both
// happen BEFORE inheritance — which is what lets a child's own `journal` block
// the `journaltitle` its parent would otherwise pass down.
#let blx-type-aliases = (conference: "inproceedings", electronic: "online", www: "online")
#let blx-field-aliases = (
  hyphenation: "langid", address: "location", school: "institution",
  annote: "annotation", archiveprefix: "eprinttype", journal: "journaltitle",
  primaryclass: "eprintclass", key: "sortkey", pdf: "file",
)
#let blx-acm-sourcemap(db) = {
  let out = (:)
  for (k, e0) in db {
    let e = e0
    if e.entry-type in blx-typed-remaps and not has(e, "type") {
      e.fields.insert("type", blx-typed-remaps.at(e.entry-type))
    }
    if e.entry-type == "techreport" { e = e + (entry-type: "report") }
    else if e.entry-type == "artifactsoftware" { e = e + (entry-type: "software") }
    else if e.entry-type == "artifactdataset" { e = e + (entry-type: "dataset") }
    else if e.entry-type in blx-type-aliases {
      e = e + (entry-type: blx-type-aliases.at(e.entry-type))
    }
    // \step[fieldset=day, null]: a `day` FIELD is not part of a BibTeX entry's
    // date. Only a parsed `date` carries day precision — and, from here on, the
    // components inheritance materializes.
    if "day" in e.fields { let _ = e.fields.remove("day") }
    for (alias, canonical) in blx-field-aliases {
      if alias in e.fields {
        let v = e.fields.at(alias)
        let _ = e.fields.remove(alias)
        // a RENAME, so an entry that spells the field both ways keeps the
        // canonical value and the legacy one goes with its name
        if canonical not in e.fields {
          e.fields.insert(canonical, v)
          if canonical in blx-name-roles { e.names.insert(canonical, parse-names(v)) }
        }
        if alias in e.names { let _ = e.names.remove(alias) }
      }
    }
    // …and then the empty ones go: biber's own parser drops them, so an empty
    // field of the child's does NOT stand in the way of what its parent passes
    // down — it only decided, just above, which spelling of the name survives.
    for (name, value) in e.fields {
      if value.trim() == "" {
        let _ = e.fields.remove(name)
        if name in e.names { let _ = e.names.remove(name) }
      }
    }
    out.insert(k, e)
  }
  out
}

// software.bbx DeclareStyleSourcemap: strip whitespace in swhid and derive
// swhidcore from the part before the first semicolon.
#let blx-software-sourcemap-entry(e) = {
  if has(e, "swhid") {
    let clean = fld(e, "swhid").replace(regex("\s+"), "")
    e.fields.insert("swhid", clean)
    if not has(e, "swhidcore") {
      e.fields.insert("swhidcore", clean.split(";").at(0))
    }
  }
  e
}

// Biber materializes every component it parsed out of a `date` — and an EMPTY
// field for each one that date leaves unknown, which is what keeps a crossref
// parent's own year out of a child whose range starts open. A date string biber
// cannot read leaves no trace at all, so such a child inherits everything.
#let blx-fill-date-fields(e) = {
  let p = blx-date-parts(e)
  if not p.parsed { return e }
  // EVERY component, ends included: an entry whose own date is a single year has
  // no end, and the empty fields saying so are what keep a grandparent's range
  // from reaching past it. An end that is genuinely unknown is a state of its
  // own — biber's \true{enddateunknown} — and travels as its own marker, since
  // an empty `endyear` alone cannot tell "no end" from "end unknown".
  for (name, value) in (
    ("year", p.year), ("month", p.month), ("day", p.day),
    ("endyear", p.end-year), ("endmonth", p.end-month), ("endday", p.end-day),
  ) {
    e.fields.insert(name, if value == none { "" } else { value })
  }
  // the marker is a component like any other: present and empty where this date
  // has no open end, so a parent's marker cannot be inherited over it
  e.fields.insert("endyearunknown", if p.open { "1" } else { "" })
  e
}

#let blx-inherit-skip = (
  "ids", "crossref", "xref", "entryset", "entrysubtype", "execute", "label",
  "options", "presort", "related", "relatedoptions", "relatedstring",
  "relatedtype", "shorthand", "shorthandintro", "sortkey",
  // biber splits a parsed date into its parts and inherits THOSE (a child's own
  // `year` keeps the parent's year out while its month still arrives), so the
  // date string itself never travels — `blx-fill-date-fields` has already put
  // the parent's parts where this pass can find them.
  "date",
)
#let blx-title-skip = ("shorttitle", "sorttitle", "indextitle", "indexsorttitle")
#let blx-inherit-rules = (
  (from: ("mvbook", "book"), to: ("inbook", "bookinbook", "suppbook"),
   map: (("author", "author"), ("author", "bookauthor")), skip: ()),
  (from: ("mvbook",), to: ("book", "inbook", "bookinbook", "suppbook"),
   map: (("title", "maintitle"), ("subtitle", "mainsubtitle"),
         ("titleaddon", "maintitleaddon")), skip: blx-title-skip),
  (from: ("mvcollection", "mvreference"),
   to: ("collection", "reference", "incollection", "inreference", "suppcollection"),
   map: (("title", "maintitle"), ("subtitle", "mainsubtitle"),
         ("titleaddon", "maintitleaddon")), skip: blx-title-skip),
  (from: ("mvproceedings",), to: ("proceedings", "inproceedings"),
   map: (("title", "maintitle"), ("subtitle", "mainsubtitle"),
         ("titleaddon", "maintitleaddon")), skip: blx-title-skip),
  (from: ("book",), to: ("inbook", "bookinbook", "suppbook"),
   map: (("title", "booktitle"), ("subtitle", "booksubtitle"),
         ("titleaddon", "booktitleaddon")), skip: blx-title-skip),
  (from: ("collection", "reference"), to: ("incollection", "inreference", "suppcollection"),
   map: (("title", "booktitle"), ("subtitle", "booksubtitle"),
         ("titleaddon", "booktitleaddon")), skip: blx-title-skip),
  (from: ("proceedings",), to: ("inproceedings",),
   map: (("title", "booktitle"), ("subtitle", "booksubtitle"),
         ("titleaddon", "booktitleaddon")), skip: blx-title-skip),
  (from: ("periodical",), to: ("article", "suppperiodical"),
   map: (("title", "journaltitle"), ("subtitle", "journalsubtitle"),
         ("titleaddon", "journaltitleaddon")), skip: blx-title-skip),
)
#let blx-inherit-field(e, name, value) = {
  if name in e.fields { return e }
  e.fields.insert(name, value)
  if name in blx-name-roles { e.names.insert(name, parse-names(value)) }
  e
}
// Resolved recursively, so a chain resolves from the top down and a codefragment
// reaches the software project two crossrefs above it.
#let blx-inherit-entry(db, key, seen: ()) = {
  let e = blx-fill-date-fields(blx-software-sourcemap-entry(db.at(key)))
  if not has(e, "crossref") { return e }
  let xr = fld(e, "crossref")
  if xr not in db or xr in seen { return e }
  let parent = blx-inherit-entry(db, xr, seen: seen + (key,))
  let processed = ()
  for rule in blx-inherit-rules {
    if parent.entry-type not in rule.from or e.entry-type not in rule.to { continue }
    for (source, target) in rule.map {
      if source not in parent.fields { continue }
      processed.push(source)
      e = blx-inherit-field(e, target, parent.fields.at(source))
    }
    for source in rule.skip {
      if source in parent.fields { processed.push(source) }
    }
  }
  for (fk, fv) in parent.fields {
    if fk in blx-inherit-skip or fk in processed { continue }
    e = blx-inherit-field(e, fk, fv)
  }
  e
}

#let blx-biber-datamodel(db) = {
  let mapped = blx-acm-sourcemap(db)
  let out = (:)
  for (k, e) in mapped {
    let r = blx-inherit-entry(mapped, k)
    out.insert(k, r)
  }
  out
}

}

#let blx-printlist(e, name) = if has(e, name) {
  (c: blx-list-content(fld(e, name)), p: false)
} else { none }

// software.bbx prints the title with the style's plain \printfield{title}:
// trad-standard.bbx (acmnumeric) leaves it upright, while acmauthoryear
// inherits biblatex's emphasized default.
#let blx-sw-title(e, style) = {
  let t = render(fld(e, "title", d: ""))
  if style == "author-year" { it(t) } else { t }
}
// The same `version` field format as blx-version, printed mid-sentence (right
// after the title), so the bibstring stays lowercase.
#let blx-sw-version(e) = if has(e, "version") { " version " + render(fld(e, "version")) } else { [] }
// software.bbx's shared date tail: a starred \setunit before \printdate, so an
// entry with no date at all ends right after the title/version.
#let blx-sw-date(e) = {
  let date = blx-printdate(e)
  if date == "" { [] }
  else if has(e, "version") or has(e, "editor") { ", " + date }
  else { " " + date }
}
#let blx-sw-editor(e) = if has(e, "editor") {
  [ (Coord.by #render(blx-join-names(e.names.editor)))]
} else { [] }

#let blx-sw-subtitle(e) = if has(e, "subtitle") {
  "\u{201C}" + render(fld(e, "subtitle")) + ",\u{201D}"
} else { [] }

// software.bbx's \newbibmacro*{swtitleauthoreditoryear} and its two subtitle
// variants (swsubtitle… and codefragmenttitle…), which differ only in the phrase
// that joins the subtitle to the title.
#let blx-sw-title-macro(e, style, subtitle-join: none) = {
  let c = []
  if has(e, "author") { c += render(blx-join-names(e.names.author)) + ", " }
  if subtitle-join != none and has(e, "subtitle") { c += blx-sw-subtitle(e) + subtitle-join }
  c += blx-sw-title(e, style)
  c += blx-sw-version(e)
  c += blx-sw-editor(e)
  c += blx-sw-date(e)
  (c: c, p: false)
}

#let blx-sw-url(e) = if has(e, "url") {
  let u = fld(e, "url")
  (c: [url: #link(u)[#u]], p: false)
} else { none }
#let blx-sw-hal-id(e) = if has(e, "hal_id") {
  let id = fld(e, "hal_id") + fld(e, "hal_version", d: "")
  (c: [hal: #link("https://hal.archives-ouvertes.fr/" + id)[⟨#id⟩]], p: false)
} else { none }
#let blx-sw-repository(e) = if has(e, "repository") {
  let u = fld(e, "repository")
  (c: [vcs: #link(u)[#u]], p: false)
} else { none }
#let blx-sw-swhid(e) = if has(e, "swhid") {
  let id = fld(e, "swhid")
  (c: [swhid: #link("http://archive.softwareheritage.org/" + id)[⟨#id⟩]], p: false)
} else { none }

// software.bbx: \newbibmacro*{swids}. ACM sets license=false, halid/swhid/vcs
// true in acmnumeric.bbx/acmauthoryear.bbx.
#let blx-swids(e) = {
  let pieces = (
    blx-doi(e),
    blx-sw-hal-id(e),
    blx-eprint(e),
    blx-sw-url(e),
    blx-sw-repository(e),
    blx-sw-swhid(e),
  ).filter(blx-nonempty)
  if pieces.len() == 0 { return none }
  let c = []
  for (i, v) in pieces.enumerate() {
    if i > 0 { c += ", " }
    c += v.c
  }
  (c: c, p: false)
}

#let blx-software-driver(e, kind, style: "numeric") = {
  let body = blx-sw-title-macro(e, style, subtitle-join: if kind == "software" { none }
    else if kind == "codefragment" { " from " } else { " part of " })
  let labelled = (c: blx-software-labels.at(kind) + " " + body.c, p: body.p)
  blx-blocks(
    labelled,
    blx-printlist(e, "institution"),
    blx-printlist(e, "organization"),
    blx-swids(e),
  )
}

#let blx-handle(e, style: "numeric", year-suffix: "") = {
  let t = e.entry-type
  if t == "article" { blx-article-like(e, style: style, suffix: year-suffix) }
  else if t == "inproceedings" or t == "conference" { blx-inproceedings(e, style: style, suffix: year-suffix) }
  else if t == "incollection" { blx-incollection(e, style: style, suffix: year-suffix) }
  else if t == "inbook" { blx-inbook(e, style: style, suffix: year-suffix) }
  else if t == "proceedings" { blx-proceedings(e, style: style, suffix: year-suffix) }
  else if t == "book" or t == "collection" { blx-book-like(e, style: style, suffix: year-suffix) }
  else if t == "patent" { blx-patent(e, style: style, suffix: year-suffix) }
  else if t in blx-software-types { blx-software-driver(e, t, style: style) }
  else if t == "artifactdataset" or t == "dataset" { blx-dataset(e, style: style, suffix: year-suffix) }
  else if t == "online" or t == "www" or t == "electronic" { blx-online(e, style: style, suffix: year-suffix) }
  else if t == "manual" { blx-manual(e, style: style, suffix: year-suffix) }
  else if t == "mastersthesis" or t == "phdthesis" or t == "thesis" { blx-report(e, style: style, suffix: year-suffix, thesis: true) }
  else if t == "techreport" or t == "report" { blx-report(e, style: style, suffix: year-suffix) }
  else if t == "periodical" {
    blx-blocks(
      blx-lead(e, style: style, suffix: year-suffix),
      blx-title-field(e, style: style, sentence: false),
      blx-periodical-journal(e),
      blx-note(e),
      ..blx-tail(e),
    )
  }
  // misc, and with it every type biblatex has no driver for — including ACM's
  // own `presentation` and `underreview`, which acm{numeric,authoryear}.bbx
  // declare in the datamodel but never give a driver.
  else { blx-misc(e, style: style, suffix: year-suffix) }
}

// ---- sort key: biber's `nty` template --------------------------------------
// \DeclareSortingTemplate{nty} (biblatex.def:1493), which both ACM styles select
// (acmnumeric.bbx:878 / acmauthoryear.bbx:893), is six sort sets compared in
// turn:
//   1 presort
//   2 sortkey                                                          [final]
//   3 sortname / author / editor / translator / sorttitle / title
//   4 sorttitle / title
//   5 sortyear / year                                                    (int)
//   6 volume, else the literal 0                                         (int)
// Set 2 is `final`: where it fires biber emits an empty string in its own slot
// and copies the value into every later slot (Internals.pm:1141), so a `key`
// field — which biblatex.def:1368 renames to `sortkey` — becomes the entry's
// whole sort key. That slot is a constant empty string for every entry, so it is
// left out of the key built here.
//
// The whole tuple is packed into one string because Typst compares strings by
// code point: a NUL joins the slots (below every character a slot can hold, so a
// shorter slot still sorts first) and the integer slots are zero-padded.
#let blx-sort-slot-sep = "\u{0}"

// Biber's normalise_string_sort (Utils.pm:589), over the value `decode-chars`
// has already turned into characters — the one place that reads a character
// command, here as everywhere else. What is left for this function is the
// residue: a tie becomes a space, a combining mark goes and leaves the base
// letter behind (which is what carries the primary collation weight, exactly
// what biber compares), then the syntax the decoder did not claim — an unknown
// control word, which biber's own regex deletes while leaving the whitespace
// behind it, a bare accent symbol, an escape, the braces — and the whitespace
// collapses. PUNCTUATION IS KEPT, unlike the .bst's purify$, because biber's
// collator gives it real weights below the digits and the letters.
// The braces come off LAST, so `nosort` can still see them: biber filters the
// name part in the form remove_outer left, where "de{-}Zed" keeps a dash the
// pattern cannot match.
#let blx-sort-clean(s) = {
  let t = str.normalize(decode-chars(s), form: "nfd")
    .replace(regex("([^\\\\])~"), m => m.captures.at(0) + " ")
  // Decomposing first puts every accent in the same shape, whether this decoded
  // it or the .bib typed the character whole, and the base letter left behind is
  // what biber's collator weighs.
  t = t.replace(regex("\\p{M}+"), "")
  t = t.replace(regex("\\\\[A-Za-z]+([ \t\n\r]*)"), m => m.captures.at(0))
  t = t.replace(regex("\\\\['`^\"~=.][ \t\n\r]*"), "")
  t.replace(regex("\\\\(.)"), m => m.captures.at(0))
}
#let blx-sort-debrace(t) = t.replace(regex("[{}]+"), "").trim().replace(regex("\\s+"), " ")
#let blx-sort-normalize(s) = blx-sort-debrace(blx-sort-clean(s))
// The primary weight biber's root collation gives each of the characters a
// BibTeX foreign-letter command stands for: "æ" files as "ae", "ß" as "ss", "å"
// as "a" — and the case it carries survives, because that is a tertiary
// difference biber does resolve ("Æ" files ahead of "æ" the way "Aesop" files
// ahead of "aesop"). Expanding is the LAST step: a rule that counts letters —
// `nosort` below — has to see "Æ-Zed", one letter before the dash, and not the
// two letters "AE-Zed" would hand it.
#let blx-char-expansions = {
  let out = (:)
  for (name, expansion) in foreign-purify { out.insert(special-letters.at(name), expansion) }
  out
}
#let blx-expand-chars(t) = {
  t.clusters().map(c => blx-char-expansions.at(c, default: c)).fold("", (a, b) => a + b)
}

// One sort slot's collation key. biblatex turns both `sortcase` and `sortupper`
// on (biblatex.sty:16129), so biber compares a slot with the full UCA: the
// case-folded text decides first and case only separates slots that are
// otherwise equal, uppercase first. Packing that as folded text, a separator
// above NUL but below every real character, then the per-character case pattern
// reproduces it slot by slot.
// Biber's collator gives every space, punctuation mark and symbol a primary
// weight below the digits and the letters, and `variable => non-ignorable` keeps
// them from being ignored altogether. Code-point order does not: ":;<=>?@",
// "[\]^_`" and "{|}~" all sit above the digits or above the letters. Folding the
// non-alphanumeric ASCII characters into a low block, in their own order,
// restores the class ordering — a title opening with a tie then files under the
// letter behind it rather than after "z".
#let blx-sort-punct = {
  let out = (:)
  for (i, c) in " !\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~".clusters().enumerate() {
    out.insert(c, str.from-unicode(2 + i))
  }
  out
}
#let blx-collate(t) = {
  let case-bit(c) = if c != lower(c) { "\u{0}" } else { "\u{1}" }
  let weigh(c) = blx-sort-punct.at(c, default: c)
  let primary = lower(t).clusters().map(weigh).fold("", (a, b) => a + b)
  primary + "\u{1}" + t.clusters().map(case-bit).fold("", (a, b) => a + b)
}
#let blx-sort-field(s) = blx-collate(blx-expand-chars(blx-sort-normalize(s)))

// ACM leaves `maxsortnames`/`minsortnames` at the values `maxbibnames=9` pulls
// them to (biblatex.sty:15008); past that biber sorts on the first name alone
// plus a marker that outranks every character (Biber.pm:2937, Internals.pm:1532).
#let blx-maxsortnames = 9
#let blx-minsortnames = 1
#let blx-name-trunc = "\u{10FFFD}"

// biber's default `nosort` (Constants.pm:266) is scoped to the `setnames` field
// set — every name list — so it filters each NAME PART before comparison, and
// leaves titles alone. Two patterns: a two-letter prefix joined by a dash at the
// very start of the part, whatever its case ("de-Zed" files under Z, "al-Hakim"
// under H, but three-letter "Ibn-Sina" stays under I), and the two characters
// biblatex never sorts on, anywhere in the part. The pattern counts LETTERS, so
// it has to run on the decoded characters and the expansion has to wait for it:
// "\AE{}-Zed" is "Æ-Zed", one letter before the dash, and keeps its prefix.
#let blx-nosort(s) = {
  s.replace(regex("^\\p{L}\\p{L}\\p{Pd}(\\S)"), m => m.captures.at(0))
    .replace(regex("[\u{02BF}\u{2018}]"), "")
}
#let blx-name-sort-part(s) = blx-expand-chars(blx-sort-debrace(blx-nosort(blx-sort-clean(remove-outer(s)))))

// The longest value of each name part anywhere in the reference list. Biber
// records this while parsing every name of every entry it creates
// (Input/file/bibtex.pm:1847) and pads with it below; any width at least as
// large as every value gives the same ordering, so measuring the strings that
// are actually padded rather than the raw ones is immaterial.
#let blx-np-lengths(entries) = {
  let m = (family: 0, given: 0, suffix: 0, prefix: 0)
  for e in entries {
    for (_, people) in e.names {
      for n in people {
        for (k, s) in (("family", n.last), ("given", n.first), ("suffix", n.jr), ("prefix", n.von)) {
          let l = blx-name-sort-part(s).clusters().len()
          if l > m.at(k) { m.insert(k, l) }
        }
      }
    }
  }
  m
}

// _namestring (Internals.pm:1489) driven by \DeclareSortingNamekeyTemplate
// (biblatex.def:1451): four key parts per name — (prefix, only with useprefix) +
// family, then given, then suffix, then (prefix, only without useprefix) —
// concatenated with no separator, name after name. The LAST name part of each
// key part is space-padded to the list-wide maximum, which is what keeps the
// parts aligned from one name to the next (biber makes the space non-ignorable
// in its collator for exactly this reason); a name part the entry does not have
// contributes nothing at all, not even padding. A prefix that shares its key
// part with the family name is NOT padded, so "van Berg" runs together as
// "vanberg". `useprefix` is on under acmnumeric (trad-standard.bbx:18) and off
// under acmauthoryear, which is why the two ACM styles file prefixed names
// differently. A trailing "and others" is not a name and neither counts toward
// the truncation nor marks the list as truncated (Biber.pm:2889).
#let blx-name-sort-string(people, lens, useprefix) = {
  let real = people.filter(n => not is-others(n))
  let visible = if real.len() > blx-maxsortnames { blx-minsortnames } else { real.len() }
  let out = ""
  for n in real.slice(0, visible) {
    let part(s, w) = {
      let t = blx-name-sort-part(s)
      t + " " * calc.max(0, w - t.clusters().len())
    }
    if useprefix and n.von != "" { out += blx-name-sort-part(n.von) }
    if n.last != "" { out += part(n.last, lens.family) }
    if n.first != "" { out += part(n.first, lens.given) }
    if n.jr != "" { out += part(n.jr, lens.suffix) }
    if not useprefix and n.von != "" { out += part(n.von, lens.prefix) }
  }
  if visible < real.len() { out += blx-name-trunc }
  out
}

// _sort_integer (Internals.pm:1239) maps a roman numeral to its value; whatever
// is still not a number becomes 2000000000 in the key extractor (Biber.pm:4320),
// so entries missing an integer field sort last within their group.
#let blx-roman-value(s) = {
  let t = upper(s.trim())
  if t == "" { return none }
  if t.match(regex("^M{0,3}(CM|CD|D?C{0,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})$")) == none { return none }
  let vals = (M: 1000, D: 500, C: 100, L: 50, X: 10, V: 5, I: 1)
  let total = 0
  let prev = 0
  for c in t.clusters().rev() {
    let v = vals.at(c)
    if v < prev { total -= v } else { total += v; prev = v }
  }
  total
}
#let blx-sort-int(s) = {
  if s == none { return 2000000000 }
  let t = s.trim()
  let r = blx-roman-value(t)
  if r != none { return r }
  if t.match(regex("^[+-]?\d+$")) != none { return int(t.trim("+", at: start)) }
  2000000000
}
// _sort_integer reads the field in Perl's boolean context (Internals.pm:1243), so
// a field whose value is exactly "0" counts as ABSENT and the sort set falls
// through to the next field in it — `sortyear = {0}` defers to `year`, and
// `volume = {0}` to the template's own literal 0.
#let blx-int-field(e, name) = if has(e, name) and fld(e, name).trim() != "0" { fld(e, name) }
// Biased so a negative year still sorts numerically, and wide enough for the
// 2000000000 sentinel above the bias.
#let blx-int-bias = 5000000000
#let blx-pad-int(n) = { let s = str(n + blx-int-bias); "0" * calc.max(0, 11 - s.len()) + s }

#let pick-int(..vals) = { let r = vals.pos().find(v => v != none); r }
#let blx-sort-key(e, lens: (family: 0, given: 0, suffix: 0, prefix: 0), useprefix: false) = {
  // \DeclarePresort{mm} (biblatex.def:1467) is the default for every entry type.
  let presort = blx-sort-field(fld(e, "presort", d: "mm"))
  // A `key` field arrives here as `sortkey` and takes over every later slot.
  let sortkey = if has(e, "sortkey") { fld(e, "sortkey") }
  if sortkey != none {
    let slot = blx-sort-field(sortkey)
    let n = blx-pad-int(blx-sort-int(blx-sort-normalize(sortkey)))
    return (presort, slot, slot, n, n).join(blx-sort-slot-sep)
  }
  let title = if has(e, "sorttitle") { fld(e, "sorttitle") } else { fld(e, "title", d: "") }
  // `usetranslator` is off by default (biblatex.sty:16132), so a translator-only
  // entry falls through to the title in the name slot as well.
  let people = if "sortname" in e.names { e.names.sortname }
    else if "author" in e.names { e.names.author }
    else if "editor" in e.names { e.names.editor }
  let named = if people != none { blx-name-sort-string(people, lens, useprefix) } else { "" }
  let name-slot = if named != "" { blx-collate(named) } else { blx-sort-field(title) }
  let year = pick-int(blx-int-field(e, "sortyear"), blx-int-field(e, "year"))
  let volume = blx-int-field(e, "volume")
  (
    presort,
    name-slot,
    blx-sort-field(title),
    blx-pad-int(blx-sort-int(year)),
    blx-pad-int(if volume == none { 0 } else { blx-sort-int(volume) }),
  ).join(blx-sort-slot-sep)
}
