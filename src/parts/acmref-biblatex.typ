// ACM BibLaTeX renderer and software driver port.

#import "bibtex.typ": parse-names
#import "scan.typ": match-brace, split-list-and, remove-outer
#import "tex.typ": foreign-purify, decode-chars, _special-letters as special-letters
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
#let blx-has-cased(s) = s.codepoints().any(c => lower(c) != upper(c))

// BibLaTeX numeric inherits a sentence-casing title formatter. Keep TeX control
// words and protected brace groups intact so presentation commands/logos survive.
#let blx-sentence-case(raw) = {
  let cp = raw.codepoints()
  let out = ""
  let first = true
  let i = 0
  while i < cp.len() {
    let c = cp.at(i)
    if c == "\\" {
      out += c
      i += 1
      let start = i
      while i < cp.len() and ((cp.at(i) >= "A" and cp.at(i) <= "Z") or (cp.at(i) >= "a" and cp.at(i) <= "z")) {
        out += cp.at(i)
        i += 1
      }
      if i == start and i < cp.len() { out += cp.at(i); i += 1 }
    } else if c == "{" {
      let j = match-brace(cp, i)
      let g = cp.slice(i, calc.min(j + 1, cp.len())).join("")
      out += g
      if first and blx-has-cased(g) { first = false }
      i = j + 1
    } else if c in (".", "!", "?") {
      out += c
      if i + 1 < cp.len() and cp.at(i + 1) == " " { first = true }
      i += 1
    } else if lower(c) != upper(c) {
      out += if first { upper(c) } else { lower(c) }
      first = false
      i += 1
    } else {
      out += c
      i += 1
    }
  }
  out
}

#let blx-list-field(e, ..names) = {
  for name in names.pos() {
    if has(e, name) { return V(fld(e, name)) }
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
#let blx-print-full-date(e) = {
  let p = blx-date-parts(e)
  if p.year == none { return "[n. d.]" }
  if p.month == none { return p.year }
  let c = blx-month(p.month)
  if p.day != none {
    let day = p.day.trim(regex("^0+"))
    c += " " + if day == "" { "0" } else { day } + ","
  }
  c + " " + p.year
}
#let blx-date(e, full: false, suffix: "") = {
  // ACM's bundled author-year style prints month+year in ordinary label dates;
  // a day appears only in drivers that explicitly use BibLaTeX's full date
  // macro (notably patents).
  (c: blx-printdate(e) + suffix, p: false)
}
#let blx-date-if-month(e) = {
  let p = blx-date-parts(e)
  if p.month != none and p.year != none { (c: "(" + blx-printdate(e) + ")", p: false) } else { none }
}
#let blx-date-parens(e) = {
  let p = blx-date-parts(e)
  if p.year != none { (c: "(" + blx-printdate(e) + ")", p: false) } else { none }
}
#let blx-eprint-date(e) = {
  if not has(e, "eprint") { return blx-date-if-month(e) }
  let p = blx-date-parts(e)
  if p.year != none { (c: "(" + blx-printdate(e) + ")", p: false) } else { none }
}

