// ACM-Reference-Format as Typst code — a faithful port of ACM-Reference-Format.bst
// (the "bst" bibliography backend). Reproduces the *visible* reference text the
// .bst produces (pdftotext strips all \bibinfo/\href tagging, so we model only
// what renders). Validated entry-by-entry against the bibtex .bbl oracle.
//
// Structure mirrors the .bst:
//   * an output state machine (before/mid/sentence/block) with add.period$,
//   * format.* helpers returning (c: content, p: ends-in-.?!),
//   * one handler per entry type assembling helper outputs,
//   * a shared trailing block (note -> doi -> url; isbn/issn/etc. render
//     invisibly in acmsmall and are omitted),
//   * sort + cite/number layer using native state/metadata/query.

#import "bibtex.typ": read-bib, parse-names
#import "bib-data.typ": journal-canon

// ACM journal.canon.abbrev: map a full journal name to its canonical abbreviation
#let canon-abbrev(j) = journal-canon.at(j, default: j)

// ---- TeX text ligatures the .bst output relies on -------------------------
// (TeX accents \"o etc. are already decoded in the parser, before name tokenizing.)
#let tx(s) = {
  if type(s) != str { return s }
  // strip the few TeX macros that survive parsing into field values
  s = s.replace(regex("\\\\(?:url|href|emph|text(?:bf|it|sc|rm))\s*\{([^}]*)\}"), m => m.captures.at(0))
  s = s.replace("\\LaTeX", "LaTeX").replace("\\TeX", "TeX").replace("\\BibTeX", "BibTeX")
  s = s.replace("~", " ").replace("\\&", "&").replace("\\ ", " ").replace("\\,", "\u{2009}")
  s = s.replace("{", "").replace("}", "")   // drop remaining grouping braces ({ACM} -> ACM)
  s = s.replace("---", "\u{2014}").replace("--", "\u{2013}")
  s = s.replace("``", "\u{201C}").replace("''", "\u{201D}")
  s = s.replace("`", "\u{2018}").replace("'", "\u{2019}")
  s
}

// tex string -> content, turning \url{U} / \href{U}{T} into real Typst links
// (acmart loads hyperref, so these are clickable in LaTeX too). Link targets and
// \url display text stay verbatim (no tx — URLs keep ~, etc.).
#let txc(s) = {
  if type(s) != str { return s }
  let out = []
  let rest = s
  let re = regex("\\\\url\s*\{([^}]*)\}|\\\\href\s*\{([^}]*)\}\s*\{([^}]*)\}")
  while true {
    let m = rest.match(re)
    if m == none { out = out + tx(rest); break }
    out = out + tx(rest.slice(0, m.start))
    if m.captures.at(0) != none {
      let u = m.captures.at(0)
      out = out + link(u)[#u]
    } else {
      out = out + link(m.captures.at(1))[#tx(m.captures.at(2))]
    }
    rest = rest.slice(m.end)
  }
  out
}
#let ends-punct(s) = {
  let t = s.trim()
  t != "" and t.last() in (".", "!", "?")
}
// a value carried through the emitter: content + whether its text ends in .?!
#let V(text, c: none) = (c: if c == none { tx(text) } else { c }, p: ends-punct(text))
#let it = emph

// ---- output state machine -------------------------------------------------
// state: "before" | "mid" | "block"   (sentence collapses to block)
#let em-init = (pieces: (), state: "before")

#let sep-for(state, variant) = {
  if state == "before" { "first" }
  else if state == "mid" {
    if variant == "dotspace" { "dotspace" }
    else if variant == "remove" { "space" }
    else if variant == "removenospace" { "none" }
    else { "comma" }
  } else { "block" }
}

// output a value (none/empty is discarded, like .bst `output`)
#let out(em, v, variant: "norm") = {
  if v == none or v.c == none or v.c == [] or v.c == "" { return em }
  em.pieces.push((sep: sep-for(em.state, variant), c: v.c, p: v.p))
  em.state = "mid"
  em
}
// output.year.check: write previous as-is, year carries a leading space
#let out-year(em, v) = {
  em.pieces.push((sep: "space", c: v.c, p: v.p))
  em.state = "mid"
  em
}
#let nblock(em) = { if em.state != "before" { em.state = "block" }; em }
#let nsentence(em) = { if em.state == "mid" { em.state = "block" }; em }

// render the body pieces, then append trailing items (each space-joined,
// self-punctuating), per fin.block + writeln-based trailing block.
#let em-render(em, trailing) = {
  let r = []
  for (i, pc) in em.pieces.enumerate() {
    if i == 0 { r += pc.c } else {
      let prev = em.pieces.at(i - 1)
      if pc.sep == "comma" { r += ", " }
      else if pc.sep == "dotspace" { r += ". " }
      else if pc.sep == "space" { r += " " }
      else if pc.sep == "none" { }
      else if pc.sep == "block" { if not prev.p { r += "." }; r += " " }
      r += pc.c
    }
  }
  // body terminal period (fin.block / fin.entry)
  let last-punct = if em.pieces.len() > 0 { em.pieces.at(-1).p } else { true }
  if not last-punct { r += "." }
  for t in trailing { r += " " + t }   // note/doi/url, each self-punctuating
  r
}

