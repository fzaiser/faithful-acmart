// ACM bibliography cite, sort, and bibliography orchestration.

#import "bibtex.typ": read-bib, parse-bib, parse-names
#import "tex.typ": tex-to-string
#import "acmref-common.typ": fld, has, is-others, von-last, it
// the .bst reads a "??" value as a missing one, which decides both its citation
// label and the year that label carries; biblatex prints such a value instead
#import "acmref-bst.typ": handle, sort-key, has as bst-has, year-value as bst-year-value
#import "acmref-biblatex.typ": blx-handle, blx-biber-datamodel, blx-sort-key, blx-np-lengths, blx-label-year
#import "acmref-blxnames.typ": name-list, disambiguate, list-label, list-context, list-namehash, list-punct-initial
#import "../formats/_base.typ": tp

// ---- cite/number layer ----------------------------------------------------
#let cited-state = state("acmref-cited", ())
#let bib-path-state = state("acmref-bibpath", none)
#let bib-format-state = state("acmref-bibformat", "bst")
// "numeric" (default) or "author-year" — set by the acmart show rule from the
// `cite-style` option, mirroring acmart's \citestyle{acmnumeric|acmauthoryear}.
#let cite-style-state = state("acmref-citestyle", "numeric")

// accept a single path, a list of paths, or an `arguments` value carrying one path.
// The `arguments` case comes from the `bibliography` shadow for a single source: it
// is threaded here un-indexed and read with `read(..paths)` so a RELATIVE path keeps
// the caller's location (Typst resolves it against where the args were constructed).
// Extracted string/array paths have lost that origin, so they must be absolute.
#let read-merged(paths) = {
  if type(paths) == arguments { return parse-bib(read(..paths)) }
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

// biber's `nty` order over the cited set. `useprefix` — whether a name prefix
// files with the family name or only breaks a tie behind it — is on under
// acmnumeric (trad-standard.bbx:18) and off under acmauthoryear, and the name
// part padding widths are measured over the whole list, so both are resolved
// here and handed to the key builder.
// biblatex's `mincrossrefs` and `minxrefs` (both 2): a parent this many CITED
// entries point at joins the bibliography in its own right, uncited. Measured
// against biber: the two relations count APART — one `crossref` beside one
// `xref` promotes nothing — the count is over distinct entries rather than
// citations, and a parent promoted this way does not itself count as a citing
// entry, so promotion never travels further up a chain.
#let blx-min-refs = (crossref: 2, xref: 2)
#let blx-promotions(db, cited) = {
  let counts = (:)
  for rel in blx-min-refs.keys() { counts.insert(rel, (:)) }
  for k in cited {
    if k not in db { continue }
    for (rel, seen) in counts {
      let parent = db.at(k).fields.at(rel, default: none)
      if parent != none and parent in db {
        counts.at(rel).insert(parent, seen.at(parent, default: 0) + 1)
      }
    }
  }
  let out = ()
  for (rel, seen) in counts {
    for (parent, n) in seen {
      if n >= blx-min-refs.at(rel) and parent not in cited and parent not in out { out.push(parent) }
    }
  }
  out
}
#let resolve-biblatex(db, cited, style) = {
  let db2 = blx-biber-datamodel(db)
  // a promoted parent is an ordinary entry of the list from here on: it sorts,
  // labels and takes an extradate letter like any other
  let listed = cited.filter(k => k in db2) + blx-promotions(db2, cited)
  let lens = blx-np-lengths(listed.map(k => db2.at(k)))
  let useprefix = style != "author-year"
  (db: db2, order: listed.sorted(key: k => blx-sort-key(db2.at(k), lens: lens, useprefix: useprefix)))
}

