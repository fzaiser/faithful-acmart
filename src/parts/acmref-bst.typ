// ACM-Reference-Format.bst renderer.
//
// Reproduces the visible reference text produced by ACM-Reference-Format.bst.

#import "bib-data.typ": journal-canon
#import "tex.typ": purify, change-case
#import "acmref-common.typ": render, ends-punct, V, it, fld, has, fV, articleno-of, is-others, join-names, dashify, von-last, year-value

// ACM journal.canon.abbrev: map a full journal name to its canonical abbreviation
#let canon-abbrev(j) = journal-canon.at(j, default: j)

// tie.or.space.connect (bst:1352): join with a non-breaking tie when the SECOND
// operand is short (text.length < 3), otherwise an ordinary space.
#let tie-connect(a, b) = a + (if b.clusters().len() < 3 { "\u{00A0}" } else { " " }) + b

// strip.articleno.or.eid (bst:449): drop a leading "Article"/"article"/"Paper"/
// "paper" and one following space or "~", so articleno = {Article 5} → "5".
#let strip-articleno(t) = {
  for w in ("Article", "article", "Paper", "paper") {
    if t.starts-with(w) { t = t.slice(w.len()) }
  }
  if t.starts-with(" ") { t = t.slice(1) }
  if t.starts-with("~") { t = t.slice("~".len()) }
  t
}
// format.year (bst:503): year, else date[0:4], else "[n.\,d.]" — always something.
#let format-year-str(e) = {
  if has(e, "year") { fld(e, "year") }
  else {
    let date = fld(e, "date", d: "")
    if date.len() >= 4 { date.slice(0, 4) } else { "[n.\u{2009}d.]" }
  }
}

// ---- output state machine -------------------------------------------------
// state: "before" | "mid" | "block"   (sentence collapses to block)
#let em-init = (pieces: (), state: "before")

#let sep-for(state, variant) = {
  if state == "before" { "first" }  // never consulted: em-render emits piece 0 with no separator
  else if state == "mid" {
    if variant == "dotspace" { "dotspace" }
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

#let format-authors(e) = {
  if not has(e, "author") { return none }
  let s = join-names(e.names.author)
  if not ends-punct(s) { s = s + "." }
  V(s)
}
// " (Ed.)" / " (Eds.)" per editor count (the .bst appends "." after it in some spots)
#let eds-suffix(people) = if people.len() > 1 { " (Eds.)" } else { " (Ed.)" }
#let format-editors(e) = {     // label position: trailing " (Ed.)."/" (Eds.)."
  if not has(e, "editor") { return none }
  V(join-names(e.names.editor) + eds-suffix(e.names.editor) + ".")
}
#let format-editors-fml(e) = { // inline after booktitle: no trailing period
  if not has(e, "editor") { return none }
  V(join-names(e.names.editor) + eds-suffix(e.names.editor))
}

// ---- titles ---------------------------------------------------------------
#let format-title(e) = if has(e, "title") { V(fld(e, "title")) } else { none }
// The .bst's format.title and format.articletitle apply the same transform.
#let format-articletitle = format-title
#let format-title-emph(e) = if has(e, "title") {
  (c: it(render(fld(e, "title"))), p: ends-punct(fld(e, "title")))
} else { none }

// emph(title) + " (Nth ed.)"  — for book/proceedings btitle & booktitle
#let title-with-edition(e, raw) = {
  if raw == none or raw.trim() == "" { return none }
  let body = it(render(raw))
  if has(e, "edition") {
    // edition "l" change.case$ (bst:1301): brace-protected words keep their case.
    let ed = change-case(fld(e, "edition"), "l")
    (c: body + " (" + render(ed) + " ed.)", p: false)
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
    (c: tie-connect("Number", fld(e, "number")) + " in " + render(fld(e, "series")), p: false)
  } else { none }
}

// format.series: " (series)" / " (series, number)" / " (series, Vol. N)" (emph), leading space
#let format-series(e) = {
  if not has(e, "series") { return none }
  let inner = render(fld(e, "series"))
  if has(e, "volume") { inner = inner + ", Vol.\u{00A0}" + fld(e, "volume") }
  else if has(e, "number") { inner = inner + ", " + fld(e, "number") }
  (c: " " + it("(" + inner + ")"), p: false)
}

