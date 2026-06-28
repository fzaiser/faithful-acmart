// Title block / frontmatter for acmsmall (journal layout).
//
// Mirrors acmart's \maketitle for the journal formats: title (LARGE sans bold,
// left aligned), author lines (large sans uppercase names + small serif
// affiliation, grouped by shared affiliation), then abstract / CCS / keywords /
// ACM reference format. See the acmsmall-frontmatter-specs memory for sources.

#import "copyright.typ": permission-text, copyright-owner
#import "spacing.typ": comp, tex-skip
#import "journals.typ": lookup-journal

#let fnsymbols = ("*", "†", "‡", "§", "¶", "‖", "**", "††", "‡‡")

#let month-names = (
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
)

// acm-month/acm-year always carry a value (acmart defaults \acmMonth/\acmYear to
// the current date; see acmart() in lib.typ), so no presence check is needed.
// Assembled as content (not a joined string) so the year int renders directly.
#let pub-date(meta) = [#month-names.at(meta.acm-month - 1) #meta.acm-year]

// Join a list of names the ACM/amsart "andify" way ("a", "a and b",
// "a, b, and c"). Items may be strings (author names) or content (names carrying
// superscript note marks); the result is content in either case.
#let andify(items) = {
  let n = items.len()
  if n == 0 { return none }
  if n == 1 { return items.at(0) }
  if n == 2 { return items.slice(0, 2).join([ and ]) }
  (items.slice(0, n - 1).join([, ]), items.at(n - 1)).join([, and ])
}

// Fill in the optional author fields so the rest of the code can use plain field
// access (a.email, a.note, ...) instead of defensive `.at(..., default:)`.
#let normalize-author(a) = (
  name: a.name,
  affiliation: a.at("affiliation", default: none),
  email: a.at("email", default: none),
  note: a.at("note", default: none),
  corresponding: a.at("corresponding", default: false),
)

// An author's `affiliation` may be a single dict or an array of dicts (a person
// with several affiliations, like LaTeX's repeated \affiliation). Normalize to a
// list of dicts; none -> empty list.
#let affil-list(aff) = {
  if aff == none { () } else if type(aff) == array { aff } else { (aff,) }
}

// Join the present (non-none) values of `keys` from dict `d` with ", ". Returns
// none — not "" — when no field is present, so absence is *always* `none` (a
// single rule the callers can filter on uniformly).
#let join-fields(d, keys) = {
  let vals = keys.map(k => d.at(k, default: none)).filter(v => v != none)
  if vals.len() == 0 { none } else { vals.join(", ") }
}

// The present affiliation strings of `aff` (one ", "-joined run of `keys` per
// affiliation dict, empty affiliations dropped via join-fields' none).
#let affil-strings(aff, keys) = affil-list(aff).map(a => join-fields(a, keys)).filter(v => v != none)

// Title-block affiliation: institution, country (city/state go to contact info).
// Multiple affiliations are joined with " and ", as LaTeX joins institutions.
#let affil-short(aff) = {
  let affs = affil-strings(aff, ("institution", "country"))
  if affs.len() == 0 { none } else { affs.join(" and ") }
}

// Group consecutive authors that share an identical affiliation.
#let group-authors(authors) = {
  let groups = ()
  for a in authors {
    if groups.len() > 0 and groups.last().affiliation == a.affiliation {
      groups.last().authors.push(a)
    } else {
      groups.push((affiliation: a.affiliation, authors: (a,)))
    }
  }
  groups
}