// ---- author-year labels (format.lab.names + calc.basic.label dispatch) -----
// short citation label: von+Last only, " and " for two, "et al." for >2 (or "and
// others"). von-last is RAW; tex-to-string gives the plain label used for both
// display and (suffix-)grouping comparison.
#let format-lab-names(people) = {
  if people.len() == 0 { return "" }
  if people.len() > 2 { return tex-to-string(von-last(people.at(0))) + " et al." }
  let s = von-last(people.at(0))
  if people.len() == 2 {
    if is-others(people.at(1)) { s = s + " et al." } else { s = s + " and " + von-last(people.at(1)) }
  }
  s = tex-to-string(s)
  s
}
#let format-lab-names-full(people) = {
  people.map(n => tex-to-string(von-last(n))).join(" and ")
}
#let pick(arr) = { let r = arr.find(x => x != none); if r == none { "" } else { r } }
// \DeclareLabeltitle (biblatex.def:1406): shorttitle, then title, then maintitle.
#let labeltitle-field(e) = {
  let names = ("shorttitle", "title", "maintitle").filter(n => has(e, n))
  if names.len() == 0 { none } else { names.first() }
}
#let label-title(e, quoted: false) = {
  let name = labeltitle-field(e)
  if name == none { return none }
  let t = tex-to-string(fld(e, name))
  if quoted { "\u{201C}" + t + "\u{201D}" } else { t }
}
// calc.basic.label's type dispatch (bst:2032): which field supplies the .bst
// citation label. BibTeX's type$ sees the LITERAL entry type, so the .bst's
// formatter aliases (collection -> proceedings, online/software/preprint/… ->
// manual, bst:2568) do not reach this dispatch: every type but the six named
// here falls to author.key.label, with no editor and no organization step.
// `full: true` is natbib's spelled-out label, which calc.label (bst:2074) builds
// from one chain for every type at all.
#let bst-lab-label(e, full: false) = {
  let names-fn = if full { format-lab-names-full } else { format-lab-names }
  let au = if bst-has(e, "author") { names-fn(e.names.author) }
  let ed = if bst-has(e, "editor") { names-fn(e.names.editor) }
  let org = if bst-has(e, "organization") { tex-to-string(fld(e, "organization")) }
  let key = if bst-has(e, "key") { tex-to-string(fld(e, "key")) }
  if full { return pick((au, ed, org, key, "??")) }
  // author.key.label &co. fall back to cite$[0:3] when nothing else is present (bst:1968)
  let ck = e.at("cite-key", default: "")
  let key3 = ck.clusters().slice(0, calc.min(3, ck.clusters().len())).join()
  let t = e.entry-type
  if t in ("book", "inbook", "article") { pick((au, ed, key, key3)) }
  else if t in ("proceedings", "periodical") { pick((ed, org, key, key3)) }
  else if t == "manual" { pick((au, ed, org, key, key3)) }
  else { pick((au, key, key3)) }
}

// biblatex.def:459 declares the `citetitle` format `cite:label` falls back to:
// emphasized, quoted for the same types whose `title` is quoted (:461), plain
// for the three supplement types (:464).
#let blx-citetitle-format(e) = {
  let t = e.entry-type
  if t in ("article", "inbook", "incollection", "inproceedings", "conference",
           "patent", "thesis", "mastersthesis", "phdthesis", "unpublished") { "quoted" }
  else if t in ("suppbook", "suppcollection", "suppperiodical") { "plain" }
  else { "emph" }
}
// BibLaTeX's `cite:label`, taking the already-disambiguated name list (`none`
// when the entry has no labelname at all). Unlike the .bst's
// author.key.organization.label it never falls back to a corporate name: with no
// labelname it prints the labeltitle, for every entry type alike.
// Only acmauthoryear's `cite:label` (authoryear.cbx:52) has a `label` step, and
// it prints the field plainly — the citetitle format applies to the title alone.
// acmnumeric's textual cite (numeric.cbx:26) goes straight from the labelname to
// the labeltitle, so an explicit label never shows there.
#let blx-lab-label(e, names, style) = pick((
  names,
  if style == "author-year" and has(e, "label") { tex-to-string(fld(e, "label")) },
  label-title(e, quoted: blx-citetitle-format(e) == "quoted"),
  if has(e, "key") { tex-to-string(fld(e, "key")) },
))