#let blx-title-raw(e) = {
  if not has(e, "title") { return none }
  let raw = fld(e, "title")
  if has(e, "subtitle") { raw += ". " + fld(e, "subtitle") }
  raw
}
#let blx-title(e, style: "numeric", sentence: true) = {
  let raw = blx-title-raw(e)
  if raw == none { return none }
  let shown = if style == "numeric" and sentence { blx-sentence-case(raw) } else { raw }
  (c: render(shown), p: blx-ends-punct(shown))
}
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
#let blx-booktitle(e, with-in: false, style: "numeric") = {
  if not has(e, "booktitle") { return none }
  let c = it(render(fld(e, "booktitle")))
  if has(e, "booksubtitle") { c += ". " + render(fld(e, "booksubtitle")) }
  if has(e, "series") { c += " (" + render(fld(e, "series")) + ")" }
  if has(e, "number") { c += " " + render(fld(e, "number")) }
  if articleno-of(e) != none { c += " Article " + articleno-of(e) }
  let pre = if not with-in { [] } else if style == "author-year" { [In: ] } else { [In ] }
  (c: pre + c, p: false)
}
#let blx-booktitle-simple(e, with-in: false, style: "numeric") = {
  if not has(e, "booktitle") { return none }
  let c = it(render(fld(e, "booktitle")))
  if has(e, "booksubtitle") { c += ". " + render(fld(e, "booksubtitle")) }
  let pre = if not with-in { [] } else if style == "author-year" { [In: ] } else { [In ] }
  (c: pre + c, p: false)
}
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
#let blx-numeric-preserve-titlecase-types = (
  "book", "collection", "manual", "periodical", "proceedings", "report",
  "techreport", "thesis", "mastersthesis", "phdthesis",
)
#let blx-title-field(e, style: "numeric", format: auto, sentence: auto) = {
  let raw = blx-title-raw(e)
  if raw == none { return none }
  let sentence = if sentence == auto {
    // trad-standard.bbx MakeTitleCase sentence-cases article/chapter/paper-like
    // titles in numeric style. Whole-volume/report/thesis titles preserve the
    // supplied case; authoryear-comp/standard keeps supplied title case too.
    style == "numeric" and e.entry-type not in blx-numeric-preserve-titlecase-types
  } else { sentence }
  let shown = if sentence { blx-sentence-case(raw) } else { raw }
  let fmt = if format == auto { blx-title-format(e, style: style) } else { format }
  let p = blx-ends-punct(shown)
  if fmt == "quoted" {
    let inner = render(shown) + if p { [] } else { [.] }
    (c: "\u{201C}" + inner + "\u{201D}", p: true)
  } else if fmt == "emph" {
    (c: it(render(shown)), p: p)
  } else {
    (c: render(shown), p: p)
  }
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
#let blx-series-number(e, style: "numeric") = {
  if not has(e, "series") and not has(e, "number") { return none }
  let series = if has(e, "series") {
    // trad-standard.bbx emphasizes series for book/inproceedings/proceedings
    // but not inbook/incollection; standard.bbx leaves it plain.
    if style == "numeric" and e.entry-type in ("book", "inproceedings", "conference", "proceedings") {
      it(render(fld(e, "series")))
    } else {
      render(fld(e, "series"))
    }
  } else { none }
  if style == "numeric" {
    // trad-standard.bbx \series+number: \printfield{number} "in"
    // \printfield{series}; ACM's number field format is bare for the custom
    // inproceedings macro, but incollection/book use the inherited "Number N".
    if has(e, "series") and has(e, "number") {
      (c: "Number " + render(fld(e, "number")) + " in " + series, p: false)
    } else if has(e, "number") {
      (c: "Number " + render(fld(e, "number")), p: false)
    } else {
      (c: series, p: blx-ends-punct(fld(e, "series")))
    }
  } else {
    // standard.bbx \series+number: \printfield{series} [space]
    // \printfield{number}.
    let c = []
    if has(e, "series") { c += series }
    if has(e, "number") {
      if c != [] { c += " " }
      c += render(fld(e, "number"))
    }
    (c: c, p: false)
  }
}
#let blx-volumes(e) = if has(e, "volumes") {
  (c: render(fld(e, "volumes")) + " volumes", p: false)
} else { none }
#let blx-bookauthor(e) = if has(e, "bookauthor") and fld(e, "bookauthor") != fld(e, "author", d: "\u{0}") {
  if "bookauthor" in e.names { (c: render(join-names(e.names.bookauthor)), p: false) }
  else { V(fld(e, "bookauthor")) }
} else { none }
#let blx-publisher-location-date(e) = {
  let parts = ()
  if has(e, "publisher") { parts.push(render(fld(e, "publisher"))) }
  if has(e, "location") { parts.push(render(fld(e, "location"))) }
  else if has(e, "address") { parts.push(render(fld(e, "address"))) }
  if has(e, "month") { parts.push("(" + blx-printdate(e) + ")") }
  let raw = ()
  if has(e, "publisher") { raw.push(fld(e, "publisher")) }
  if has(e, "location") { raw.push(fld(e, "location")) }
  else if has(e, "address") { raw.push(fld(e, "address")) }
  if has(e, "month") { raw.push("(" + blx-printdate(e) + ")") }
  if parts.len() == 0 { none } else { (c: parts.join(", "), p: blx-ends-punct(raw.join(", "))) }
}
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
  if pub != none and pg != none { (c: pub.c + ", " + pg.c, p: false) }
  else if pub != none { pub }
  else { pg }
}
#let blx-volume(e) = if has(e, "volume") { (c: "Vol. " + fld(e, "volume"), p: false) } else { none }
#let blx-ed-by(e) = if has(e, "editor") {
  (c: "Ed. by " + render(join-names(e.names.editor)), p: false)
} else { none }
#let blx-editor-block(e, style: "numeric") = if not has(e, "editor") {
  none
} else if style == "author-year" {
  blx-ed-by(e)
} else {
  let suffix = if e.names.editor.len() > 1 { ", (Eds.)" } else { ", (Ed.)" }
  (c: render(join-names(e.names.editor)) + suffix, p: true)
}
#let blx-bytranslator(e) = if has(e, "translator") {
  (c: "Trans. by " + render(join-names(e.names.translator)), p: false)
} else { none }
#let blx-isbn(e) = if has(e, "isbn") { (c: "isbn: " + fld(e, "isbn"), p: false) } else { none }
#let blx-journal(e) = {
  if not has(e, "journal") { return none }
  let parts = (it(render(fld(e, "journal"))),)
  if has(e, "series") { parts.push(render(fld(e, "series"))) }
  if has(e, "volume") { parts.push(fld(e, "volume")) }
  if has(e, "number") { parts.push(fld(e, "number")) }
  if has(e, "articleno") { parts.push("Article " + fld(e, "articleno").replace("~", " ")) }
  let d = blx-date-if-month(e)
  if d != none { parts.push(d.c) }
  if has(e, "eid") { parts.push(fld(e, "eid")) }
  let pg = blx-pages(e)
  if pg != none { parts.push(pg.c) }
  (c: parts.join(", "), p: false)
}
#let blx-periodical-journal(e) = {
  if not has(e, "journal") { return none }
  let c = it(render(fld(e, "journal")))
  if has(e, "volume") { c += " " + fld(e, "volume") }
  if has(e, "number") { c += ", " + fld(e, "number") }
  let d = blx-date-if-month(e)
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
  let prefix = fld(e, "archiveprefix", d: if has(e, "eprinttype") { fld(e, "eprinttype") } else { "arXiv" })
  let cls = if has(e, "primaryclass") { " [" + fld(e, "primaryclass") + "]" } else if has(e, "eprintclass") { " [" + fld(e, "eprintclass") + "]" } else { "" }
  // acmart links arXiv eprints to arxiv.org/abs (\showeprint, acmart.dtx:8913);
  // non-arXiv prefixes stay plain text.
  let num = if lower(prefix) == "arxiv" { link("https://arxiv.org/abs/" + ep)[#ep] } else { ep }
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
#let blx-tail(e, url-always: false) = {
  let items = ()
  // print url when no doi, OR when the per-entry `distinctURL` field is set and not
  // "0" (matches the .bst's `distinctURL empty.or.zero not`; field keys are lowercased
  // at parse time, so only "distincturl" can occur).
  let distinct-url = has(e, "distincturl") and fld(e, "distincturl") != "0"
  if url-always or (not has(e, "doi")) or distinct-url {
    let u = blx-url-urldate(e)
    if u != none { items.push(u) }
  }
  let ep = blx-eprint(e)
  if ep != none { items.push(ep) }
  let doi = blx-doi(e)
  if doi != none { items.push(doi) }
  items
}

#let blx-person-label(e, editor-ok: true, org-ok: true, key-ok: true) = {
  if has(e, "author") { return (c: render(join-names(e.names.author)), kind: "author") }
  if editor-ok and has(e, "editor") {
    let suffix = if e.names.editor.len() > 1 { ", (Eds.)" } else { ", (Ed.)" }
    return (c: render(join-names(e.names.editor)) + suffix, kind: "editor")
  }
  if org-ok and has(e, "organization") { return (c: render(fld(e, "organization")), kind: "organization") }
  if key-ok and has(e, "key") { return (c: render(fld(e, "key")), kind: "key") }
  none
}
#let blx-lead(e, style: "numeric", suffix: "", editor-ok: true, org-ok: true, key-ok: true) = {
  let who = blx-person-label(e, editor-ok: editor-ok, org-ok: org-ok, key-ok: key-ok)
  let dt = blx-date(e, full: style == "author-year", suffix: suffix)
  if who == none { return if style == "numeric" { dt } else { none } }
  let sep = if style == "numeric" and who.kind == "editor" { " " } else { ". " }
  (c: who.c + sep + dt.c, p: false)
}
#let blx-inbook-lead(e, style: "numeric", suffix: "") = {
  // acmnumeric.bbx/acmauthoryear.bbx use \iffieldundef{author} here, not
  // \ifnameundef{author}. Since author is a name list rather than a literal
  // field, real BibLaTeX takes the "author undefined" branch even when the .bib
  // entry has an author name. Mirror that visible behavior: byeditor+others is
  // the only name lead in this ACM inbook driver.
  if has(e, "editor") {
    // acmnumeric.bbx then prints the year; acmauthoryear.bbx does not.
    let c = "Ed. by " + render(join-names(e.names.editor))
    if style == "numeric" { c += ". " + blx-date(e, suffix: suffix).c }
    return (c: c, p: false)
  }
  if style == "numeric" { blx-date(e, suffix: suffix) } else { none }
}
// a rendered value carries visible text (drives block/swids filtering)
#let blx-nonempty(v) = v != none and v.c != none and v.c != [] and v.c != ""
#let blx-blocks(..vals) = {
  let pieces = vals.pos().filter(blx-nonempty)
  let out = []
  for (i, v) in pieces.enumerate() {
    if i > 0 { out += " " }
    out += v.c
    if not v.p { out += "." }
  }
  out
}
#let blx-article-like(e, style: "numeric", suffix: "") = blx-blocks(
  blx-lead(e, style: style, suffix: suffix),
  blx-title-field(e, style: style),
  blx-bytranslator(e),
  blx-journal(e),
  blx-note(e),
  ..blx-tail(e),
)
#let blx-inproceedings(e, style: "numeric", suffix: "") = {
  let title-led = style == "author-year" and not has(e, "author") and not has(e, "editor") and not has(e, "organization") and has(e, "title")
  blx-blocks(
    if title-led { none } else { blx-lead(e, style: style, suffix: suffix, key-ok: false) },
    blx-title-field(e, style: style),
    blx-bytranslator(e),
    blx-booktitle(e, with-in: true, style: style),
    blx-editor-block(e, style: style),
    blx-volume(e),
    blx-list-field(e, "organization"),
    blx-publisher-pages(e),
    blx-isbn(e),
    ..blx-tail(e),
  )
}
#let blx-incollection(e, style: "numeric", suffix: "") = blx-blocks(
  blx-lead(e, style: style, suffix: suffix),
  blx-title-field(e, style: style),
  blx-bytranslator(e),
  blx-booktitle-simple(e, with-in: true, style: style),
  blx-series-number(e, style: style),
  blx-edition(e),
  blx-volume(e),
  blx-volumes(e),
  blx-editor-block(e, style: style),
  blx-note(e),
  blx-publisher-pages(e),
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
    blx-publisher-location-date(e),
    blx-chapter-pages(e),
    blx-isbn(e),
    ..blx-tail(e),
  )
}
#let blx-book-like(e, style: "numeric", suffix: "") = blx-blocks(
  blx-lead(e, style: style, suffix: suffix),
  blx-title-field(e, style: style),
  blx-bytranslator(e),
  blx-edition(e),
  blx-series-number(e, style: style),
  blx-volume(e),
  blx-volumes(e),
  blx-note(e),
  blx-publisher-pages(e),
  blx-isbn(e),
  ..blx-tail(e),
)
#let blx-online(e, style: "numeric", suffix: "") = {
  let who = blx-person-label(e, key-ok: false)
  let lead = if who == none {
    if style == "numeric" { blx-date(e, suffix: suffix) } else { none }
  } else { blx-lead(e, style: style, suffix: suffix, key-ok: false) }
  blx-blocks(
    lead,
    blx-title-field(e, style: style),
    blx-bytranslator(e),
    fV(e, "howpublished"),
    fV(e, "version"),
    blx-note(e),
    blx-list-field(e, "organization"),
    blx-eprint-date(e),
    blx-eprint(e),
    blx-doi(e),
    blx-url-urldate(e),
  )
}
#let blx-presentation(e, style: "numeric", suffix: "") = blx-blocks(
  blx-lead(e, style: style, suffix: suffix, key-ok: false),
  blx-title-field(e, style: style, format: "plain"),
  blx-date-parens(e),
  ..blx-tail(e),
)
#let blx-institution-location(e) = {
  let inst = blx-list-field(e, "school", "institution")
  let loc = blx-list-field(e, "location", "address")
  if inst != none and loc != none { (c: inst.c + ", " + loc.c, p: false) }
  else if inst != none { inst }
  else { loc }
}
#let blx-report(e, style: "numeric", suffix: "", thesis: false) = {
  let ty = if thesis {
    if has(e, "type") { fV(e, "type") } else if e.entry-type == "phdthesis" { (c: "Ph.D. Dissertation", p: false) } else { (c: "Master\u{2019}s thesis", p: false) }
  } else if has(e, "type") and has(e, "number") { (c: render(fld(e, "type")) + " " + render(fld(e, "number")), p: false) }
  else if has(e, "type") { fV(e, "type") }
  else { none }
  blx-blocks(
    blx-lead(e, style: style, suffix: suffix, editor-ok: false, org-ok: false),
    blx-title-field(e, style: style),
    ty,
    fV(e, "version"),
    blx-institution-location(e),
    blx-note(e),
    blx-chapter-pages(e),
    ..blx-tail(e),
  )
}

