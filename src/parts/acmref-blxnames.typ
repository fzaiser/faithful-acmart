// BibLaTeX name disambiguation for author-year cite labels.
//
// acmauthoryear.bbx builds on biblatex's authoryear-comp, which switches on
// uniquename=full and uniquelist=true, and it caps citation name lists with
// maxcitenames=2 (mincitenames keeps biblatex's minnames default of 1). Two
// mechanisms therefore shape a label:
//
//   * uniquename adds as much of a name's given part as it takes to tell it
//     apart from every other *visible* name sharing its family name — nothing,
//     the initials, or the given name in full;
//   * uniquelist widens a list past the maxcitenames truncation point until the
//     names it shows identify the entry.
//
// The two feed each other — uniquename decides what a list position contributes
// to uniquelist, uniquelist decides which names uniquename can see — so biber
// alternates the passes to a fixed point (Biber.pm `uniqueness`). This is a port
// of that computation: `disambiguate` reproduces the per-name `un=` and
// per-list `ul=` values biber writes into the .bbl.

#import "tex.typ": tex-to-string, decode-chars
#import "acmref-common.typ": is-others

#let max-cite-names = 2
#let min-cite-names = 1

// biber's gen_initials (Utils.pm:1775) reads the name syntax, which is why this
// takes the part before `tex-to-string` decodes it: braces decide what may be
// split. Only the character commands are decoded first, exactly as biber does
// (see `decode-chars`) — a foreign letter is one character to every rule below,
// so "\ae-Paul" initials as "æ.-P." and not as the two letters "ae".
// parsename (Input/file/bibtex.pm:1820) first neutralises the whitespace inside
// a part that is wrapped in braces, so "{Jean Paul}" stays one word and yields
// one initial; then strip_noinit drops a LOWERCASE two-letter dash prefix
// ("de-Paul" -> "Paul", but "De-Paul" keeps its "D.-P.") and the two characters
// biblatex never initials on; then it splits on whitespace and ties outside
// braces. gen_initials splits a hyphenated word and rejoins with the hyphen
// ("Jean-Paul" -> "J.-P.") unless the whole word is braced or the hyphen itself
// is protected ("Hans{-}Peter" -> "H."), the old BibTeX way of suppressing it.
#let outer-braced(s) = {
  let t = s.trim()
  if not (t.starts-with("{") and t.ends-with("}")) { return false }
  let depth = 0
  for (i, c) in t.clusters().enumerate() {
    if c == "{" { depth += 1 } else if c == "}" {
      depth -= 1
      if depth == 0 { return i == t.clusters().len() - 1 }
    }
  }
  false
}
// split on every character the separator matches, but only at brace depth 0
#let split-unbraced(s, sep) = {
  let out = ()
  let cur = ""
  let depth = 0
  for c in s.clusters() {
    if c == "{" { depth += 1; cur += c }
    else if c == "}" { depth -= 1; cur += c }
    else if depth == 0 and c.contains(sep) { if cur != "" { out.push(cur) }; cur = "" }
    else { cur += c }
  }
  if cur != "" { out.push(cur) }
  out
}
#let strip-noinit(s) = {
  s.replace(regex("\\b\\p{Ll}\\p{Ll}\\p{Pd}(\\S)"), m => m.captures.at(0))
    .replace(regex("[\u{02BF}\u{2018}]"), "")
}
// A word yields one initial: its first character once the raw syntax has been
// decoded, so an accent or a character macro contributes the letter it stands
// for. gen_initials (Utils.pm:1792) takes a SECOND character when the first is
// a diacritic, which is how "`Ali" initials as a left quote and then "A." — the
// backtick is TeX's input spelling of that quote and carries the property.
#let word-initial(w) = {
  let raw = w.trim(regex("^\{+"))
  // …and it slices its OWN form, before any of TeX's input ligatures: "``Ali"
  // is two backticks there and the initial is the one quote they typeset as,
  // where slicing the typeset text would take that quote plus a letter.
  if raw.starts-with(regex("\p{Diacritic}")) {
    let cl = raw.clusters()
    return tex-to-string(cl.slice(0, calc.min(2, cl.len())).join("")).trim() + "."
  }
  let t = tex-to-string(raw).trim()
  if t == "" { "" } else { t.clusters().first() + "." }
}
// gen_initials splits on the whole Dash property, which is wider than the dash
// PUNCTUATION the noinit and nosort patterns use: it also covers the dashes that
// are symbols (a minus sign) or fullwidth forms.
#let blx-dash = regex("\\p{Dash}")
#let name-initials(raw) = {
  if raw.trim() == "" { return "" }
  let raw = decode-chars(raw)
  // biber neutralises the whitespace inside an outer-braced part so the split
  // below cannot break it up; keeping it whole has the same effect without
  // putting a character into the text that the renderer would have to carry.
  let whole = outer-braced(raw)
  let part = strip-noinit(raw)
  let hyphenated = w => {
    not outer-braced(w) and w.replace(regex("\\{\\p{Dash}\\}"), "").contains(blx-dash)
  }
  let word = w => {
    if hyphenated(w) { split-unbraced(w, blx-dash).map(word-initial).join("-") }
    else { word-initial(w) }
  }
  let words = if whole { (part,) } else { split-unbraced(part, regex("[\\s~]")) }
  words.map(word).join(" ")
}

