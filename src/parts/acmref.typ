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

#import "bibtex.typ": read-bib

// ---- TeX text ligatures the .bst output relies on -------------------------
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
  (c: tx(fld(e, "bookpages")) + " pages", p: false) } else { none }
// chapter + pages, or just pages
#let format-chapter-pages(e) = {
  if has(e, "chapter") {
    let ty = if has(e, "type") { tx(lower(fld(e, "type"))) } else { "Chapter" }
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
// misc/periodical page count: "N pages" from numpages
#let format-page-count(e) = if has(e, "numpages") {
  (c: fld(e, "numpages") + " pages", p: false) } else { none }

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
// "N pages" when articleno present (numpages, or page-count reduced from pages)
#let format-articleno-numpages(e) = {
  if articleno-of(e) == none { return none }
  if has(e, "numpages") { (c: fld(e, "numpages") + " pages", p: false) } else { none }
}
#let format-journal-block(e) = {
  if not has(e, "journal") { return none }
  let c = it(tx(fld(e, "journal")))
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
  let pre = if has(e, "journal") { it(tx(fld(e, "journal"))) + "." } else { [] }
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

// ---- shared trailing block: note, doi, url --------------------------------
#let strip-doi(d) = {
  let m = d.match(regex("(?i)^https?://(?:dx\.)?doi\.org/(.+)$"))
  if m != none { m.captures.at(0) } else { d }
}
#let trailing(e) = {
  let items = ()
  if has(e, "note") {
    let n = tx(fld(e, "note"))
    items.push(if ends-punct(fld(e, "note")) { n } else { n + "." })
  }
  if has(e, "eprint") {
    let cls = if has(e, "primaryclass") { fld(e, "primaryclass") } else if has(e, "eprintclass") { fld(e, "eprintclass") } else { none }
    items.push("arXiv:" + fld(e, "eprint") + (if cls != none { " [" + cls + "]" } else { "" }))
  }
  if has(e, "doi") { items.push("doi:" + strip-doi(fld(e, "doi"))) }
  if has(e, "url") and not has(e, "doi") {
    let u = fld(e, "url")
    let r = if has(e, "lastaccessed") { "Retrieved " + tx(fld(e, "lastaccessed")) + " from " + u } else { u }
    if has(e, "archived") { r = r + ", archived at [" + fld(e, "archived") + "]" }
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
#let lead-author-year(em, e) = {
  em = out(em, format-authors(e), variant: "norm")
  if not has(e, "author") and has(e, "editor") { em = out(em, format-editors(e)) }
  em = out-year(em, year-value(e))
  em
}