// \DeclareLabelname: the author list, or the editor list when there is none
// (ACM's proceedings-like types label on the editor).
#let blx-label-people(e) = {
  if e.entry-type in ("proceedings", "periodical", "collection") {
    if has(e, "editor") { e.names.editor } else { none }
  } else {
    if has(e, "author") { e.names.author } else if has(e, "editor") { e.names.editor } else { none }
  }
}

#let blx-label-title-italic(e, style) = {
  if style == "author-year" and has(e, "label") { return false }
  blx-label-people(e) == none and labeltitle-field(e) != none and blx-citetitle-format(e) == "emph"
}

// \natexlab a/b/c suffixes: a..z over consecutive (label, year)-equal entries in
// sorted order (forward.pass/reverse.pass); singletons get "".
#let lab-dedup-key(e) = bst-lab-label(e) + "\u{0}" + bst-year-value(e).c
// \natexlab a/b/c suffixes are assigned in BibTeX's PRESORT order (bst forward/
// reverse pass run right after the presort SORT), where entries are grouped by
// (citation label, year) so equal-label entries are always adjacent — unlike the
// FINAL bib.sort.order (name/year/title), which can interleave a different-label
// entry between two same-label ones and split the group. We therefore regroup
// over the presort key (dedup label+year, then the final name/title order for
// the a/b order within a group) before the passes.
#let bst-extras(db, order) = {
  order = order.sorted(key: k => (lab-dedup-key(db.at(k)), sort-key(db.at(k))))
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

// BibLaTeX's extradate: entries sharing a label context and a year are lettered
// a, b, c… in reference-list order. Unlike the .bst passes above this is a plain
// global count (biber's seen_nametitledateparts), so an intervening entry does
// not split a group.
#let blx-extras(db, order, contexts) = {
  let group = k => {
    let y = blx-label-year(db.at(k))
    contexts.at(k) + "\u{0}" + (if y == none { "n.d." } else { y })
  }
  let counts = (:)
  for k in order { counts.insert(group(k), counts.at(group(k), default: 0) + 1) }
  let seen = (:)
  let res = (:)
  for k in order {
    let g = group(k)
    if counts.at(g) == 1 { res.insert(k, ""); continue }
    seen.insert(g, seen.at(g, default: 0) + 1)
    let letter = str.from-unicode(96 + seen.at(g))
    // A year takes the letter bare ("2010a"); the `nodate` label date takes it
    // parenthesized ("N.d.(a)"), in the cite label as well as the entry.
    res.insert(k, if blx-label-year(db.at(k)) == none { "(" + letter + ")" } else { letter })
  }
  res
}

// Every BibLaTeX cite label plus the extradate letters, resolved in one pass over
// the reference list: name disambiguation decides both what a label prints and
// which labels still collide and so need a letter.
// `style` decides two things biblatex ties to the citation style rather than the
// entry: acmauthoryear rides authoryear-comp, which turns uniquename and
// uniquelist on, while acmnumeric rides plain numeric and leaves both off; and
// `useprefix`, which acmnumeric inherits as true from trad-standard.bbx:18, puts
// the prefix into a bare family-name label ("van Beethoven", not "Beethoven").
#let blx-labels(db, order, style) = {
  let unique = style == "author-year"
  let useprefix = not unique
  let lists = order
    .map(k => {
      let people = blx-label-people(db.at(k))
      if people != none { name-list(k, people) }
    })
    .filter(l => l != none)
  let dis = (:)
  for d in disambiguate(lists, unique: unique) { dis.insert(d.key, d) }
  let by-key = (:)
  for l in lists { by-key.insert(l.key, l) }

  let labels = (:)
  let contexts = (:)
  let hashes = (:)
  for k in order {
    let e = db.at(k)
    let named = k in dis
    labels.insert(k, (
      text: blx-lab-label(e, if named { list-label(by-key.at(k), dis.at(k), useprefix: useprefix) }, style),
      italic: blx-label-title-italic(e, style),
      named: named,
      // …and whether that label opens with a generated, punctuation-only initial
      punct-initial: named and list-punct-initial(by-key.at(k), dis.at(k), useprefix: useprefix),
    ))
    // what authoryear-comp compresses consecutive cites on
    hashes.insert(k, if named { list-namehash(by-key.at(k), dis.at(k)) } else { "\u{0}" + k })
    // \DeclareExtradateContext is labelname, else labeltitle; an entry with
    // neither is never lettered, so give it a context nothing can share.
    let lt = labeltitle-field(e)
    contexts.insert(k, if named { "n\u{0}" + list-context(by-key.at(k), dis.at(k)) }
      else if lt != none { "t\u{0}" + str.normalize(tex-to-string(fld(e, lt)), form: "nfc") }
      else { "k\u{0}" + k })
  }
  (labels: labels, hashes: hashes, extras: blx-extras(db, order, contexts))
}