// ---- pages ----------------------------------------------------------------
#let format-pages(e) = if has(e, "pages") { (c: dashify(fld(e, "pages")), p: false) } else { none }
#let format-bookpages(e) = if has(e, "bookpages") {
  (c: render(fld(e, "bookpages")) + " book pages", p: false) } else { none }
// chapter + pages, or just pages
#let format-chapter-pages(e) = {
  if has(e, "chapter") {
    let ty = if has(e, "type") { render(change-case(fld(e, "type"), "t")) } else { "Chapter" }
    let r = tie-connect(ty, fld(e, "chapter"))
    if has(e, "pages") { r = r + ", " + dashify(fld(e, "pages")) }
    (c: r, p: false)
  } else { format-pages(e) }
}
// pages when no articleno (acmsmall: numpages-only -> "N pages")
#let format-pages-noart(e) = {
  if articleno-of(e) != none { none }
  else if has(e, "pages") { format-pages(e) }
  else if has(e, "numpages") { (c: fld(e, "numpages") + "\u{00A0}pages", p: false) }
  else { none }
}
// reduce.pages.to.page.count (bst:946): numpages wins; else the .bst's SECOND `if`
// (which overwrites the first) is the only branch that reduces — its final page
// count is the second parsed number when pages starts with "1" and has no third
// number, otherwise the pages string verbatim. A bare "1--N" → N, "1" → the
// (empty) second number → prints nothing; "n:1--n:m"/"5--12" stay verbatim.
#let reduce-pages(e) = {
  if has(e, "numpages") { return fld(e, "numpages") }
  if not has(e, "pages") { return none }
  let p = fld(e, "pages")
  let nums = p.matches(regex("[0-9]+"))
  let p1 = if nums.len() > 0 { nums.at(0).text } else { none }
  let p3 = if nums.len() > 2 { nums.at(2).text } else { none }
  if p1 == "1" and p3 == none { if nums.len() > 1 { nums.at(1).text } else { none } } else { p }
}
// format.page.count (bst:1540): "<count>~pages" — always a non-breaking tie.
#let format-page-count(e) = {
  let c = reduce-pages(e)
  if c == none { none } else { (c: dashify(c) + "\u{00A0}pages", p: false) }
}

// ---- date / journal -------------------------------------------------------
// format.articleno (bst:481): "Article N" with strip.articleno.or.eid; none when
// neither articleno nor eid is present.
#let format-articleno(e) = {
  let art = articleno-of(e)
  if art == none { none } else { (c: "Article " + strip-articleno(art), p: false) }
}
// format.day.month.year (bst:538): an "Article N" prefix (", Article N" only when
// the caller has already set output.state to after.block, i.e. `lead: true`), then
// an unconditional " (day month year)" with the format.year fallback. day precedes
// the month (bst:520). Always returns a value — format.year always emits something.
#let format-day-month-year(e, lead: true) = {
  let art = articleno-of(e)
  let art-pre = if art != none {
    (if lead { ", " } else { "" }) + "Article " + strip-articleno(art)
  } else { "" }
  let dm = if has(e, "month") {
    if has(e, "day") { fld(e, "day") + " " + render(fld(e, "month")) + " " }
    else { render(fld(e, "month")) + " " }
  } else { "" }
  (c: art-pre + " (" + dm + format-year-str(e) + ")", p: false)
}
// "N pages" when articleno present (numpages, or reduced from pages)
#let format-articleno-numpages(e) = {
  if articleno-of(e) == none { return none }
  format-page-count(e)
}
// format.journal.volume.number.day.month.year (bst:1718): emphasized canonical
// journal (empty when absent, but volume/number/date still print, bst:1725), the
// volume/number block, then the date — omitted only for @inproceedings (bst:1755).
#let format-journal-block(e) = {
  let jname = if has(e, "journal") { it(render(canon-abbrev(fld(e, "journal")))) } else { none }
  let vn = if has(e, "volume") and has(e, "number") {
    " " + fld(e, "volume") + ", " + fld(e, "number")
  } else if has(e, "volume") {
    " " + fld(e, "volume")
  } else if has(e, "number") {
    " " + fld(e, "number")
  } else { none }
  let dmy = if e.entry-type != "inproceedings" { format-day-month-year(e) } else { none }
  if jname == none and vn == none and dmy == none { return none }
  let c = []
  if jname != none { c = c + jname }
  if vn != none { c = c + vn }
  if dmy != none { c = c + dmy.c }
  (c: c, p: false)
}
#let format-journal-underreview(e) = {
  let pre = if has(e, "journal") { it(render(canon-abbrev(fld(e, "journal")))) + "." } else { [] }
  (c: pre + " Manuscript submitted for review", p: false)
}