// The name parts biblatex disambiguates on, as plain (TeX-decoded) text.
//
// COMPOSED, because these are comparison keys as much as printed text: an
// accent this decoded arrives as a base letter plus a combining mark, while a
// .bib that types the character whole arrives precomposed. Biber writes NFC
// into the .bbl and recognizes "Jos{\'e}" and "José" as one author, lettering
// them 2019a/b; two forms of one name would otherwise disambiguate against each
// other and print two labels where biber prints one.
#let name-forms(n) = {
  let part = raw => str.normalize(tex-to-string(raw), form: "nfc")
  let ini = raw => str.normalize(name-initials(raw), form: "nfc")
  let (family, prefix, given, suffix) = (part(n.last), part(n.von), part(n.first), part(n.jr))
  (
    family: family, prefix: prefix, given: given, suffix: suffix,
    // the initials come from the RAW part, which is what biber initials on
    giveni: ini(n.first), prefixi: ini(n.von), suffixi: ini(n.jr),
  )
}

// The disambiguation ladder of a name, from least to most specific. The base is
// the family name alone: biblatex's default uniquename template folds the prefix
// into the base only under `useprefix`, which ACM leaves off. Levels 0/1/2 index
// straight into it.
#let name-ladder(f) = if f.given == "" { (f.family,) } else {
  (f.family, f.family + "\u{0}i" + f.giveni, f.family + "\u{0}f" + f.given)
}

// biblatex.def's `labelname` format, one name per uniquename level: the family
// alone, the given initials before it, or the given name in full. Levels 1 and 2
// always carry the prefix (initialled or whole) between the given part and the
// family; the base form carries it only under `useprefix`, which acmnumeric
// inherits as true and acmauthoryear leaves off.
#let render-name(f, level, useprefix: false) = {
  if level == 0 { return if useprefix and f.prefix != "" { f.prefix + " " + f.family } else { f.family } }
  let (given, prefix, suffix) = if level == 1 { (f.giveni, f.prefixi, f.suffixi) }
    else { (f.given, f.prefix, f.suffix) }
  (given, prefix, f.family, suffix).filter(p => p != "").join(" ")
}

// biblatex's name-list delimiters: ", " between names and a serial ", and "
// before the last (american.lbx defines \finalandcomma). A truncated list ends
// in "et al.", preceded by that same serial comma as soon as it shows more than
// one name (biblatex.def's name:andothers).
#let join-label(parts, truncated) = {
  if parts.len() == 0 { "" }
  else if truncated { parts.join(", ") + if parts.len() > 1 { "," } else { "" } + " et al." }
  else if parts.len() <= 2 { parts.join(" and ") }
  else { parts.slice(0, -1).join(", ") + ", and " + parts.last() }
}

#let _join(toks) = toks.join("\u{1}")
#let _bump(counts, k) = counts + ((k): counts.at(k, default: 0) + 1)
#let _add(pool, ns, nskey) = pool + ((ns): pool.at(ns, default: (:)) + ((nskey): true))

// How many names a citation shows: the whole list up to maxcitenames, else the
// uniquelist point if one was found and mincitenames otherwise.
#let visible-count(lst, ul) = if lst.names.len() > max-cite-names {
  ul.at(lst.key, default: min-cite-names)
} else { lst.names.len() }