#let blx-patent(e, style: "numeric", suffix: "") = {
  let locations = if has(e, "location") {
    split-list-and(fld(e, "location"), trim: true, filter-empty: true).map(render).join(", ")
  } else if has(e, "address") {
    split-list-and(fld(e, "address"), trim: true, filter-empty: true).map(render).join(", ")
  } else { none }
  let identification = []
  if has(e, "type") { identification += render(fld(e, "type")) }
  if has(e, "number") {
    if identification != [] { identification += " " }
    identification += "Patent No. " + render(fld(e, "number"))
  }
  if locations != none and locations != [] {
    identification += " (" + locations + ")"
  }
  let holder = if has(e, "holder") {
    (c: render(join-names(e.names.holder)), p: false)
  } else { none }
  let lead = if style == "author-year" and has(e, "author") {
    (c: render(join-names(e.names.author)) + ". " + blx-print-full-date(e) + suffix, p: false)
  } else {
    blx-lead(e, style: style, suffix: suffix, editor-ok: false, org-ok: false, key-ok: false)
  }
  blx-blocks(
    lead,
    blx-title-field(e, style: style),
    (c: "(" + blx-print-full-date(e) + ")", p: false),
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

// acmnumeric.bbx/acmauthoryear.bbx DeclareStyleSourcemap.
#let blx-acm-sourcemap(db) = {
  let out = (:)
  for (k, e0) in db {
    let e = e0
    if e.entry-type == "techreport" { e = e + (entry-type: "report") }
    else if e.entry-type == "artifactsoftware" { e = e + (entry-type: "software") }
    else if e.entry-type == "artifactdataset" { e = e + (entry-type: "dataset") }
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

#let blx-software-can-inherit(parent, child) = {
  if parent == "software" { child in ("softwareversion", "softwaremodule", "codefragment") }
  else if parent == "softwareversion" { child in ("softwaremodule", "codefragment") }
  else if parent == "softwaremodule" { child == "codefragment" }
  else { false }
}

// software.dbx DeclareDataInheritance, resolved recursively so a codefragment
// inherits through softwareversion to the top-level software project.
#let blx-software-inherit-entry(db, key, seen: ()) = {
  let e = blx-fill-date-fields(blx-software-sourcemap-entry(db.at(key)))
  if e.entry-type not in blx-software-types or not has(e, "crossref") { return e }
  let xr = fld(e, "crossref")
  if xr not in db or xr in seen { return e }
  let parent = blx-software-inherit-entry(db, xr, seen: seen + (key,))
  if not blx-software-can-inherit(parent.entry-type, e.entry-type) { return e }
  for (fk, fv) in parent.fields {
    if fk == "crossref" { continue }
    if fk not in e.fields {
      e.fields.insert(fk, fv)
      if fk == "author" or fk == "editor" { e.names.insert(fk, parse-names(fv)) }
    }
  }
  e
}