// ---- "In booktitle (city)" variants ---------------------------------------
#let format-city(e) = {
  let loc = if has(e, "location") { fld(e, "location") } else if has(e, "city") { fld(e, "city") } else { none }
  let date = if has(e, "date") { fld(e, "date") } else { none }
  if loc == none and date == none { "" }
  else if loc == none { " (" + render(date) + ")" }
  else if date == none { " (" + render(loc) + ")" }
  else { " (" + render(loc) + ", " + render(date) + ")" }
}
#let format-in-emph-booktitle(e) = {
  let bt = format-emph-booktitle(e)
  if bt == none { return none }
  (c: [In ] + bt.c + format-city(e), p: false)
}
// format.in.booktitle (bst:1800): non-emphasized "In booktitle (city)" for
// proceedings that appear in a journal.
#let format-in-booktitle(e) = {
  if not has(e, "booktitle") { return none }
  (c: [In ] + render(fld(e, "booktitle")) + format-city(e), p: false)
}
#let format-in-ed-booktitle(e) = {
  let bt = format-emph-booktitle(e)
  if bt == none { return none }
  let c = [In ] + bt.c + format-city(e)
  if has(e, "editor") {
    c = c + ", " + join-names(e.names.editor) + eds-suffix(e.names.editor)
  }
  (c: c, p: false)
}
#let format-venue(e) = if has(e, "venue") {
  (c: "Presentation at " + render(fld(e, "venue")), p: false) } else { none }

// ---- thesis / techreport --------------------------------------------------
#let format-thesis-type(e, default) = (c: render(if has(e, "type") { fld(e, "type") } else { default }), p: ends-punct(if has(e, "type") { fld(e, "type") } else { default }))
#let format-tr-number(e) = {
  let raw = if has(e, "type") { fld(e, "type") } else { "Technical Report" }
  let ty = render(raw)
  if has(e, "number") { (c: ty + " " + fld(e, "number"), p: false) }
  else { (c: ty, p: ends-punct(raw)) }
}
#let format-advisor(e) = if has(e, "advisor") {
  V("Advisor(s) " + fld(e, "advisor")) } else { none }

// ---- crossref ("See [N]") --------------------------------------------------
// `xref-cite` is the rendered citation of the crossref'd parent ("[N]" in numeric
// mode), supplied by the context layer once the parent's number is known.
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
    if has(e, "key") { render(fld(e, "key")) }
    else if has(e, "series") { it(render(fld(e, "series"))) }
    else { [] }
  } else { render(format-crossref-editor(e)) }
  (c: pre + mid + [ ] + xref-cite, p: false)
}