// ---- field access ---------------------------------------------------------
#let fld(e, name, d: none) = e.fields.at(name, default: d)
#let has(e, name) = name in e.fields and e.fields.at(name).trim() != ""
#let articleno-of(e) = if has(e, "articleno") { fld(e, "articleno") } else if has(e, "eid") { fld(e, "eid") } else { none }

// ---- names ----------------------------------------------------------------
#let is-others(n) = n.last == "others" and n.first == "" and n.von == ""
#let one-name(n) = (n.first, n.von, n.last).filter(p => p != "").join(" ") + (
  if n.jr != "" { ", " + n.jr } else { "" })

// format.names: list authors/editors in "First von Last, Jr" order
#let join-names(people) = {
  let n = people.len()
  let out = ""
  for (i, person) in people.enumerate() {
    let nm = if is-others(person) { "et al." } else { one-name(person) }
    if i == 0 { out = nm }
    else if i < n - 1 { out = out + ", " + nm }
    else {
      if n > 2 { out = out + "," }
      out = out + (if is-others(person) { " " } else { " and " }) + nm
    }
  }
  out
}

#let format-authors(e) = {
  if not has(e, "author") { return none }
  let s = join-names(e.names.author)
  if not ends-punct(s) { s = s + "." }
  V(s)
}
#let format-editors(e) = {     // label position: trailing " (Ed.)."/" (Eds.)."
  if not has(e, "editor") { return none }
  let s = join-names(e.names.editor) + (if e.names.editor.len() > 1 { " (Eds.)." } else { " (Ed.)." })
  V(s)
}
#let format-editors-fml(e) = { // inline after booktitle: no trailing period
  if not has(e, "editor") { return none }
  V(join-names(e.names.editor) + (if e.names.editor.len() > 1 { " (Eds.)" } else { " (Ed.)" }))
}

// ---- titles ---------------------------------------------------------------
#let format-articletitle(e) = if has(e, "title") { V(fld(e, "title")) } else { none }
#let format-title(e) = if has(e, "title") { V(fld(e, "title")) } else { none }
#let format-title-emph(e) = if has(e, "title") {
  (c: it(tx(fld(e, "title"))), p: ends-punct(fld(e, "title")))
} else { none }

// emph(title) + " (Nth ed.)"  — for book/proceedings btitle & booktitle
#let title-with-edition(e, raw) = {
  if raw == none or raw.trim() == "" { return none }
  let body = it(tx(raw))
  if has(e, "edition") {
    let ed = lower(fld(e, "edition"))
    (c: body + " (" + tx(ed) + " ed.)", p: false)
  } else { (c: body, p: ends-punct(raw)) }
}
#let format-btitle(e) = title-with-edition(e, fld(e, "title"))
#let format-emph-booktitle(e) = title-with-edition(e, fld(e, "booktitle"))

// ---- volume / number / series ---------------------------------------------
#let format-bvolume(e) = {
  if not has(e, "volume") { return none }
  if has(e, "series") { V("\u{200B}", c: fld(e, "series") + ", Vol.\u{00A0}" + fld(e, "volume")) }
  else { V("\u{200B}", c: "Vol.\u{00A0}" + fld(e, "volume")) }
}
#let format-bvolume-noseries(e) = if has(e, "volume") {
  (c: "Vol.\u{00A0}" + fld(e, "volume"), p: false)
} else { none }
#let format-number-series(e) = {
  // Per the .bst: a lone series (no volume, no number) is NOT shown here — only
  // "Number <n> in <series>" when a number is present and volume is absent.
  if has(e, "volume") { return none }
  if has(e, "number") and has(e, "series") {
    (c: "Number " + fld(e, "number") + " in " + tx(fld(e, "series")), p: false)
  } else { none }
}

// format.series: " (series)" / " (series, number)" / " (series, Vol. N)" (emph), leading space
#let format-series(e) = {
  if not has(e, "series") { return none }
  let inner = tx(fld(e, "series"))
  if has(e, "volume") { inner = inner + ", Vol.\u{00A0}" + fld(e, "volume") }
  else if has(e, "number") { inner = inner + ", " + fld(e, "number") }
  (c: " " + it("(" + inner + ")"), p: false)
}

// ---- pages ----------------------------------------------------------------
#let dashify(s) = s.replace("--", "\u{2013}").replace("-", "\u{2013}")
#let format-pages(e) = if has(e, "pages") { (c: dashify(fld(e, "pages")), p: false) } else { none }
#let format-bookpages(e) = if has(e, "bookpages") {
  (c: tx(fld(e, "bookpages")) + " book pages", p: false) } else { none }