#let blx-biber-datamodel(db) = {
  let mapped = blx-acm-sourcemap(db)
  let out = (:)
  for (k, e) in mapped {
    let r = if e.entry-type in blx-software-types {
      blx-software-inherit-entry(mapped, k)
    } else {
      blx-fill-date-fields(e)
    }
    out.insert(k, r)
  }
  out
}

#let blx-list-content(raw) = {
  let parts = split-list-and(raw, trim: true, filter-empty: true).map(render)
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

#let blx-printlist(e, name) = if has(e, name) {
  (c: blx-list-content(fld(e, name)), p: false)
} else { none }

#let blx-sw-version(e) = if has(e, "version") { " version " + render(fld(e, "version")) } else { [] }
#let blx-sw-editor(e) = if has(e, "editor") {
  [ (Coord.by #render(join-names(e.names.editor)))]
} else { [] }

// software.bbx: \newbibmacro*{swtitleauthoreditoryear}
#let blx-swtitleauthoreditoryear(e) = {
  let c = []
  if has(e, "author") { c += render(join-names(e.names.author)) + ", " }
  c += render(fld(e, "title", d: ""))
  c += blx-sw-version(e)
  c += blx-sw-editor(e)
  let date = blx-printdate(e)
  if has(e, "version") or has(e, "editor") { c += ", " + date } else { c += " " + date }
  (c: c, p: false)
}