// ---- shared trailing block: note, doi, url --------------------------------
// .bst strip.doi: bare DOIs start "10."; otherwise drop any scheme + host, keeping
// the path (http://doi.acm.org/10.1145/X -> 10.1145/X).
#let strip-doi(d) = {
  if d.starts-with("10.") { return d }
  // Only a URL-prefixed value is stripped (host up to the first "/"); a schemeless
  // value is unrecognized and kept verbatim, matching the .bst's warn-and-keep.
  if d.match(regex("(?i)^https?://")) == none { return d }
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
  // "~[class]" is a non-breaking tie in the .bst (bst:740/743).
  let suffix = if cls != none { "\u{00A0}[" + cls + "]" } else { "" }
  if lower(prefix) == "arxiv" {
    [arXiv:#link("https://arxiv.org/abs/" + ep)[#ep]#suffix]
  } else {
    // non-arXiv: lowercase the archiveprefix ("l" change.case$, bst:734).
    [#change-case(prefix, "l"):#ep#suffix]
  }
}

// shared trailing block: note, eprint, doi, url — each self-punctuating, with real
// hyperlinks (acmart renders these via hyperref \href/\url/\showeprint).
#let trailing(e) = {
  let items = ()
  if has(e, "note") {
    let n = render(fld(e, "note"))
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
    let r = if has(e, "lastaccessed") { [Retrieved #render(fld(e, "lastaccessed")) from #link(u)[#u]] } else { link(u)[#u] }
    if has(e, "archived") { r = r + [, archived at \[#link(fld(e, "archived"))[#fld(e, "archived")]\]] }
    items.push(r)
  }
  items
}

// ---- per-entry-type handlers ----------------------------------------------
#let howpub(e) = fV(e, "howpublished")

// The lead author/year slot. Only article/underreview fall back to the editor
// (bst:2198, `format.editors "editor" output.check`) and NEVER show a key
// (`author format.no.key`, bst:2208); every other driver instead uses `format.key`
// (author, else the `key` field) and never the editor (bst:2368/2400/… `author
// format.key output`). This is what keeps an editor-only @inproceedings from
// printing its editor twice (once here, once in the inline `(Eds.)` list).
#let lead-author-year(em, e, ysuf, editor-ok: false, key-ok: true) = {
  if has(e, "author") { em = out(em, format-authors(e), variant: "norm") }
  else if editor-ok and has(e, "editor") { em = out(em, format-editors(e)) }
  else if key-ok and has(e, "key") { em = out(em, V(fld(e, "key"))) }
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
  let lead = (em, e, ..o) => lead-author-year(em, e, ysuf, ..o)
  let has-xref = has(e, "crossref") and xref-cite != none
  let t = e.entry-type
  let em = em-init
  // aliases
  let manual-like = ("online", "game", "video", "artifactsoftware", "artifactdataset", "software", "dataset", "preprint", "manual")
  if t == "article" or t == "underreview" {
    // article/underreview are the only drivers that fall back to the editor and
    // never emit a key (bst:2198/2208).
    em = lead(em, e, editor-ok: true, key-ok: false)
    em = nblock(em)
    em = out(em, format-articletitle(e))
    em = nblock(em)   // new.block between title and howpublished (bst:2210/2249)
    em = out(em, howpub(e))
    if t == "underreview" {
      // format.journal.underreview does NOT set after.block, so after a
      // howpublished the journal joins with a comma, not a period (bst:1762/2257).
      em = out(em, format-journal-underreview(e))
    } else {
      if has-xref { em = out(em, format-article-crossref(e, xref-cite)) }
      else {
        // format.journal.volume.number.day.month.year sets output.state to
        // after.block (bst:1750), so the preceding piece (howpublished, or the
        // title) is always closed with a period before the journal block.
        em = nblock(em)
        em = out(em, format-journal-block(e))
      }
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
      em = out(em, fV(e, "publisher"))
      em = out(em, fV(e, "address"))
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
      em = out(em, fV(e, "publisher"))
      em = out(em, fV(e, "address"))
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
    } else if has(e, "journal") {
      // proceedings appearing in a journal (bst:2410/2461): non-emphasized "In
      // booktitle (city)" (comma-joined), editors fml, new.sentence, journal block
      // (format-journal-block drops the date for @inproceedings, bst:1755).
      if t == "presentation" {
        em = nsentence(em)
        em = out(em, format-venue(e))
      } else {
        em = out(em, format-in-booktitle(e))
      }
      em = out(em, format-editors-fml(e))
      em = nsentence(em)
      em = out(em, format-journal-block(e))
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
      em = out(em, fV(e, "organization"))
      em = out(em, fV(e, "publisher"))
      em = out(em, fV(e, "address"))
      em = out(em, format-bookpages(e))
    }
    // "Article N" then pages, after every branch (bst:2431/2436/2484/2489).
    em = out(em, format-articleno(e))
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
    em = out(em, fV(e, "school"))
    em = out(em, fV(e, "address"))
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
    if bt != none { bt = (c: bt.c + format-city(e), p: false) }
    em = out(em, bt)
    em = nsentence(em)
    em = out(em, format-bvolume(e))
    em = out(em, format-number-series(e))
    em = nsentence(em)
    em = out(em, fV(e, "organization"))
    em = out(em, fV(e, "publisher"))
    em = out(em, fV(e, "address"))
  } else if t == "techreport" {
    em = lead(em, e)
    em = nblock(em)
    em = out(em, format-btitle(e))
    em = nblock(em)
    em = out(em, format-tr-number(e))
    em = nsentence(em)
    em = out(em, fV(e, "institution"))
    em = out(em, fV(e, "address"))
    em = nsentence(em)
    em = out(em, if has(e, "pages") { (c: dashify(fld(e, "pages")) + " pages", p: false) } else { none })
  } else if t == "unpublished" {
    em = lead(em, e)
    em = nblock(em)
    em = out(em, format-title(e))          // plain title (not emphasized)
    em = nsentence(em)
    let ymd = format-day-month-year(e, lead: false)
    if ymd != none { em = out(em, ymd) }
    em = out(em, format-page-count(e))
    // note is required for @unpublished and emitted by the shared trailing block
  } else if t == "misc" or t == "booklet" {
    em = lead(em, e)
    em = nblock(em)
    em = out(em, format-title(e))
    em = nblock(em)
    em = out(em, fV(e, "howpublished"))
    if t == "booklet" { em = out(em, fV(e, "address")) }
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
    em = out(em, fV(e, "organization"))
    em = out(em, fV(e, "address"))
  } else {
    // fallback: author. year. title.
    em = lead(em, e)
    em = nblock(em)
    em = out(em, format-title(e))
  }
  // @periodical ends at fin.entry (bst:2669) with no trailing note/DOI/URL block.
  em-render(em, if t == "periodical" { () } else { trailing(e) })
}

// ---- final sort (BibTeX's two-phase SORT) ---------------------------------
// sortify (bst:2874): purify$ then downcase — BibTeX's case-insensitive compare
// that also drops \commands/grouping braces and folds foreign chars to ASCII.
#let sortify(s) = lower(purify(s))
// sort.format.names (bst:2890): each name as "{vv{ } }{ll{ }}{  f{ }}{  jj{ }}"
// (von + last + first-INITIALS + jr), sortified and joined; a trailing "others"
// becomes " et~al". The exact BibTeX inter-token spacing is not reproduced — only
// the relative ordering matters, which surname+initials fully determines.
#let sort-format-names(people) = {
  let parts = ()
  for (i, n) in people.enumerate() {
    if i == people.len() - 1 and is-others(n) { parts.push("et al") }
    else {
      let fi = purify(n.first).split(regex("\s+")).filter(t => t != "").map(t => t.clusters().first())
      let s = (purify(n.von), purify(n.last), fi.join(" "), purify(n.jr)).filter(p => p != none and p.trim() != "").join(" ")
      parts.push(lower(if s == none { "" } else { s }))
    }
  }
  parts.join("   ")
}
// The type-dispatched name source (bst:3024-3041 / presort). BibTeX's type$ sees
// the literal entry type, so aliases (collection, online, …) fall through to
// author.sort — NO editor fallback for those.
#let author-sort(e) = if has(e, "author") { sort-format-names(e.names.author) } else if has(e, "key") { sortify(fld(e, "key")) } else { "" }
#let author-editor-sort(e) = if has(e, "author") { sort-format-names(e.names.author) } else if has(e, "editor") { sort-format-names(e.names.editor) } else if has(e, "key") { sortify(fld(e, "key")) } else { "" }
#let editor-organization-sort(e) = if has(e, "editor") { sort-format-names(e.names.editor) } else if has(e, "organization") { sortify(fld(e, "organization")) } else if has(e, "key") { sortify(fld(e, "key")) } else { "" }
#let author-editor-organization-sort(e) = if has(e, "author") { sort-format-names(e.names.author) } else if has(e, "editor") { sort-format-names(e.names.editor) } else if has(e, "organization") { sortify(fld(e, "organization")) } else if has(e, "key") { sortify(fld(e, "key")) } else { "" }
#let sort-names(e) = {
  let t = e.entry-type
  if t in ("book", "inbook", "article") { author-editor-sort(e) }
  else if t in ("proceedings", "periodical") { editor-organization-sort(e) }
  else if t == "manual" { author-editor-organization-sort(e) }
  else { author-sort(e) }
}
// sort.format.title (bst:2913): drop a leading "A "/"An "/"The ", then sortify.
#let sort-format-title(raw) = {
  let s = raw
  if s.starts-with("The ") { s = s.slice(4) }
  if s.starts-with("An ") { s = s.slice(3) }
  if s.starts-with("A ") { s = s.slice(2) }
  sortify(s)
}
// bib.sort.order (bst:3122): sort.label(name source) + year + title — the FINAL
// reference-list order. A NUL joins the fields so a shorter field always sorts
// before its own extension (like BibTeX's blank field separator).
#let sort-key(e) = sort-names(e) + "\u{0}" + sortify(fld(e, "year", d: "")) + "\u{0}" + sort-format-title(fld(e, "title", d: ""))