// chapter + pages, or just pages
// change.case$ "t": first char of the string upper, the rest lower
#let title-case(s) = if s == "" { s } else { upper(s.slice(0, 1)) + lower(s.slice(1)) }
#let format-chapter-pages(e) = {
  if has(e, "chapter") {
    let ty = if has(e, "type") { tx(title-case(fld(e, "type"))) } else { "Chapter" }
    let r = ty + " " + fld(e, "chapter")
    if has(e, "pages") { r = r + ", " + dashify(fld(e, "pages")) }
    (c: r, p: false)
  } else { format-pages(e) }
}
// pages when no articleno (acmsmall: numpages-only -> "N pages")
#let format-pages-noart(e) = {
  if articleno-of(e) != none { none }
  else if has(e, "pages") { format-pages(e) }
  else if has(e, "numpages") { (c: fld(e, "numpages") + " pages", p: false) }
  else { none }
}
// reduce.pages.to.page.count: numpages wins; else parse the first three numbers of
// `pages` — a bare "1--N" range reduces to N (its page count), anything else
// (n:1--n:m, 5--12, ...) stays verbatim. (The .bst's second `if` overwrites the
// first, so only the "1--N" case actually reduces.)
#let reduce-pages(e) = {
  if has(e, "numpages") { return fld(e, "numpages") }
  if not has(e, "pages") { return none }
  let p = fld(e, "pages")
  let nums = p.matches(regex("[0-9]+"))
  let p1 = if nums.len() > 0 { nums.at(0).text } else { none }
  let p3 = if nums.len() > 2 { nums.at(2).text } else { none }
  if p1 == "1" and p3 == none { nums.at(1).text } else { p }
}
// calc.format.page.count: "<count> pages" (misc/periodical/articleno paths)
#let format-page-count(e) = {
  let c = reduce-pages(e)
  if c == none { none } else { (c: dashify(c) + " pages", p: false) }
}

// ---- date / journal -------------------------------------------------------
#let format-day-month-year(e) = {
  // optional ", Article N" prefix, then " (month year)" / " (day month year)"
  let art = articleno-of(e)
  let pre = if art != none { ", Article " + art } else { "" }
  if not has(e, "month") {
    if has(e, "year") { (c: pre + " (" + fld(e, "year") + ")", p: false) }
    else if art != none { (c: pre, p: false) } else { none }
  } else {
    let d = if has(e, "day") { fld(e, "day") + " " } else { "" }
    (c: pre + " (" + tx(fld(e, "month")) + " " + d + fld(e, "year") + ")", p: false)
  }
}
// "N pages" when articleno present (numpages, or reduced from pages)
#let format-articleno-numpages(e) = {
  if articleno-of(e) == none { return none }
  format-page-count(e)
}
#let format-journal-block(e) = {
  if not has(e, "journal") { return none }
  let c = it(tx(canon-abbrev(fld(e, "journal"))))
  if has(e, "number") {
    c = c + " " + fld(e, "volume") + ", " + fld(e, "number")
  } else if has(e, "volume") {
    c = c + " " + fld(e, "volume")
  }
  let dmy = format-day-month-year(e)
  if e.entry-type != "inproceedings" and dmy != none { c = c + dmy.c }
  (c: c, p: false)
}
#let format-journal-underreview(e) = {
  let pre = if has(e, "journal") { it(tx(canon-abbrev(fld(e, "journal")))) + "." } else { [] }
  (c: pre + " Manuscript submitted for review", p: false)
}

// ---- "In booktitle (city)" variants ---------------------------------------
#let format-city(e, prev-empty) = {
  if prev-empty { return "" }
  let loc = if has(e, "location") { fld(e, "location") } else if has(e, "city") { fld(e, "city") } else { none }
  let date = if has(e, "date") { fld(e, "date") } else { none }
  if loc == none and date == none { "" }
  else if loc == none { " (" + tx(date) + ")" }
  else if date == none { " (" + tx(loc) + ")" }
  else { " (" + tx(loc) + ", " + tx(date) + ")" }
}
#let format-in-emph-booktitle(e) = {
  let bt = format-emph-booktitle(e)
  if bt == none { return none }
  (c: [In ] + bt.c + format-city(e, false), p: false)
}
#let format-in-ed-booktitle(e) = {
  let bt = format-emph-booktitle(e)
  if bt == none { return none }
  let c = [In ] + bt.c + format-city(e, false)
  if has(e, "editor") {
    c = c + ", " + join-names(e.names.editor) + (if e.names.editor.len() > 1 { " (Eds.)" } else { " (Ed.)" })
  }
  (c: c, p: false)
}
#let format-venue(e) = if has(e, "venue") {
  (c: "Presentation at " + tx(fld(e, "venue")), p: false) } else { none }

// ---- thesis / techreport --------------------------------------------------
#let format-thesis-type(e, default) = (c: tx(if has(e, "type") { fld(e, "type") } else { default }), p: ends-punct(if has(e, "type") { fld(e, "type") } else { default }))
#let format-tr-number(e) = {
  let ty = if has(e, "type") { tx(fld(e, "type")) } else { "Technical Report" }
  if has(e, "number") { (c: ty + " " + fld(e, "number"), p: false) }
  else { (c: ty, p: ends-punct(ty)) }
}
#let format-advisor(e) = if has(e, "advisor") {
  V("Advisor(s) " + fld(e, "advisor")) } else { none }