#let bst-labels(db, order) = {
  let res = (:)
  for k in order { res.insert(k, (text: bst-lab-label(db.at(k)), italic: false)) }
  res
}

// The whole resolved reference list for the current cited set — entries, their
// sorted order, and every entry's cite label and year suffix — or `none` if no
// acmart `#bibliography` ever registered a path (`bib-path-state` still `none`).
// Callers turn that into an actionable error — see `with-prepared`.
#let prepared() = {
  let path = bib-path-state.final()
  if path == none { return none }
  let db = read-merged(path)
  // Stamp each entry with its citation key (cite$) for the author.key.label
  // last-ditch fallback — the first 3 chars of the key when there is no
  // author/editor/organization/key field (bst:1968).
  for (k, e) in db { db.insert(k, e + (cite-key: k)) }
  let cited = cited-state.final()
  let fmt = bib-format-state.final()
  let style = cite-style-state.final()
  let res = if fmt == "biblatex" { resolve-biblatex(db, cited, style) } else { resolve-crossref(db, cited) }
  res + (fmt: fmt) + if fmt == "biblatex" { blx-labels(res.db, res.order, style) } else {
    (labels: bst-labels(res.db, res.order), extras: bst-extras(res.db, res.order))
  }
}

// cited keys reordered into reference-list (sorted) order
#let cite-order(keys, order) = keys.filter(k => k in order).sorted(key: k => order.position(x => x == k))

// The year a cite prints. The BibLaTeX cite styles have no ACM `year` bibmacro:
// an entry biber resolved to \literal{nodate} (biblatex.def:1391) shows the
// `nodate` string (english.lbx:389) mid-sentence, and so uncapitalized, where
// the .bst backend shows ACM's own "[n. d.]".
#let cite-year(p, k) = {
  if p.fmt == "biblatex" { let y = blx-label-year(p.db.at(k)); if y == none { "n.d." } else { y } }
  else { bst-year-value(p.db.at(k), nodate: "[n.\u{2009}d.]").c }
}
#let cite-label(p, k) = p.labels.at(k).text
// biblatex's \bibinitperiod is \adddot, and its punctuation tracker drops that
// dot when punctuation already stands in front of it. An initial that is nothing
// but a mark ("“.") never re-arms the tracker, so it keeps its period only where
// nothing precedes it — first in a citation — and loses it behind the "; " an
// earlier entry left. An initial with a letter in it re-arms the tracker and
// keeps its period wherever it sits.
#let cite-label-content(p, k, first: true) = {
  let label = p.labels.at(k)
  let generated = label.at("punct-initial", default: false)
  let text = if first or not generated { label.text } else { label.text.replace(".", "", count: 1) }
  if label.italic { it(text) } else { text }
}

// ---- cite -> reference-list hyperlinks -------------------------------------
// Each reference entry carries `entry-label(key)`; cites `link` to it, matching
// LaTeX+hyperref's in-text cite anchors. The label is namespaced to avoid
// clashing with user labels.
#let entry-label(key) = label("acmref:" + key)
#let cite-num-link(num, key) = link(entry-label(key))[#num]

