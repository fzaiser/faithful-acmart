// Title block / frontmatter for acmsmall (journal layout).
//
// Mirrors acmart's \maketitle for the journal formats: title (LARGE sans bold,
// left aligned), author lines (large sans uppercase names + small serif
// affiliation, grouped structurally per acmart — see group-authors), then
// abstract / CCS / keywords /
// ACM reference format. See the acmsmall-frontmatter-specs memory for sources.

#import "copyright.typ": permission-text, copyright-owner
#import "spacing.typ": comp, tex-skip
#import "journals.typ": lookup-journal
#import "strings.typ": lang-record

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

// Group authors exactly as acmart's \@mkauthors@i does (acmart.dtx:7337-7371) —
// the unconditional rule for journal formats incl. acmsmall (the \@mkauthors
// \ifcase routes acmsmall to @i, acmart.dtx:7160). Authors accumulate onto one
// line; an \affiliation closes that line and attaches itself to EVERY author
// accumulated so far, then the next author starts a fresh line. Consequences,
// matching acmart and NOT a value comparison (acmart never compares affiliations):
//   - an author with no affiliation is andified onto the following author(s);
//   - authors that each carry an affiliation get their own line, even when the
//     affiliations are identical;
//   - trailing affiliation-less authors share a final, affiliation-less line.
#let group-authors(authors) = {
  let groups = ()
  let pending = ()
  for a in authors {
    pending.push(a)
    if a.affiliation != none {
      groups.push((affiliation: a.affiliation, authors: pending))
      pending = ()
    }
  }
  if pending.len() > 0 {
    groups.push((affiliation: none, authors: pending))
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

// authordraft stamps the page-1 copyright block with a black large-bold notice
// overlaying the (greyed) copyright text (acmart.dtx:6606-6610). place() gives it
// zero size, so the copyright lines flow behind it.
#let draft-stamp(cfg) = place(top + left, text(size: cfg.size.large, weight: "bold")[Unpublished working draft. Not for distribution.])

// The conference info line in the copyright block (acmart.dtx:6618-6620): italic
// "<conference short>, <conference venue>", or the engage/booktitle form
// "<booktitle>, <year>.". none when no conference metadata was supplied.
#let conf-info-line(meta) = {
  if meta.conference != none {
    let c = meta.conference
    let short = c.at("short", default: c.at("name", default: none))
    let venue = c.at("venue", default: none)
    let parts = (short, venue).filter(v => v != none)
    if parts.len() > 0 { emph(parts.join(", ")) }
  } else if meta.booktitle != none {
    emph[#meta.booktitle, #meta.acm-year.]
  }
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

    // 2. Authors' Contact Information — only the journal/tog formats print this
    // footnote (\if@ACM@journal@bibstrip@or@tog, acmart.dtx:6592); the conference
    // formats carry contact info in the author grid instead. Suppressed if anon.
    if meta.bibstrip and not anon and meta.authors.len() > 0 and meta.authors.any(a => a.affiliation != none or a.email != none) {
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
    } else if meta.author-version {
      // author-version: drop the permission text (acmart.dtx:6612) and replace
      // the ACM bibstrip with the author's-version notice, naming the full
      // (emphasized) journal and the DOI (acmart.dtx:6634-6647). Unlike the short
      // bibstrip lines below, this is a running paragraph, so it stays justified
      // (inherited from the footnote stack) rather than ragged.
      rule(100%)
      block(spacing: lead, {
        if meta.author-draft { draft-stamp(cfg) }
        set text(fill: if meta.author-draft { luma(90%) } else { black })
        let owner = copyright-owner(mode)
        if owner != none { [© #meta.copyright-year #owner] } else { [#meta.copyright-year.] }
        linebreak()
        [This is the author's version of the work. It is posted here for your personal use. Not for redistribution. The definitive Version of Record was published in #emph(j.name)#{
          if meta.doi != none [, #link("https://doi.org/" + meta.doi)[https:\/\/doi.org\/#meta.doi].]
          else [.]
        }]
      })
    } else {
      rule(100%)
      block(spacing: lead, {
        if meta.author-draft { draft-stamp(cfg) }
        set text(fill: if meta.author-draft { luma(90%) } else { black })
        if ptext != none { ptext; parbreak() }
        set par(justify: false)
        // Conference info line, between the permission text and the © line
        // (acmart.dtx:6615-6622): italic "<conf short>, <conf venue>", or for the
        // engage/booktitle path "<booktitle>, <year>.". Journal/tog skip it.
        if not meta.bibstrip {
          let cl = conf-info-line(meta)
          if cl != none { cl; linebreak() }
        }
        // © <year> <owner>  (copyright-year always has a value; see acmart() in lib.typ)
        let owner = copyright-owner(mode)
        if owner != none {
          [© #meta.copyright-year #owner]
          linebreak()
        } else {
          [#meta.copyright-year. ]
        }
        // Final line: manuscript notice / journal bibstrip / conference ISBN+DOI
        // (acmart.dtx:6631-6656).
        if cfg.name == "manuscript" {
          [Manuscript submitted to ACM]
        } else if meta.bibstrip {
          // ACM <issn>/<year>/<month>-ART<article> then DOI (acmart.dtx:6651).
          // \@acmArticle defaults to empty, so ART may have no number. str() on the
          // month delimits the number from the following "-ART" (markup would
          // otherwise read "acm-month-ART" as one hyphenated identifier).
          [ACM #j.issn/#str(meta.acm-year)/#str(meta.acm-month)-ART#{
            if meta.acm-article != none { str(meta.acm-article) }
          }]
          if meta.doi != none {
            linebreak()
            link("https://doi.org/" + meta.doi)[https:\/\/doi.org\/#meta.doi]
          }
        } else {
          // conference: ACM ISBN <isbn> then DOI (acmart.dtx:6654).
          if meta.isbn != none { [ACM ISBN #meta.isbn]; linebreak() }
          if meta.doi != none {
            link("https://doi.org/" + meta.doi)[https:\/\/doi.org\/#meta.doi]
          }
        }
      })
    }
  }

  // float: true so the block reserves space at the bottom of the first page and
  // the body text flows above it (rather than overlapping).
  place(bottom, float: true, block(width: 100%, spacing: 0pt, stack))
}

// The journal @i spanning head (acmart.dtx:6986): left-aligned title/subtitle,
// then the andified author *list* with short affiliations. Used by the single-
// column journals and by acmtog (two-column journal). The conference formats use
// conf-title-head instead; make-title-head dispatches on cfg.title-style.
#let journal-title-head(cfg, meta) = {
  let ni = collect-notes(meta)
  // \@titlefont / \@subtitlefont differ per format (acmart.dtx:6911/6946); the
  // family/weight/size come from the format dict.
  let tf = cfg.title-font
  let sf = cfg.subtitle-font
  // --- Title (journal @i: left-aligned; font per format) ---
  block(spacing: 0pt)[
    // top-edge: cap-height places the (tall) first line's cap-top at the top
    // margin, matching LaTeX \topskip behaviour for a first line taller than it.
    #set text(font: cfg.fonts.at(tf.family), weight: tf.weight, size: cfg.size.at(tf.size), top-edge: "cap-height")
    #set par(justify: false, first-line-indent: 0pt, leading: comp(cfg, sz: tf.size), spacing: comp(cfg, sz: tf.size))
    #meta.title#if ni.title-mark != none { super(ni.title-mark) }
    // \@translatedtitle: each secondary title is a new \par in the title font
    // (acmart.dtx:3374/6994), one baselineskip below (par spacing = leading).
    #for (l, t) in meta.translated-title {
      parbreak()
      text(lang: lang-record(l).code, t)
    }
  ]
  // Subtitle (\@subtitlefont = \normalsize\mdseries, inherits the sans family);
  // its own block so it gets normalsize leading, not the title's LARGE leading.
  // LaTeX `\par` puts it one normalsize baselineskip below the title.
  if meta.subtitle != none {
    block(spacing: tex-skip(cfg, 0pt))[
      #set text(font: cfg.fonts.at(sf.family), weight: sf.weight, size: cfg.size.at(sf.size))
      #set par(justify: false, first-line-indent: 0pt, leading: comp(cfg, sz: sf.size), spacing: comp(cfg, sz: sf.size))
      #meta.subtitle#if ni.subtitle-mark != none { super(ni.subtitle-mark) }
      // \@translatedsubtitle: each in the subtitle font (acmart.dtx:3391/6996).
      #for (l, t) in meta.translated-subtitle {
        parbreak()
        text(lang: lang-record(l).code, t)
      }
    ]
  }

  // Author-list fonts come from the format dict (acmart.dtx:7206 \@authorfont /
  // \@affiliationfont): acmsmall \large sans names + \small serif affils (the
  // make-format defaults), acmtog \LARGE sans + \large. The size step also drives
  // the leading and the title->authors gap.
  let af = cfg.author-font
  let aff-f = cfg.affil-font
  // Title box ends with \par\bigskip; \@mkauthors@i prepends \par\medskip before
  // the author lines (at the author size). gap = \bigskip + \medskip.
  v(tex-skip(cfg, cfg.bigskip + cfg.medskip, sz: af.size), weak: true)

  // --- Authors (grouped structurally per acmart; see group-authors) ---
  // Anonymous review: replace the whole author strip with "Anonymous Author(s)".
  if meta.anonymous {
    block(spacing: 0pt)[
      #set text(font: cfg.fonts.at(af.family), weight: af.weight, size: cfg.size.at(af.size))
      #upper[Anonymous Author(s)]
    ]
  } else {
  let marked = meta.authors.enumerate().map(((i, a)) => {
    let a2 = a
    a2.insert("_marks", ni.marks.at(i))
    a2
  })
  block(spacing: 0pt)[
    #set par(justify: false, leading: comp(cfg, sz: af.size), spacing: 0pt)
    #for g in group-authors(marked) {
      let names = g.authors.map(a => {
        upper(a.name)
        // note marks (superscript symbols); the ✉ glyph is large, so shrink it
        for m in a._marks {
          if m == "✉" { super(text(size: 0.72em)[#m]) } else { super(m) }
        }
      })
      block(spacing: comp(cfg, sz: af.size))[
        // andify preserves the per-name content marks (superscript symbols).
        #text(font: cfg.fonts.at(af.family), weight: af.weight, size: cfg.size.at(af.size))[#andify(names)]#{
          let aff = affil-short(g.affiliation)
          if aff != none {
            text(font: cfg.fonts.at(aff-f.family), weight: aff-f.weight, size: cfg.size.at(aff-f.size))[, #aff]
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
}

// Conference author grid (\@mkauthors@iii, acmart.dtx:7438): one centered box per
// affiliation group (same group-authors rule as the journal list), laid out N per
// row. acmart's box width is (textwidth - sep)/N - sep with sep = \author@bx@sep
// (1pc); N defaults from the group count (1-3 -> that many, 4 -> 2, 5+ -> 3) and
// is overridable with authors-per-row. Names are mixed-case (not uppercased like
// the journal list); fonts are cfg.author-font / cfg.affil-font.
#let make-authors-grid(cfg, groups, authors-per-row: 0) = {
  let sep = 12pt // \author@bx@sep = 1pc
  let tw = cfg.paper.width - cfg.margin.inside - cfg.margin.outside
  let n = if authors-per-row > 0 { authors-per-row } else {
    let g = groups.len()
    if g <= 3 { g } else if g == 4 { 2 } else { 3 }
  }
  let bw = (tw - sep) / n - sep
  let af = cfg.author-font
  let aff = cfg.affil-font
  let author-box(group) = {
    set align(center)
    set text(font: cfg.fonts.at(af.family), weight: af.weight, size: cfg.size.at(af.size))
    set par(justify: false, leading: comp(cfg, sz: af.size), spacing: comp(cfg, sz: af.size))
    andify(group.authors.map(a => {
      a.name
      for m in a._marks {
        if m == "✉" { super(text(size: 0.72em)[#m]) } else { super(m) }
      }
    }))
    parbreak()
    set text(font: cfg.fonts.at(aff.family), weight: aff.weight, size: cfg.size.at(aff.size))
    set par(leading: comp(cfg, sz: aff.size), spacing: comp(cfg, sz: aff.size))
    // affiliation lines (institution, city, state, country) then emails, each on
    // its own line (acmart appends \email to \@currentaffiliation as \par lines).
    let affs = affil-strings(group.affiliation, ("institution", "city", "state", "country"))
    let emails = group.authors.map(a => a.email).filter(e => e != none)
    (affs + emails).join(linebreak())
  }
  // One grid of N columns auto-wraps to rows; row-gutter = \lineskip (1pc).
  align(center, grid(
    columns: (bw,) * n,
    column-gutter: sep,
    row-gutter: 12pt,
    ..groups.map(author-box),
  ))
}

// The conference @mktitle@iii spanning head (acmart.dtx:7018): CENTERED title and
// subtitle, then the centered author grid. Fonts come from the format dict.
#let conf-title-head(cfg, meta) = {
  let ni = collect-notes(meta)
  let tf = cfg.title-font
  let sf = cfg.subtitle-font
  set align(center)
  block(spacing: 0pt)[
    #set text(font: cfg.fonts.at(tf.family), weight: tf.weight, size: cfg.size.at(tf.size), top-edge: "cap-height")
    #set par(justify: false, first-line-indent: 0pt, leading: comp(cfg, sz: tf.size), spacing: comp(cfg, sz: tf.size))
    #meta.title#if ni.title-mark != none { super(ni.title-mark) }
    #for (l, t) in meta.translated-title { parbreak(); text(lang: lang-record(l).code, t) }
  ]
  if meta.subtitle != none {
    block(spacing: tex-skip(cfg, 0pt))[
      #set text(font: cfg.fonts.at(sf.family), weight: sf.weight, size: cfg.size.at(sf.size))
      #set par(justify: false, first-line-indent: 0pt, leading: comp(cfg, sz: sf.size), spacing: comp(cfg, sz: sf.size))
      #meta.subtitle#if ni.subtitle-mark != none { super(ni.subtitle-mark) }
      #for (l, t) in meta.translated-subtitle { parbreak(); text(lang: lang-record(l).code, t) }
    ]
  }
  // title box \par\bigskip + @mkauthors@iii leading \par\medskip before the boxes
  v(tex-skip(cfg, cfg.bigskip + cfg.medskip), weak: true)
  if meta.anonymous {
    block(spacing: 0pt)[
      #set text(font: cfg.fonts.at(cfg.author-font.family), size: cfg.size.at(cfg.author-font.size))
      Anonymous Author(s)
    ]
  } else {
    let marked = meta.authors.enumerate().map(((i, a)) => {
      let a2 = a
      a2.insert("_marks", ni.marks.at(i))
      a2
    })
    make-authors-grid(cfg, group-authors(marked), authors-per-row: meta.authors-per-row)
  }
  if meta.teaser != none {
    v(tex-skip(cfg, cfg.bigskip), weak: true)
    block(width: 100%, spacing: 0pt, meta.teaser)
  }
  // closing \par\bigskip of \mktitle@bx (the float clearance adds the gap to body)
  v(tex-skip(cfg, cfg.bigskip), weak: true)
}

// Dispatch the spanning head on the format's title style (acmart.dtx:6874).
#let make-title-head(cfg, meta) = if cfg.title-style == "conf-center" {
  conf-title-head(cfg, meta)
} else {
  journal-title-head(cfg, meta)
}

// In-column top matter: abstract / CCS / keywords / ACM reference format. In
// two-column formats these follow \@printtopmatter (acmart.dtx:6665) and so flow
// in the FIRST column beneath the spanning title box; in one column they are
// contiguous with the head. The leading weak skip collapses at a column top.
#let make-title-body(cfg, meta) = {
  // --- Abstract (9pt, no heading label, paragraphs indented \parindent) ---
  if meta.abstract != none {
    fm-block(cfg, meta.abstract, indent: cfg.parindent)
  }
  // Translated abstracts: each is another 9pt block in its own language, right
  // after the main one (journals print no \abstractname; acmart.dtx:6666/7706).
  for (l, ab) in meta.translated-abstract {
    fm-block(cfg, text(lang: lang-record(l).code, ab), indent: cfg.parindent)
  }

  // --- CCS Concepts (suppressed by \settopmatter{printccs=false}) ---
  if meta.ccs != none and meta.print-ccs {
    special-line(cfg, [CCS Concepts], render-ccs-concepts(meta.ccs))
  }

  // --- Keywords ---
  // journals use \keywordsname = "Additional Key Words and Phrases" (acmart.dtx:3294);
  // plain "Keywords" is only for the conference formats. The label is localized
  // to the main language (meta.strings.keywords).
  let kw-join = kw => if type(kw) == array { kw.join(", ") } else { kw }
  if meta.keywords != none {
    special-line(cfg, meta.strings.keywords, kw-join(meta.keywords))
  }
  // Translated keywords (secondary languages): each block carries \keywordsname
  // in its own language and sets that language for hyphenation (acmart.dtx:5338).
  for (l, kw) in meta.translated-keywords {
    let rec = lang-record(l)
    special-line(cfg, rec.keywords, text(lang: rec.code, kw-join(kw)))
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

// One-column path: the head and in-column body are contiguous, exactly as the
// old single make-title. Two-column formats call the two halves separately (the
// head inside a spanning float), so this wrapper is the single-column entry.
#let make-title(cfg, meta) = {
  make-title-head(cfg, meta)
  make-title-body(cfg, meta)
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