// ---- crossref ("See [N]") --------------------------------------------------
// `xref-cite` is the rendered citation of the crossref'd parent ("[N]" in numeric
// mode), supplied by the context layer once the parent's number is known.
#let von-last(n) = (n.von, n.last).filter(p => p != "").join(" ")
// format.crossref.editor: first editor (von last); " and second" for two, " et al." for >2
#let format-crossref-editor(e) = {
  let eds = e.names.editor
  let s = von-last(eds.at(0))
  if eds.len() > 2 { s + " et al." }
  else if eds.len() == 2 {
    if is-others(eds.at(1)) { s + " et al." } else { s + " and " + von-last(eds.at(1)) }
  } else { s }
}
#let format-article-crossref(e, xref-cite) = (c: [See] + xref-cite, p: false)   // .bst: no space
#let format-incoll-inproc-crossref(e, xref-cite) = (c: [See ] + xref-cite, p: false)
#let format-book-crossref(e, xref-cite) = {
  // "Volume N of <ed/key/series> [N]" or "In <ed/key/series> [N]"
  let pre = if has(e, "volume") { [Volume #fld(e, "volume") of ] } else { [In ] }
  let ed-empty = not has(e, "editor") or fld(e, "editor") == fld(e, "author", d: "\u{0}")
  let mid = if ed-empty {
    if has(e, "key") { tx(fld(e, "key")) }
    else if has(e, "series") { it(tx(fld(e, "series"))) }
    else { [] }
  } else { format-crossref-editor(e) }
  (c: pre + mid + [ ] + xref-cite, p: false)
}

// ---- shared trailing block: note, doi, url --------------------------------
// .bst strip.doi: bare DOIs start "10."; otherwise drop any scheme + host, keeping
// the path (http://doi.acm.org/10.1145/X -> 10.1145/X).
#let strip-doi(d) = {
  if d.starts-with("10.") { return d }
  let s = d.replace(regex("(?i)^https?://"), "")
  let parts = s.split("/")
  if parts.len() <= 1 { d } else { parts.slice(1).join("/") }
}
// arXiv eprint per acmart's \showeprint: "arXiv:" + linked number + " [class]"
// for arxiv-family prefixes, else plain "prefix:eprint".
#let format-eprint(e) = {
  let ep = fld(e, "eprint")
  let prefix = fld(e, "archiveprefix", d: if has(e, "eprinttype") { fld(e, "eprinttype") } else { "arxiv" })
  let cls = if has(e, "primaryclass") { fld(e, "primaryclass") } else if has(e, "eprintclass") { fld(e, "eprintclass") } else { none }
  let suffix = if cls != none { " [" + cls + "]" } else { "" }
  if lower(prefix) == "arxiv" {
    [arXiv:#link("https://arxiv.org/abs/" + ep)[#ep]#suffix]
  } else {
    [#prefix:#ep#suffix]
  }
}

// shared trailing block: note, eprint, doi, url — each self-punctuating, with real
// hyperlinks (acmart renders these via hyperref \href/\url/\showeprint).
#let trailing(e) = {
  let items = ()
  if has(e, "note") {
    let n = txc(fld(e, "note"))
    items.push(if ends-punct(fld(e, "note")) { n } else { n + [.] })
  }
  if has(e, "issue") { items.push("Issue " + fld(e, "issue") + ".") }
  if has(e, "eprint") { items.push(format-eprint(e)) }
  if has(e, "doi") {
    let bare = strip-doi(fld(e, "doi"))
    items.push(link("https://doi.org/" + bare)[doi:#bare])
  }
  // output.url: print url when no doi, OR when the per-entry `distinctURL` field
  // is present and not "0" (the .bst's `distinctURL empty.or.zero not`).
  let distinct-url = has(e, "distincturl") and fld(e, "distincturl") != "0"
  if has(e, "url") and (not has(e, "doi") or distinct-url) {
    let u = fld(e, "url")
    let r = if has(e, "lastaccessed") { [Retrieved #tx(fld(e, "lastaccessed")) from #link(u)[#u]] } else { link(u)[#u] }
    if has(e, "archived") { r = r + [, archived at \[#link(fld(e, "archived"))[#fld(e, "archived")]\]] }
    items.push(r)
  }
  items
}

// ---- year piece -----------------------------------------------------------
#let year-value(e) = {
  let y = if has(e, "year") { fld(e, "year") } else if has(e, "date") { fld(e, "date").slice(0, 4) } else { "[n.d.]" }
  (c: y, p: false)
}

// ---- per-entry-type handlers ----------------------------------------------
#let howpub(e) = if has(e, "howpublished") { V(fld(e, "howpublished")) } else { none }

#let lead-author-year(em, e, ysuf) = {
  em = out(em, format-authors(e), variant: "norm")
  if not has(e, "author") and has(e, "editor") { em = out(em, format-editors(e)) }
  // format.key fallback: an author-less entry shows its `key` field in that slot
  if not has(e, "author") and not has(e, "editor") and has(e, "key") { em = out(em, V(fld(e, "key"))) }
  em = out-year(em, ysuf(year-value(e)))
  em
}

// `xref-cite`: rendered parent citation when the entry keeps a `crossref` (parent
// is in the bibliography); `year-suffix`: \natexlab a/b/c disambiguator (author-year).
// The suffix attaches ONLY to the lead `output.year.check` year (verified against
// bibtex: an article's later "(2020)" journal date is NOT disambiguated).
#let handle(e, xref-cite: none, year-suffix: "") = {
  // append the \natexlab suffix to the lead year value (no-op in numeric mode)
  let ysuf = v => if year-suffix == "" { v } else { (c: v.c + year-suffix, p: v.p) }
  let lead = (em, e) => lead-author-year(em, e, ysuf)
  let has-xref = has(e, "crossref") and xref-cite != none
  let t = e.entry-type
  let em = em-init
  // aliases
  let manual-like = ("online", "game", "video", "artifactsoftware", "artifactdataset", "software", "dataset", "preprint", "manual")
  if t == "article" or t == "underreview" {
    em = lead(em, e)
    em = nblock(em)
    em = out(em, format-articletitle(e))
    em = nblock(em)
    em = out(em, howpub(e))
    em = nblock(em)
    if t == "underreview" { em = out(em, format-journal-underreview(e)) }
    else {
      if has-xref { em = out(em, format-article-crossref(e, xref-cite)) }
      else { em = out(em, format-journal-block(e)) }
      em = out(em, format-pages-noart(e))
      em = out(em, format-articleno-numpages(e))
    }
  } else if t == "book" or t == "inbook" {
    if has(e, "author") { em = out(em, format-authors(e)) } else { em = out(em, format-editors(e)) }
    em = out-year(em, ysuf(year-value(e)))
    em = nblock(em)
    em = out(em, format-btitle(e))
    if has-xref {
      // inbook prints chapter/pages before the crossref; book does not
      if t == "inbook" {
        em = out(em, format-bookpages(e))
        em = out(em, format-chapter-pages(e))
      }
      em = nblock(em)
      em = out(em, format-book-crossref(e, xref-cite))
    } else {
      em = nsentence(em)
      em = out(em, format-bvolume(e))
      em = nblock(em)
      em = out(em, format-number-series(e))
      em = nsentence(em)
      em = out(em, if has(e, "publisher") { V(fld(e, "publisher")) } else { none })
      em = out(em, if has(e, "address") { V(fld(e, "address")) } else { none })
      if t == "inbook" {
        em = out(em, format-bookpages(e))
        em = out(em, format-chapter-pages(e))
      } else {
        // book: fin.sentence, then bookpages OR "<pages> pages"
        em = nsentence(em)
        if has(e, "pages") { em = out(em, (c: dashify(fld(e, "pages")) + " pages", p: false)) }
        else { em = out(em, format-bookpages(e)) }
      }
    }
  } else if t == "incollection" {
    em = lead(em, e)
    em = nblock(em)
    em = out(em, format-articletitle(e))
    em = nblock(em)
    if has-xref {
      em = out(em, format-incoll-inproc-crossref(e, xref-cite))
      em = out(em, format-chapter-pages(e))
    } else {
      em = out(em, format-in-ed-booktitle(e))
      em = nsentence(em)
      em = out(em, format-bvolume(e))
      em = out(em, format-number-series(e))
      em = nsentence(em)
      em = out(em, if has(e, "publisher") { V(fld(e, "publisher")) } else { none })
      em = out(em, if has(e, "address") { V(fld(e, "address")) } else { none })
      em = out(em, format-bookpages(e))
      em = out(em, format-chapter-pages(e))
    }
  } else if t == "inproceedings" or t == "conference" or t == "presentation" {
    em = lead(em, e)
    em = nblock(em)
    em = out(em, format-articletitle(e))
    em = out(em, howpub(e), variant: "dotspace")
    if has-xref {
      em = out(em, format-incoll-inproc-crossref(e, xref-cite))
    } else {
      if t == "presentation" {
        em = nsentence(em)
        em = out(em, format-venue(e))
      } else {
        em = out(em, format-in-emph-booktitle(e), variant: "dotspace")
      }
      em = out(em, format-series(e), variant: "removenospace")
      em = out(em, format-editors-fml(e))
      if not has(e, "series") { em = out(em, format-bvolume-noseries(e)) }
      em = nsentence(em)
      em = out(em, if has(e, "organization") { V(fld(e, "organization")) } else { none })
      em = out(em, if has(e, "publisher") { V(fld(e, "publisher")) } else { none })
      em = out(em, if has(e, "address") { V(fld(e, "address")) } else { none })
      em = out(em, format-bookpages(e))
    }
    em = out(em, format-pages-noart(e))
    em = out(em, format-articleno-numpages(e))
  } else if t == "mastersthesis" or t == "phdthesis" {
    em = lead(em, e)
    em = nblock(em)
    em = out(em, format-title-emph(e))
    em = nblock(em)
    let default = if t == "phdthesis" { "Ph.\u{2009}D. Dissertation" } else { "Master's thesis" }
    em = out(em, format-thesis-type(e, default))
    em = nsentence(em)
    em = out(em, if has(e, "school") { V(fld(e, "school")) } else { none })
    em = out(em, if has(e, "address") { V(fld(e, "address")) } else { none })
    em = nblock(em)
    em = out(em, format-advisor(e))
  } else if t == "periodical" {
    if has(e, "editor") { em = out(em, format-editors(e)) }
    else if has(e, "organization") { em = out(em, V(fld(e, "organization"))) }
    em = nblock(em)
    em = out-year(em, ysuf(year-value(e)))
    em = nsentence(em)
    em = out(em, format-articletitle(e))
    em = nblock(em)
    em = out(em, format-journal-block(e))
    em = out(em, format-page-count(e))
  } else if t == "proceedings" or t == "collection" {
    // editor, else organization, else `format.key` fallback (org & editor absent)
    if has(e, "editor") { em = out(em, format-editors(e)) }
    else if has(e, "organization") { em = out(em, V(fld(e, "organization"))) }
    else if has(e, "key") { em = out(em, V(fld(e, "key"))) }
    em = out-year(em, ysuf(year-value(e)))
    em = nblock(em)
    let bt = format-btitle(e)
    if bt != none { bt = (c: bt.c + format-city(e, false), p: false) }
    em = out(em, bt)
    em = nsentence(em)
    em = out(em, format-bvolume(e))
    em = out(em, format-number-series(e))
    em = nsentence(em)
    em = out(em, if has(e, "organization") { V(fld(e, "organization")) } else { none })
    em = out(em, if has(e, "publisher") { V(fld(e, "publisher")) } else { none })
    em = out(em, if has(e, "address") { V(fld(e, "address")) } else { none })
  } else if t == "techreport" {
    em = lead(em, e)
    em = nblock(em)
    em = out(em, format-btitle(e))
    em = nblock(em)
    em = out(em, format-tr-number(e))
    em = nsentence(em)
    em = out(em, if has(e, "institution") { V(fld(e, "institution")) } else { none })
    em = out(em, if has(e, "address") { V(fld(e, "address")) } else { none })
    em = nsentence(em)
    em = out(em, if has(e, "pages") { (c: dashify(fld(e, "pages")) + " pages", p: false) } else { none })
  } else if t == "unpublished" {
    em = lead(em, e)
    em = nblock(em)
    em = out(em, format-title(e))          // plain title (not emphasized)
    em = nsentence(em)
    let ymd = format-day-month-year(e)
    if ymd != none { em = out(em, (c: ymd.c.trim(), p: false)) }
    em = out(em, format-page-count(e))
    // note is required for @unpublished and emitted by the shared trailing block
  } else if t == "misc" or t == "booklet" {
    em = lead(em, e)
    em = nblock(em)
    em = out(em, format-title(e))
    em = nblock(em)
    em = out(em, if has(e, "howpublished") { V(fld(e, "howpublished")) } else { none })
    if t == "booklet" { em = out(em, if has(e, "address") { V(fld(e, "address")) } else { none }) }
    else { em = out(em, format-page-count(e)) }
  } else if t in manual-like {
    // manual & friends (online/software/dataset/preprint/...): title + org + address;
    // url/"Retrieved" comes from the shared trailing block.
    if has(e, "author") { em = out(em, format-authors(e)) }
    else if has(e, "editor") { em = out(em, format-editors(e)) }
    else if has(e, "organization") { em = out(em, V(fld(e, "organization"))) }
    else if has(e, "key") { em = out(em, V(fld(e, "key"))) }   // format.key fallback
    em = out-year(em, ysuf(year-value(e)))
    em = nblock(em)
    em = out(em, format-btitle(e))
    em = nblock(em)
    em = out(em, if has(e, "organization") { V(fld(e, "organization")) } else { none })
    em = out(em, if has(e, "address") { V(fld(e, "address")) } else { none })
  } else {
    // fallback: author. year. title.
    em = lead(em, e)
    em = nblock(em)
    em = out(em, format-title(e))
  }
  em-render(em, trailing(e))
}

// ---- sort key + cite/number layer -----------------------------------------
// .bst sort key: alphabetical by author/editor (von last first), then year, then
// title — ties on surname break by given name, like bibtex's label-based presort.
#let sort-key(e) = {
  let ppl = e.names.at("author", default: e.names.at("editor", default: ()))
  let names = ppl.map(n => lower((n.von + " " + n.last + " " + n.first).trim())).join(" ")
  if names == none { names = "" }   // ().join() is none, not ""
  if names == "" and has(e, "key") { names = lower(fld(e, "key")) }
  let y = if has(e, "year") { fld(e, "year") } else { "" }
  names + "   " + y + "   " + lower(fld(e, "title", d: ""))
}

#let cited-state = state("acmref-cited", ())
#let bib-path-state = state("acmref-bibpath", none)
// "numeric" (default) or "author-year" — set by the acmart show rule from the
// `cite-style` option, mirroring acmart's \citestyle{acmnumeric|acmauthoryear}.
#let cite-style-state = state("acmref-citestyle", "numeric")

// accept a single path or a list of paths; later files override earlier keys
#let read-merged(paths) = {
  let ps = if type(paths) == array { paths } else { (paths,) }
  let db = (:)
  for p in ps { db = db + read-bib(p) }
  db
}

// ---- crossref resolution (BibTeX engine behaviour, not the .bst) -----------
// BibTeX (not the .bst) inherits a crossref parent's missing fields into the
// child, and adds the parent to the reference list only when it is crossref'd
// >= min_crossrefs (=2) times or cited directly. A child whose parent IS listed
// renders "See [parent]" (the .bst's format.*.crossref); a child whose parent is
// NOT listed keeps the inherited fields and renders in full (BibTeX strips its
// crossref). Verified against real bibtex (both thresholds + field inheritance).
#let min-crossrefs = 2
#let resolve-crossref(db, cited) = {
  let counts = (:)
  for k in cited {
    if k not in db { continue }
    let xr = db.at(k).fields.at("crossref", default: none)
    if xr != none and xr in db { counts.insert(xr, counts.at(xr, default: 0) + 1) }
  }
  let listed = cited.filter(k => k in db)
  for (xr, c) in counts {
    if c >= min-crossrefs and xr not in listed { listed.push(xr) }
  }
  let db2 = db
  for k in listed {
    let e = db2.at(k)
    let xr = e.fields.at("crossref", default: none)
    if xr == none or xr not in db { continue }
    let parent = db.at(xr)
    for (fk, fv) in parent.fields {
      if fk == "crossref" { continue }
      if fk not in e.fields {
        e.fields.insert(fk, fv)
        if fk == "author" or fk == "editor" { e.names.insert(fk, parse-names(fv)) }
      }
    }
    if xr not in listed { let _ = e.fields.remove("crossref") }   // parent excluded -> full render
    db2.insert(k, e)
  }
  (db: db2, order: listed.sorted(key: k => sort-key(db2.at(k))))
}

// resolved (db, order) for the current cited set
#let prepared() = resolve-crossref(read-merged(bib-path-state.final()), cited-state.final())

// ---- author-year labels (format.lab.names + calc.basic.label dispatch) -----
// short citation label: von+Last only, " and " for two, "et al." for >2 (or "and others")
#let format-lab-names(people) = {
  if people.len() == 0 { return "" }
  if people.len() > 2 { return von-last(people.at(0)) + " et al." }
  let s = von-last(people.at(0))
  if people.len() == 2 {
    if is-others(people.at(1)) { s = s + " et al." } else { s = s + " and " + von-last(people.at(1)) }
  }
  s
}
#let pick(arr) = { let r = arr.find(x => x != none); if r == none { "" } else { r } }
// calc.basic.label's type dispatch: which field supplies the citation label
#let lab-label(e) = {
  let t = e.entry-type
  let au = if has(e, "author") { format-lab-names(e.names.author) }
  let ed = if has(e, "editor") { format-lab-names(e.names.editor) }
  let org = if has(e, "organization") { tx(fld(e, "organization")) }
  let key = if has(e, "key") { tx(fld(e, "key")) }
  let manual-like = ("manual", "online", "game", "video", "artifactsoftware", "artifactdataset", "software", "dataset", "preprint")
  if t in ("book", "inbook", "article") { pick((au, ed, key)) }
  else if t in ("proceedings", "periodical", "collection") { pick((ed, org, key)) }
  else if t in manual-like { pick((au, ed, org, key)) }
  else { pick((au, key)) }
}