// natbib author-year \citep/\citet: group consecutive same-label entries, then
// group their years by base year so suffixes collapse ("2020a,b,c"); ", " between
// distinct years, "; " between author groups. \citet puts years in brackets.
// `mode`: "citep" ([Label Year; …], the default), "citet" (Label [Year]), or
// "citealt" (Label Year — no brackets, natbib \citealt). `supplement` is natbib's
// postnote, joined with notesep ", " inside the closing bracket (dtx:3272).
#let cite-ay(p, keys, mode: "citep", supplement: none) = {
  let ks = cite-order(keys, p.order)
  let lgroups = ()
  for k in ks {
    // natbib compresses on the printed label; authoryear-comp compresses on
    // biber's namehash, which separates entries whose labels coincide.
    let lbl = if "hashes" in p { p.hashes.at(k) } else { cite-label(p, k) }
    let shown = cite-label-content(p, k, first: lgroups.len() == 0)
    let yr = (base: cite-year(p, k), suf: p.extras.at(k, default: ""))
    if lgroups.len() > 0 and lgroups.at(-1).label == lbl { lgroups.at(-1).years.push(yr) }
    else { lgroups.push((label: lbl, shown: shown, years: (yr,), key: k)) }
  }
  let render-years(years) = {
    let ybits = ()
    for y in years {
      if ybits.len() > 0 and ybits.at(-1).base == y.base { ybits.at(-1).sufs.push(y.suf) }
      else { ybits.push((base: y.base, sufs: (y.suf,))) }
    }
    // \bibrangedash carries an infinite penalty, so a year RANGE never breaks
    // across lines the way a bare en dash otherwise would; the ", " between
    // years stays ordinary breakable glue.
    ybits.map(b => box(b.base + b.sufs.join(","))).join(", ")
  }
  // link each author group to its first entry (hyperref anchors the whole citation)
  let years = g => render-years(g.years)
  let parts = lgroups.map(g => link(entry-label(g.key),
    if mode == "citet" { g.shown + " [" + years(g) + "]" }
    else { g.shown + " " + years(g) }))
  let note = if supplement != none { [, #supplement] } else { [] }
  if mode == "citep" { "[" + parts.join("; ") + note + "]" } else { parts.join("; ") }
}
// natbib \citet/\citealt in NUMBERS mode: "Author et al. [N]" / "Author et al. N".
#let numeric-textcite(p, ks, brackets: true) = {
  cite-order(ks, p.order).map(k => {
    let num = p.order.position(x => x == k) + 1
    let label = cite-label-content(p, k)
    link(entry-label(k), if brackets { [#label \[#num\]] } else { [#label #num] })
  }).join(", ")
}

// collapse [1,2,3,5] -> "1–3, 5", each number linked to its entry. `pairs` are
// (num, key) so the range endpoints keep their own link targets.
#let collapse-linked(pairs) = {
  let s = pairs.sorted(key: p => p.num)
  let groups = ()
  for p in s {
    if groups.len() > 0 and p.num == groups.at(-1).at(-1).num + 1 { groups.at(-1).push(p) }
    else { groups.push((p,)) }
  }
  groups.map(g => if g.len() >= 3 {
    [#cite-num-link(g.first().num, g.first().key)\u{2013}#cite-num-link(g.last().num, g.last().key)]
  } else {
    g.map(p => cite-num-link(p.num, p.key)).join(", ")
  }).join(", ")
}

// numeric \cite: each cited key -> its reference-list number; the .bst collapses
// ranges while BibLaTeX lists them in command order. Every key is known here
// (ensure-known ran first, so `position` never returns none).
#let numeric-cite(p, ks, supplement: none) = {
  let pairs = ks.map(k => (num: p.order.position(x => x == k) + 1, key: k))
  let inner = if p.fmt == "biblatex" {
    pairs.map(pair => cite-num-link(pair.num, pair.key)).join(", ")
  } else {
    collapse-linked(pairs)
  }
  // natbib notesep ", " before the postnote, inside the brackets (dtx:3272)
  let note = if supplement != none { [, #supplement] } else { [] }
  [[#inner#note]]
}

// An undefined citation key is a hard error, matching Typst's native `cite`/`@key`
// ("key `x` does not exist in the bibliography") rather than LaTeX's silent "[?]".
#let ensure-known(ks, db) = {
  for k in ks {
    assert(k in db, message: "faithful-acmart: key `" + k + "` does not exist in the bibliography")
  }
}

#let register-cites(ks) = cited-state.update(cur => {
  for k in ks { if k not in cur { cur.push(k) } }
  cur
})

// Run `body(p)` in a cite context. `prepared()` is `none` only when no acmart
// `#bibliography` ever registered a path (`bib-path-state` still holds its `none`
// init) — a real misconfiguration, since on the bibtex/biblatex backends `@key` /
// `#cite` resolve against acmart's own `bibliography`. (When the acmart bibliography
// IS in scope, Typst pre-collects its state update, so `.final()` reliably returns
// the path on every layout pass — verified: none of the twins ever hit this branch.
// So erroring here is safe; it does not abort a valid document mid-convergence.)
// The old code called `read()` on the `none` path instead, crashing with a cryptic
// "expected string, found none" deep in the .bib reader.
#let with-prepared(ks, body) = {
  // Register the cited keys before resolving, so a future backend entry point can
  // never forget the registration step (it lived at every bbl-* call site before).
  register-cites(ks)
  context {
  let p = prepared()
  assert(p != none, message:
    "faithful-acmart: cited a key but no bibliography is registered to resolve it. On "
    + "the `bibtex`/`biblatex` backends, `@key` / `#cite` resolve through "
    + "faithful-acmart's `#bibliography` (not Typst's built-in). Make sure you (1) import "
    + "the template with `*` (`#import \"...\": *`, not just `acmart`) so `bibliography` "
    + "shadows the built-in, and (2) call `#bibliography(\"refs.bib\")`.")
  ensure-known(ks, p.db)
  body(p)
  }
}

// numeric: .bst collapses ranges, BibLaTeX preserves command order; author-year:
// \citep "[Label Year]"
#let bbl-cite(..keys) = {
  let ks = keys.pos()
  let supp = keys.named().at("supplement", default: none)
  with-prepared(ks, p => {
    if cite-style-state.get() == "author-year" {
      cite-ay(p, ks, supplement: supp)
    } else {
      numeric-cite(p, ks, supplement: supp)
    }
  })
}

// \citet: "Label [Year]" (author-year) / "Author et al. [N]" (numbers mode —
// natbib keeps the author name in numeric \citet, dtx numbers style).
#let bbl-citet(..keys) = {
  let ks = keys.pos()
  with-prepared(ks, p => {
    if cite-style-state.get() == "author-year" {
      cite-ay(p, ks, mode: "citet")
    } else {
      numeric-textcite(p, ks)
    }
  })
}