// CCS concepts: group by area (preserving order), style specifics by
// significance (>=500 bold, >=300 italic, else roman), join with "; ",
// bullet + bold area + arrow per group, trailing period. Input: list of
// (significance, area, specific) tuples (mirrors \ccsdesc[sig]{area~specific}).
#let render-ccs-concepts(ccs) = {
  // preserve area order
  let areas = ()
  let by-area = (:)
  for entry in ccs {
    let (sig, area, ..rest) = entry
    let spec = if rest.len() > 0 { rest.at(0) } else { none }
    if area not in by-area {
      by-area.insert(area, ())
      areas.push(area)
    }
    if spec != none and spec != "" {
      by-area.at(area).push((sig: sig, spec: spec))
    }
  }
  let style-spec(s) = {
    if s.sig >= 500 { strong(s.spec) }
    else if s.sig >= 300 { emph(s.spec) }
    else { s.spec }
  }
  // \ccsdesc separates every concept (areas and specifics) with "; " and ends
  // with "." (acmart.dtx:5994-6006), so areas are joined by "; " too.
  for (i, area) in areas.enumerate() {
    if i > 0 { [; ] }
    [• #strong(area)]
    let specs = by-area.at(area)
    if specs.len() > 0 {
      [ → ]
      specs.map(style-spec).join("; ")
    }
  }
  [.]
}

// A full-width frontmatter text block at one font-size step (default "small" =
// 9pt), with intra-block leading and inter-paragraph spacing on the baseline
// grid (comp()). `indent` sets the first-line indent (0pt = none); `spacing` is
// the outer block gap to neighbours. Used for the abstract, CCS/keywords lines,
// and the ACM reference format.
#let fm-block(cfg, body, sz: "small", justify: true, indent: 0pt, spacing: 0pt) = {
  let lead = comp(cfg, sz: sz)
  block(width: 100%, spacing: spacing)[
    #set text(font: cfg.fonts.serif, size: cfg.size.at(sz))
    #set par(
      justify: justify,
      leading: lead,
      first-line-indent: if indent == 0pt { 0pt } else { (amount: indent, all: false) },
      spacing: lead,
    )
    #body
  ]
}

// A 9pt "Label: content" line used for CCS Concepts and Keywords.
// \@specialsection does `\par\medskip\small ...`, so the gap is \medskip before
// 9pt text (tex-skip with sz: "small"). See DESIGN.md "block vertical spacing".
#let special-line(cfg, label, content) = {
  v(tex-skip(cfg, cfg.medskip, sz: "small"), weak: true)
  fm-block(cfg, [#label: #content], justify: false, spacing: comp(cfg, sz: "small"))
}

// Assign footnote symbols across the whole top matter, matching acmart's shared
// footnote counter. \maketitle resets the counter and emits the texts in the
// order \@titlenotes, \@subtitlenotes, \@authornotes (acmart.dtx:6577-6581), all
// using \@fnsymbol marks (acmart.dtx:6571). So a title note takes the first
// symbol (*), a subtitle note the next, and author notes follow. Identical author
// notes are deduplicated; the corresponding-author ✉ is a fixed glyph (\ding{41},
// acmart.dtx:5430), NOT a counter step, so it consumes no symbol. In anonymous
// mode \authornote is suppressed (acmart.dtx:5406) while title/subtitle notes
// still appear with placeholder text (acmart.dtx:5360/5383).
//
// Returns the title/subtitle marks (for make-title), the ordered footnote list
// (for make-footnotes), and each author's superscript marks.
#let collect-notes(meta) = {
  let anon = meta.anonymous
  let notes = ()
  let idx = 0
  let title-mark = none
  let subtitle-mark = none

  if meta.title-note != none {
    title-mark = fnsymbols.at(idx)
    notes.push((symbol: title-mark, body: if anon { [Title note] } else { meta.title-note }))
    idx += 1
  }
  if meta.subtitle-note != none {
    subtitle-mark = fnsymbols.at(idx)
    notes.push((symbol: subtitle-mark, body: if anon { [Subtitle note] } else { meta.subtitle-note }))
    idx += 1
  }

  let seen = (:)
  let marks = ()
  for a in meta.authors {
    let m = ()
    if a.corresponding { m.push("✉") }
    if a.note != none and not anon {
      let key = repr(a.note)
      if key not in seen {
        seen.insert(key, fnsymbols.at(idx))
        notes.push((symbol: seen.at(key), body: a.note))
        idx += 1
      }
      m.push(seen.at(key))
    }
    marks.push(m)
  }
  (title-mark: title-mark, subtitle-mark: subtitle-mark, notes: notes, marks: marks)
}