// \natexlab a/b/c suffixes: a..z over consecutive (label, year)-equal entries in
// sorted order (forward.pass/reverse.pass); singletons get "".
#let lab-dedup-key(e) = lab-label(e) + "\u{0}" + year-value(e).c
#let extra-labels(db, order) = {
  let res = (:)
  let i = 0
  while i < order.len() {
    let k = lab-dedup-key(db.at(order.at(i)))
    let j = i
    while j < order.len() and lab-dedup-key(db.at(order.at(j))) == k { j += 1 }
    let grp = order.slice(i, j)
    if grp.len() == 1 { res.insert(grp.at(0), "") }
    else { for (m, gk) in grp.enumerate() { res.insert(gk, str.from-unicode(97 + m)) } }
    i = j
  }
  res
}

// cited keys reordered into reference-list (sorted) order
#let cite-order(keys, order) = keys.filter(k => k in order).sorted(key: k => order.position(x => x == k))

// natbib author-year \citep/\citet: group consecutive same-label entries, then
// group their years by base year so suffixes collapse ("2020a,b,c"); ", " between
// distinct years, "; " between author groups. \citet puts years in brackets.
#let cite-ay(keys, db, order, extras, citet: false) = {
  let ks = cite-order(keys, order)
  if ks.len() == 0 { return if citet { "[?]" } else { "[?]" } }
  let lgroups = ()
  for k in ks {
    let lbl = lab-label(db.at(k))
    let yr = (base: year-value(db.at(k)).c, suf: extras.at(k, default: ""))
    if lgroups.len() > 0 and lgroups.at(-1).label == lbl { lgroups.at(-1).years.push(yr) }
    else { lgroups.push((label: lbl, years: (yr,))) }
  }
  let render-years(years) = {
    let ybits = ()
    for y in years {
      if ybits.len() > 0 and ybits.at(-1).base == y.base { ybits.at(-1).sufs.push(y.suf) }
      else { ybits.push((base: y.base, sufs: (y.suf,))) }
    }
    ybits.map(b => b.base + b.sufs.join(",")).join(", ")
  }
  let parts = lgroups.map(g => if citet { g.label + " [" + render-years(g.years) + "]" }
    else { g.label + " " + render-years(g.years) })
  if citet { parts.join("; ") } else { "[" + parts.join("; ") + "]" }
}