// The level at which a name first becomes unique in a pool, or 0 when even its
// full form does not (biber leaves such a name at the base of the schema).
#let _level(pool, ladder) = {
  for (i, ns) in ladder.enumerate() {
    if pool.at(ns, default: (:)).len() == 1 { return i }
  }
  0
}

// create_uniquename_info + generate_uniquename. Two pools are counted: one over
// the names a citation actually shows, which drives the printed label, and one
// over every name in every list, which uniquelist needs so it can tell what a
// hidden list position would contribute if it were exposed.
#let un-pass(lists, ul) = {
  let seen = (visible: (:), all: (:))
  let visible-of = lst => {
    let u = ul.at(lst.key, default: 0)
    // A list shorter than the truncation point shows every name, and so does one
    // the .bib itself truncated with "and others".
    lst.names.enumerate().map(((i, _)) => lst.morenames
      or lst.names.len() <= max-cite-names
      or i < u
      or i < min-cite-names)
  }
  for lst in lists {
    for (i, vis) in visible-of(lst).enumerate() {
      let ladder = name-ladder(lst.names.at(i))
      let nskey = _join(ladder)
      for ns in ladder {
        if vis { seen.visible = _add(seen.visible, ns, nskey) }
        seen.all = _add(seen.all, ns, nskey)
      }
    }
  }
  let levels = (:)
  let levels-all = (:)
  for lst in lists {
    let vis = visible-of(lst)
    let ladders = lst.names.map(name-ladder)
    levels.insert(lst.key, ladders.enumerate().map(((i, l)) =>
      if vis.at(i) { _level(seen.visible, l) } else { 0 }))
    levels-all.insert(lst.key, ladders.map(l => _level(seen.all, l)))
  }
  (visible: levels, all: levels-all)
}

// namelist_differs_index: the position at which this list first parts company
// with the most similar *other* complete list, or none when no other list even
// starts the same. A list that is a strict prefix of another reports its own
// last position, so the caller widens to the whole list.
#let _differs-index(list, finals) = {
  let index = none
  for l in finals {
    if l == list { continue }
    let i = 0
    while i < list.len() and i < l.len() and list.at(i) == l.at(i) {
      if index == none or i > index { index = i }
      i += 1
    }
  }
  if index == none { none }
  else if index == list.len() - 1 { index }
  else { index + 1 }
}

// namelist_differs_nth: is there another complete list, at least as long, that
// agrees with this one up to `n - 1` and differs at `n`? While there is, the
// list must keep its nth name to stay distinguishable.
#let _differs-nth(list, n, finals) = finals.any(l =>
  l.len() >= list.len()
    and l.at(n - 1) != list.at(n - 1)
    and l.slice(0, n - 1) == list.slice(0, n - 1))

// create_uniquelist_info + generate_uniquelist + DataList's set_uniquelist. Each
// list is reduced to one token per name — the form uniquename would print for it
// were it visible — and widened to the shortest prefix no other list shares.
#let ul-pass(lists, levels-all) = {
  let tokens = (:)
  for lst in lists {
    tokens.insert(lst.key, lst.names.enumerate().map(((i, f)) =>
      name-ladder(f).at(levels-all.at(lst.key).at(i))))
  }
  let prefixes = (:)
  let finals = (:)
  for lst in lists {
    let t = tokens.at(lst.key)
    for j in range(1, t.len() + 1) { prefixes = _bump(prefixes, _join(t.slice(0, j))) }
    finals = _bump(finals, _join(t))
  }
  let final-lists = lists.map(lst => tokens.at(lst.key)).dedup()
  let out = (:)
  for lst in lists {
    let t = tokens.at(lst.key)
    let n = t.len()
    let cut = n
    for j in range(1, n + 1) {
      if prefixes.at(_join(t.slice(0, j))) == 1 { cut = j; break }
    }
    let namelist = t.slice(0, cut)
    // A one-name prefix is no disambiguation at all, and a list never truncated
    // in the first place has nothing to widen. Widening below mincitenames would
    // likewise mean disambiguating with *less* information.
    let value = if cut <= 1 or n <= max-cite-names or (cut <= min-cite-names and min-cite-names != n) {
      none
    } else if finals.at(_join(namelist), default: 0) > 1 {
      // Identical lists cannot be told apart by widening, so widen only as far
      // as some *other*, similar list demands — and not at all if there is none.
      let idx = _differs-index(namelist, final-lists)
      if idx == none { none } else { idx + 1 }
    } else if n > cut and not _differs-nth(namelist, cut, final-lists) {
      // Nothing else branches away at this name, so it need not be shown: the
      // "et al." already distinguishes this list from the shorter one.
      cut - 1
    } else { cut }
    if value != none { out.insert(lst.key, value) }
  }
  out
}