// \citealt: like \citet but with no brackets ("Label Year" / "Author et al. N").
#let bbl-citealt(..keys) = {
  let ks = keys.pos()
  with-prepared(ks, p => {
    if cite-style-state.get() == "author-year" {
      cite-ay(p, ks, mode: "citealt")
    } else {
      numeric-textcite(p, ks, brackets: false)
    }
  })
}

// \citeyearpar: the year(s) in brackets. \citeyear yields the YEAR in BOTH modes
// (numbers mode too — natbib prints "[1978]", not "[N]"); the a/b suffix only
// applies in author-year mode.
#let bbl-citeyearpar(..keys) = {
  let ks = keys.pos()
  with-prepared(ks, p => {
    let extras = if cite-style-state.get() == "author-year" { p.extras } else { (:) }
    "[" + cite-order(ks, p.order).map(k =>
      link(entry-label(k), cite-year(p, k) + extras.at(k, default: ""))).join(", ") + "]"
  })
}

// \shortcite (dtx:3670): \cite in numbers mode, \citeyearpar in author-year mode.
#let bbl-shortcite(..keys) = context {
  if cite-style-state.get() == "author-year" { bbl-citeyearpar(..keys) } else { bbl-cite(..keys) }
}

// \citeyear: just the year(s) with suffix; \citeauthor: just the label
#let bbl-citeyear(..keys) = {
  let ks = keys.pos()
  with-prepared(ks, p => {
    let extras = if cite-style-state.get() == "author-year" { p.extras } else { (:) }
    cite-order(ks, p.order).map(k => cite-year(p, k) + extras.at(k, default: "")).join(", ")
  })
}
#let bbl-citeauthor(..keys) = {
  let ks = keys.pos()
  with-prepared(ks, p => {
    // \citeauthor prints `labelname` and nothing else, so under acmnumeric an
    // entry with no name list prints nothing at all — where \textcite and \cite
    // fall through to `cite:label` and show the title. acmauthoryear patches
    // \citeauthor (acmauthoryear.cbx) and does show the title there.
    let bare = p.fmt == "biblatex" and cite-style-state.get() != "author-year"
    cite-order(ks, p.order)
      .filter(k => not (bare and not p.labels.at(k).at("named", default: true)))
      .map(k => link(entry-label(k), cite-label-content(p, k))).join("; ")
  })
}