// One author's contact entry, replaying name → affiliation fields → email in
// that order (email LAST), matching LaTeX \@mkauthorsaddresses (acmart.dtx:7588).
// Authors are listed individually in source order with the affiliation repeated
// per author — NOT grouped. (LaTeX also allows multiple affiliations per author,
// joined by " and "; our data model carries one affiliation each.)
#let contact-line(a) = {
  let parts = (a.name,)
  // each affiliation as "institution, city, state, country"; several joined by
  // " and " (LaTeX's institution separator), then email last.
  let affs = affil-strings(a.affiliation, ("institution", "city", "state", "country"))
  if affs.len() > 0 { parts.push(affs.join(" and ")) }
  if a.email != none { parts.push(a.email) }
  parts.join(", ")
}

// The page-1 footnote stack: author notes, authors' contact information, and the
// copyright/permission block, each with a rule above. Placed at the bottom of
// the first page's text area.
#let make-footnotes(cfg, meta) = {
  let fs = cfg.size.footnotesize
  let lead = comp(cfg, sz: "footnotesize")
  let ni = collect-notes(meta)
  let j = lookup-journal(meta.journal)

  let rule(width) = {
    v(cfg.footnote-rule-kern-above, weak: true)
    line(length: width, stroke: 0.4pt)
    v(cfg.footnote-rule-kern-below, weak: true)
  }

  let stack = {
    set text(font: cfg.fonts.serif, size: fs)
    set par(justify: true, leading: lead, first-line-indent: 0pt, spacing: lead)

    let anon = meta.anonymous

    // 1. Title/subtitle/author notes (regular footnotes, symbol marks). collect-notes
    // already excludes author notes under anonymity but keeps title/subtitle notes.
    if ni.notes.len() > 0 {
      rule(cfg.footnote-rule-short)
      for n in ni.notes {
        block(spacing: lead)[#super(n.symbol)#n.body]
      }
    }

    // 2. Authors' Contact Information (suppressed in anonymous mode)
    if not anon and meta.authors.len() > 0 and meta.authors.any(a => a.affiliation != none or a.email != none) {
      rule(100%)
      let label = if meta.authors.len() > 1 { "Authors' Contact Information:" } else { "Author's Contact Information:" }
      let contacts = meta.authors.map(contact-line).join("; ")
      block(spacing: lead)[#label #contacts.]
    }

    // 3. Copyright / permission (faithful to acmart's assembly). nonacm
    // suppresses this whole block — including the © line and ACM bibstrip —
    // except cc mode, which still prints its permission text (acmart.dtx:6599-6661).
    let mode = meta.copyright
    let ptext = permission-text(mode, cc-type: meta.cc-type, cc-version: meta.cc-version)
    if meta.nonacm {
      if mode == "cc" and ptext != none {
        rule(100%)
        block(spacing: lead, ptext)
      }
    } else {
      rule(100%)
      block(spacing: lead, {
        if ptext != none { ptext; parbreak() }
        set par(justify: false)
        // © <year> <owner>  (copyright-year always has a value; see acmart() in lib.typ)
        let owner = copyright-owner(mode)
        if owner != none {
          [© #meta.copyright-year #owner]
          linebreak()
        } else {
          [#meta.copyright-year. ]
        }
        // journal bibstrip: ACM <issn>/<year>/<month>-ART<article> then DOI
        // (acmart.dtx:6651). \@acmArticle defaults to empty, so ART may have no number.
        // str() on the month delimits the number from the following "-ART" (markup
        // would otherwise read "acm-month-ART" as one hyphenated identifier).
        [ACM #j.issn/#str(meta.acm-year)/#str(meta.acm-month)-ART#{
          if meta.acm-article != none { str(meta.acm-article) }
        }]
        if meta.doi != none {
          linebreak()
          link("https://doi.org/" + meta.doi)[https:\/\/doi.org\/#meta.doi]
        }
      })
    }
  }

  // float: true so the block reserves space at the bottom of the first page and
  // the body text flows above it (rather than overlapping).
  place(bottom, float: true, block(width: 100%, spacing: 0pt, stack))
}

#let make-title(cfg, meta) = {
  let ni = collect-notes(meta)
  // --- Title (LARGE sans bold, left-aligned) ---
  block(spacing: 0pt)[
    // top-edge: cap-height places the (tall) first line's cap-top at the top
    // margin, matching LaTeX \topskip behaviour for a first line taller than it.
    #set text(font: cfg.fonts.sans, weight: "bold", size: cfg.size.LARGE, top-edge: "cap-height")
    #set par(justify: false, leading: comp(cfg, sz: "LARGE"))
    #meta.title#if ni.title-mark != none { super(ni.title-mark) }
  ]
  // Subtitle (\@subtitlefont = \normalsize\mdseries, inherits the sans family);
  // its own block so it gets normalsize leading, not the title's LARGE leading.
  // LaTeX `\par` puts it one normalsize baselineskip below the title.
  if meta.subtitle != none {
    block(spacing: tex-skip(cfg, 0pt))[
      #set text(font: cfg.fonts.sans, weight: "regular", size: cfg.font-size)
      #set par(justify: false, leading: comp(cfg))
      #meta.subtitle#if ni.subtitle-mark != none { super(ni.subtitle-mark) }
    ]
  }

  // Title box ends with \par\bigskip; \@mkauthors@i prepends \par\medskip before
  // the author lines (at \large). So the gap is \bigskip + \medskip before 10.95pt.
  v(tex-skip(cfg, cfg.bigskip + cfg.medskip, sz: "large"), weak: true)

  // --- Authors (grouped by affiliation) ---
  // Anonymous review: replace the whole author strip with "Anonymous Author(s)".
  if meta.anonymous {
    block(spacing: 0pt)[
      #set text(font: cfg.fonts.sans, size: cfg.size.large)
      #upper[Anonymous Author(s)]
    ]
  } else {
  let marked = meta.authors.enumerate().map(((i, a)) => {
    let a2 = a
    a2.insert("_marks", ni.marks.at(i))
    a2
  })
  block(spacing: 0pt)[
    #set par(justify: false, leading: comp(cfg, sz: "large"), spacing: 0pt)
    #for g in group-authors(marked) {
      let names = g.authors.map(a => {
        upper(a.name)
        // note marks (superscript symbols); the ✉ glyph is large, so shrink it
        for m in a._marks {
          if m == "✉" { super(text(size: 0.72em)[#m]) } else { super(m) }
        }
      })
      block(spacing: comp(cfg, sz: "large"))[
        // andify preserves the per-name content marks (superscript symbols).
        #text(font: cfg.fonts.sans, size: cfg.size.large)[#andify(names)]#{
          let aff = affil-short(g.affiliation)
          if aff != none {
            text(font: cfg.fonts.serif, size: cfg.size.small)[, #aff]
          }
        }
      ]
    }
  ]
  } // end non-anonymous author block

  // --- Teaser figure (between authors and abstract) ---
  // \@mkteasers appends each teaser to the title box with \par\bigskip above and
  // a closing \medskip (acmart.dtx:7663-7671): a full-text-width figure in the
  // one-column journal layout. With no teaser, the trailing \medskip is the normal
  // author-box gap to the abstract.
  if meta.teaser != none {
    v(tex-skip(cfg, cfg.bigskip), weak: true)
    block(width: 100%, spacing: 0pt, meta.teaser)
  }
  // author box trailing \par\medskip; next block (abstract/CCS/...) is 9pt
  v(tex-skip(cfg, cfg.medskip, sz: "small"), weak: true)

  // --- Abstract (9pt, no heading label, paragraphs indented \parindent) ---
  if meta.abstract != none {
    fm-block(cfg, meta.abstract, indent: cfg.parindent)
  }

  // --- CCS Concepts (suppressed by \settopmatter{printccs=false}) ---
  if meta.ccs != none and meta.print-ccs {
    special-line(cfg, [CCS Concepts], render-ccs-concepts(meta.ccs))
  }

  // --- Keywords ---
  if meta.keywords != none {
    let kw = if type(meta.keywords) == array { meta.keywords.join(", ") } else { meta.keywords }
    // journals use \keywordsname = "Additional Key Words and Phrases" (acmart.dtx:3294);
    // plain "Keywords" is only for the conference formats.
    special-line(cfg, [Additional Key Words and Phrases], kw)
  }

  // --- ACM Reference Format ---
  if meta.show-ref {
    let j = lookup-journal(meta.journal)
    // \@mkbibcitation does `\par\medskip\small ...`; next block is 9pt
    v(tex-skip(cfg, cfg.medskip, sz: "small"), weak: true)
    context {
      let total = counter(page).final().first()
      fm-block(cfg, [
        #strong[ACM Reference Format:]\
        #{ if meta.anonymous [Anonymous Author(s)] else { andify(meta.authors.map(a => a.name)) } }. #meta.acm-year. #meta.title#{
          if meta.subtitle != none [: #meta.subtitle]
        }. #if j.short != none { emph(j.short) + " " }#meta.acm-volume, #meta.acm-number#if meta.acm-article != none [, Article #meta.acm-article] (#pub-date(meta)), #total #if total == 1 [page] else [pages].#{
          if meta.doi != none [ #link("https://doi.org/" + meta.doi)[https:\/\/doi.org\/#meta.doi]]
        }
      ])
    }
  }

  // \@printendtopmatter \par\bigskip; next block is the body at 10pt
  v(tex-skip(cfg, cfg.bigskip), weak: true)
}

// Format a paper-history line for \received. acmart accumulates calls into one
// string: the first stage defaults to "Received <date>", later stages append
// "; <stage> <date>" (acmart.dtx:5844-5857). We accept either:
//   - content/string -> used verbatim, or
//   - an array of items, each a (stage, date) pair or a bare date; the first
//     item's empty/none stage becomes "Received", later empty stages "revised".
#let format-received(received) = {
  if type(received) != array { return received }
  let parts = ()
  for (i, item) in received.enumerate() {
    let (stage, date) = if type(item) == array { (item.at(0), item.at(1)) } else { (none, item) }
    let s = if stage == none or stage == "" {
      if i == 0 { "Received" } else { "revised" }
    } else { stage }
    parts.push([#s #date])
  }
  parts.join([; ])
}

// The paper-history line, printed at the very end of the document
// (acmart \AtEndDocument, acmart.dtx:5858-5861): \par\bigskip then \small
// \normalfont (9pt serif roman), unindented.
#let make-received(cfg, received) = {
  v(tex-skip(cfg, cfg.bigskip, sz: "small"), weak: true)
  block(width: 100%, spacing: 0pt)[
    #set text(font: cfg.fonts.serif, weight: "regular", style: "normal", size: cfg.size.small)
    #set par(justify: false, leading: comp(cfg, sz: "small"), first-line-indent: 0pt)
    #format-received(received)
  ]
}

// Artifact-evaluation badges for the first-page header (acmart firstpagestyle,
// acmsmall: \@acmBadgeL at left, \@acmBadgeR at right; acmart.dtx:8203-8206).
// `badges` is a dict with optional `left`/`right` content (typically an image at
// `cfg.badge-width` wide, optionally wrapped in a link). Returns header content.
#let make-badges(cfg, badges) = {
  if badges == none { return none }
  let l = badges.at("left", default: none)
  let r = badges.at("right", default: none)
  grid(columns: (1fr, 1fr),
    align(left + bottom, if l != none { l }),
    align(right + bottom, if r != none { r }))
}