#let blx-sw-subtitle(e) = if has(e, "subtitle") {
  "\u{201C}" + render(fld(e, "subtitle")) + ",\u{201D}"
} else { [] }

// software.bbx: \newbibmacro*{swsubtitleauthoreditoryear}
#let blx-swsubtitleauthoreditoryear(e) = {
  let c = []
  if has(e, "author") { c += render(join-names(e.names.author)) + ", " }
  if has(e, "subtitle") { c += blx-sw-subtitle(e) + " part of " }
  c += render(fld(e, "title", d: ""))
  c += blx-sw-version(e)
  c += blx-sw-editor(e)
  let date = blx-printdate(e)
  if has(e, "version") or has(e, "editor") { c += ", " + date } else { c += " " + date }
  (c: c, p: false)
}

// software.bbx: \newbibmacro*{codefragmenttitleauthoreditoryear}
#let blx-codefragmenttitleauthoreditoryear(e) = {
  let c = []
  if has(e, "author") { c += render(join-names(e.names.author)) + ", " }
  if has(e, "subtitle") { c += blx-sw-subtitle(e) + " from " }
  c += render(fld(e, "title", d: ""))
  c += blx-sw-version(e)
  c += blx-sw-editor(e)
  let date = blx-printdate(e)
  if has(e, "version") or has(e, "editor") { c += ", " + date } else { c += " " + date }
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