#let bbl-bibliography(path, title: [References], size: 8pt, leading: auto, format: "bst") = {
  bib-path-state.update(path)
  bib-format-state.update(format)
  context {
    let p = prepared()
    let db = p.db
    let order = p.order
    let ay = cite-style-state.get() == "author-year"
    let extras = if ay { p.extras } else { (:) }
    let num-of = (:)
    for (i, k) in order.enumerate() { num-of.insert(k, i + 1) }
    set text(size: size)
    set par(justify: true, first-line-indent: 0pt, leading: if leading == auto { 0.65em } else { leading })
    // List geometry: the label box is as wide as the WIDEST label "[N]" and the
    // label is right-flushed inside it, with every line (first + continuation)
    // hanging at leftmargin = labelwidth + labelsep. This holds for BOTH engines —
    // natbib (\settowidth\labelwidth{\@biblabel{N}} + \@biblabel right-flush,
    // natbib.sty:627) and biblatex numeric (\labelwidth=\labelnumberwidth +
    // \makelabel{\hss#1}, numeric.bbx:29) — but \labelsep DIFFERS:
    //   • natbib/bst → \labelsep = 5pt (amsart re-sets it at begin-document,
    //     amsart.cls:241/943, after acmart's 4pt \AtBeginDocument, so amsart wins);
    //   • biblatex   → \biblabelsep = 2\labelsep = 10pt (biblatex.def:346).
    // The measure must run under `text(size: size)` so it reads the bibliography's
    // 8pt, not the caller's.
    let labelsep = if format == "biblatex" { 2 * 5 * tp } else { 5 * tp }
    let labelwidth = measure(text(size: size)[[#order.len()]]).width
    // acmart \addcontentsline's the bibliography heading (dtx:3165-3168), so it is
    // outlined (PDF bookmark), unlike our default headings.
    if title != none { heading(level: 1, numbering: none, outlined: true, title) }
    for (i, key) in order.enumerate() {
      let e = db.at(key)
      // "See [parent]" citation for a child whose parent is in the list
      let xref-cite = none
      let xr = e.fields.at("crossref", default: none)
      if xr != none and xr in num-of {
        xref-cite = if ay { cite-ay(p, (xr,), mode: "citet") } else { [[#cite-num-link(num-of.at(xr), xr)]] }
      }
      let body = if format == "biblatex" {
        blx-handle(e, style: cite-style-state.get(), year-suffix: extras.at(key, default: ""))
      } else {
        handle(e, xref-cite: xref-cite, year-suffix: extras.at(key, default: ""))
      }
      let entry = if ay {
        // author-year list: no numbers, hanging indent = natbib \bibhang (1em
        // frozen at load-time 10pt, natbib.sty:637; acmart does not override it).
        block(par(hanging-indent: 10 * tp, body))
      } else {
        // right-flush the label in a labelwidth-wide column, labelsep gap to text.
        grid(columns: (labelwidth, 1fr), column-gutter: labelsep, align: (right, left),
          [[#(i + 1)]], body)
      }
      // in-text cites `link` here (see `entry-label`); the label must be attached
      // in markup (a bare label in a code block can't join with content)
      [#entry#entry-label(key)]
    }
  }
}