// collapse [1,2,3,5] -> "1–3, 5"
#let collapse(nums) = {
  let s = nums.sorted()
  let groups = ()
  for n in s {
    if groups.len() > 0 and n == groups.at(-1).at(-1) + 1 { groups.at(-1).push(n) }
    else { groups.push((n,)) }
  }
  groups.map(g => if g.len() >= 3 { str(g.first()) + "\u{2013}" + str(g.last()) }
    else { g.map(str).join(", ") }).join(", ")
}

#let register-cites(ks) = cited-state.update(cur => {
  for k in ks { if k not in cur { cur.push(k) } }
  cur
})

// numeric: collapsed bracketed numbers; author-year: \citep "[Label Year]"
#let bbl-cite(..keys) = {
  let ks = keys.pos()
  register-cites(ks)
  context {
    let p = prepared()
    if cite-style-state.get() == "author-year" {
      cite-ay(ks, p.db, p.order, extra-labels(p.db, p.order))
    } else {
      let nums = ks.map(k => p.order.position(x => x == k)).filter(x => x != none).map(x => x + 1)
      if nums.len() == 0 { [[?]] } else { [[#collapse(nums)]] }
    }
  }
}

// \citet "Label [Year]" (author-year); falls back to numeric brackets otherwise
#let bbl-citet(..keys) = {
  let ks = keys.pos()
  register-cites(ks)
  context {
    let p = prepared()
    if cite-style-state.get() == "author-year" {
      cite-ay(ks, p.db, p.order, extra-labels(p.db, p.order), citet: true)
    } else {
      let nums = ks.map(k => p.order.position(x => x == k)).filter(x => x != none).map(x => x + 1)
      if nums.len() == 0 { [[?]] } else { [[#collapse(nums)]] }
    }
  }
}

// \citeyear: just the year(s) with suffix; \citeauthor: just the label
#let bbl-citeyear(..keys) = {
  let ks = keys.pos()
  register-cites(ks)
  context {
    let p = prepared()
    let extras = extra-labels(p.db, p.order)
    cite-order(ks, p.order).map(k => year-value(p.db.at(k)).c + extras.at(k, default: "")).join(", ")
  }
}
#let bbl-citeauthor(..keys) = {
  let ks = keys.pos()
  register-cites(ks)
  context {
    let p = prepared()
    cite-order(ks, p.order).map(k => lab-label(p.db.at(k))).join("; ")
  }
}

#let bbl-bibliography(path, title: [References], size: 8pt, leading: auto) = {
  bib-path-state.update(path)
  context {
    let p = prepared()
    let db = p.db
    let order = p.order
    let ay = cite-style-state.get() == "author-year"
    let extras = if ay { extra-labels(db, order) } else { (:) }
    let num-of = (:)
    for (i, k) in order.enumerate() { num-of.insert(k, i + 1) }
    set text(size: size)
    set par(justify: true, first-line-indent: 0pt, leading: if leading == auto { 0.65em } else { leading })
    heading(level: 1, numbering: none, outlined: false, title)
    for (i, key) in order.enumerate() {
      let e = db.at(key)
      // "See [parent]" citation for a child whose parent is in the list
      let xref-cite = none
      let xr = e.fields.at("crossref", default: none)
      if xr != none and xr in num-of {
        xref-cite = if ay { cite-ay((xr,), db, order, extras, citet: true) } else { [[#num-of.at(xr)]] }
      }
      let body = handle(e, xref-cite: xref-cite, year-suffix: extras.at(key, default: ""))
      if ay {
        // author-year list: no numbers, hanging indent (acmart \bibhang)
        block(par(hanging-indent: 1.8em, body))
      } else {
        grid(columns: (2.4em, 1fr), gutter: 0pt, [[#(i + 1)]], body)
      }
      v(0.2em, weak: true)
    }
  }
}