#let blx-software-driver(e, kind) = {
  let body = if kind == "software" { blx-swtitleauthoreditoryear(e) }
    else if kind == "codefragment" { blx-codefragmenttitleauthoreditoryear(e) }
    else { blx-swsubtitleauthoreditoryear(e) }
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
  else if t == "underreview" {
    blx-blocks(
      blx-lead(e, style: style, suffix: year-suffix),
      blx-title(e, style: style, sentence: style == "numeric"),
      blx-date-parens(e),
      blx-note(e),
      ..blx-tail(e),
    )
  }
  else if t == "inproceedings" or t == "conference" { blx-inproceedings(e, style: style, suffix: year-suffix) }
  else if t == "presentation" { blx-presentation(e, style: style, suffix: year-suffix) }
  else if t == "incollection" { blx-incollection(e, style: style, suffix: year-suffix) }
  else if t == "inbook" { blx-inbook(e, style: style, suffix: year-suffix) }
  else if t == "book" or t == "proceedings" or t == "collection" { blx-book-like(e, style: style, suffix: year-suffix) }
  else if t == "patent" { blx-patent(e, style: style, suffix: year-suffix) }
  else if t in blx-software-types { blx-software-driver(e, t) }
  else if t == "online" or t == "manual" or t == "misc" or t == "game" or t == "video" or t == "artifactdataset" or t == "dataset" or t == "preprint" {
    blx-online(e, style: style, suffix: year-suffix)
  }
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
  else { blx-blocks(blx-lead(e, style: style, suffix: year-suffix), blx-title(e, style: style, sentence: style == "numeric"), ..blx-tail(e)) }
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