// Biber alternates the two passes until neither changes anything. Each pass is a
// pure function of the other's output, so the loop is a plain fixed-point
// iteration; the bound only guards against an oscillation that biber's own
// change-flags would also have to break out of.
// `unique: false` is acmnumeric, which enables neither uniquename nor uniquelist:
// every name stays at the base of its ladder and a list past maxcitenames is cut
// to mincitenames with no widening, so two John/Jane Smiths both cite as "Smith".
#let disambiguate(lists, unique: true) = {
  if not unique {
    return lists.map(lst => {
      let visible = visible-count(lst, (:))
      (key: lst.key, levels: lst.names.map(_ => 0), visible: visible,
       truncated: visible < lst.names.len() or lst.morenames)
    })
  }
  let ul = (:)
  let un = (:)
  let rounds = 0
  while rounds < 16 {
    let pass = un-pass(lists, ul)
    let next-ul = ul-pass(lists, pass.all)
    let settled = pass.visible == un and next-ul == ul
    un = pass.visible
    ul = next-ul
    if settled { break }
    rounds += 1
  }
  lists.map(lst => {
    let visible = visible-count(lst, ul)
    (key: lst.key, levels: un.at(lst.key), visible: visible,
     truncated: visible < lst.names.len() or lst.morenames)
  })
}

// The printed label of a disambiguated name list.
#let list-label(lst, dis, useprefix: false) = join-label(
  lst.names.slice(0, dis.visible).enumerate().map(((i, f)) =>
    render-name(f, dis.levels.at(i), useprefix: useprefix)),
  dis.truncated)

// Whether the label this list produces OPENS with a generated initial that is
// nothing but punctuation — the "``Ali" case, where biblatex's \bibinitperiod
// is the period and the punctuation tracker decides whether to print it. A label
// that merely starts with a period of its own (a title like ".NET Article") is
// not one of these, which is why the cite layer needs this rather than a regex.
#let list-punct-initial(lst, dis, useprefix: false) = {
  if dis.visible == 0 or lst.names.len() == 0 { return false }
  if dis.levels.first() != 1 { return false }
  let f = lst.names.first()
  let lead = if f.giveni != "" { f.giveni } else if useprefix and f.prefixi != "" { f.prefixi } else { "" }
  lead != "" and not lead.trim(".", at: end).contains(regex("[\\p{L}\\p{N}]"))
}

// biber's _getnamehash (Internals.pm:40), which authoryear-comp compresses
// consecutive cites on: every part of every visible name, plus a marker when the
// list was truncated. It ignores uniquename entirely, so two entries that PRINT
// the same label — a Martin King with and without a suffix, both "King" — stay
// separate groups and take year letters instead of being merged.
#let list-namehash(lst, dis) = {
  let one = f => f.prefix + f.family + f.given + f.suffix
  lst.names.slice(0, dis.visible).map(one).join("") + if dis.truncated { "+" } else { "" }
}

// biber's _getnamehash_u, the context extradate groups entries by: the visible
// names' prefix and family plus whatever uniquename added, and a marker when the
// list was truncated. The prefix counts here even with `useprefix` off — the
// hash walks the uniquename template without applying its `use` test, so
// "Ludwig von Berg" and "Ludwig Berg" are separate groups although both print as
// "Berg".
#let list-context(lst, dis) = {
  let one = ((i, f)) => f.prefix + f.family + (
    if dis.levels.at(i) == 1 { f.giveni } else if dis.levels.at(i) == 2 { f.given } else { "" })
  lst.names.slice(0, dis.visible).enumerate().map(one).join("") + if dis.truncated { "+" } else { "" }
}

// A parsed name list ready for `disambiguate`: a trailing "and others" is a
// truncation marker, not a name.
#let name-list(key, people) = {
  let morenames = people.len() > 0 and is-others(people.last())
  let names = if morenames { people.slice(0, -1) } else { people }
  if names.len() == 0 { return none }
  (key: key, names: names.map(name-forms), morenames: morenames)
}