#let handle(e) = {
  let t = e.entry-type
  let em = em-init
  // aliases
  let manual-like = ("online", "game", "video", "artifactsoftware", "artifactdataset", "software", "dataset", "preprint", "manual")
  if t == "article" or t == "underreview" {
    em = lead-author-year(em, e)
    em = nblock(em)
    em = out(em, format-articletitle(e))
    em = nblock(em)
    if t == "underreview" { em = out(em, format-journal-underreview(e)) }
    else {
      em = out(em, format-journal-block(e))
      em = out(em, format-pages-noart(e))
      em = out(em, format-articleno-numpages(e))
    }
  } else if t == "book" or t == "inbook" {
    if has(e, "author") { em = out(em, format-authors(e)) } else { em = out(em, format-editors(e)) }
    em = out-year(em, year-value(e))
    em = nblock(em)
    em = out(em, format-btitle(e))
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
    } else if not has(e, "pages") { em = out(em, format-bookpages(e)) }
    else { em = out(em, format-pages(e)) }
  } else if t == "incollection" {
    em = lead-author-year(em, e)
    em = nblock(em)
    em = out(em, format-articletitle(e))
    em = nblock(em)
    em = out(em, format-in-ed-booktitle(e))
    em = nsentence(em)
    em = out(em, format-bvolume(e))
    em = out(em, format-number-series(e))
    em = nsentence(em)
    em = out(em, if has(e, "publisher") { V(fld(e, "publisher")) } else { none })
    em = out(em, if has(e, "address") { V(fld(e, "address")) } else { none })
    em = out(em, format-bookpages(e))
    em = out(em, format-chapter-pages(e))
  } else if t == "inproceedings" or t == "conference" or t == "presentation" {
    em = lead-author-year(em, e)
    em = nblock(em)
    em = out(em, format-articletitle(e))
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
    em = out(em, format-pages-noart(e))
    em = out(em, format-articleno-numpages(e))
  } else if t == "mastersthesis" or t == "phdthesis" {
    em = lead-author-year(em, e)
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
    em = out-year(em, year-value(e))
    em = nsentence(em)
    em = out(em, format-articletitle(e))
    em = nblock(em)
    em = out(em, format-journal-block(e))
    em = out(em, format-page-count(e))
  } else if t == "proceedings" or t == "collection" {
    if has(e, "editor") { em = out(em, format-editors(e)) }
    else if has(e, "organization") { em = out(em, V(fld(e, "organization"))) }
    em = out-year(em, year-value(e))
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
    em = lead-author-year(em, e)
    em = nblock(em)
    em = out(em, format-btitle(e))
    em = nblock(em)
    em = out(em, format-tr-number(e))
    em = nsentence(em)
    em = out(em, if has(e, "institution") { V(fld(e, "institution")) } else { none })
    em = out(em, if has(e, "address") { V(fld(e, "address")) } else { none })
    em = nsentence(em)
    em = out(em, if has(e, "pages") { (c: dashify(fld(e, "pages")) + " pages", p: false) } else { none })
  } else if t == "misc" or t == "booklet" {
    em = lead-author-year(em, e)
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
    em = out-year(em, year-value(e))
    em = nblock(em)
    em = out(em, format-btitle(e))
    em = nblock(em)
    em = out(em, if has(e, "organization") { V(fld(e, "organization")) } else { none })
    em = out(em, if has(e, "address") { V(fld(e, "address")) } else { none })
  } else {
    // fallback: author. year. title.
    em = lead-author-year(em, e)
    em = nblock(em)
    em = out(em, format-title(e))
  }
  em-render(em, trailing(e))
}

// ---- sort key + cite/number layer -----------------------------------------
#let sort-key(e) = {
  let ppl = e.names.at("author", default: e.names.at("editor", default: ()))
  let surn = ppl.map(n => lower(n.last)).join(" ")
  let y = if has(e, "year") { fld(e, "year") } else { "" }
  surn + "   " + y + "   " + lower(fld(e, "title", d: ""))
}

#let cited-state = state("acmref-cited", ())
#let bib-path-state = state("acmref-bibpath", none)

// accept a single path or a list of paths; later files override earlier keys
#let read-merged(paths) = {
  let ps = if type(paths) == array { paths } else { (paths,) }
  let db = (:)
  for p in ps { db = db + read-bib(p) }
  db
}

#let ordered-keys() = {
  let db = read-merged(bib-path-state.final())
  let keys = cited-state.final().filter(k => k in db)
  keys.sorted(key: k => sort-key(db.at(k)))
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

#let bbl-cite(..keys) = {
  let ks = keys.pos()
  cited-state.update(cur => {
    for k in ks { if k not in cur { cur.push(k) } }
    cur
  })
  context {
    let order = ordered-keys()
    let nums = ks.map(k => order.position(x => x == k)).filter(p => p != none).map(p => p + 1)
    if nums.len() == 0 { [[?]] } else { [[#collapse(nums)]] }
  }
}

#let bbl-bibliography(path, title: [References], size: 8pt, leading: auto) = {
  bib-path-state.update(path)
  context {
    let db = read-merged(path)
    let order = ordered-keys()
    set text(size: size)
    set par(justify: true, first-line-indent: 0pt, leading: if leading == auto { 0.65em } else { leading })
    heading(level: 1, numbering: none, outlined: false, title)
    for (i, key) in order.enumerate() {
      grid(columns: (2.4em, 1fr), gutter: 0pt,
        [[#(i + 1)]], handle(db.at(key)))
      v(0.2em, weak: true)
    }
  }
}
