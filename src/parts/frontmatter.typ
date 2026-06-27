// Title block / frontmatter for acmsmall (journal layout).
//
// Mirrors acmart's \maketitle for the journal formats: title (LARGE sans bold,
// left aligned), author lines (large sans uppercase names + small serif
// affiliation, grouped by shared affiliation), then abstract / CCS / keywords /
// ACM reference format. See the acmsmall-frontmatter-specs memory for sources.

#let fnsymbols = ("*", "†", "‡", "§", "¶", "‖", "**", "††", "‡‡")

#let month-names = (
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
)

// journal key -> (name, short, issn). issn is acmart's \@permissionCodeTwo,
// used in the "ACM <issn>/<year>/<month>-ART<article>" copyright line.
#let journals = (
  JACM: (name: "Journal of the ACM", short: "J. ACM", issn: "1557-735X"),
  TOG:  (name: "ACM Transactions on Graphics", short: "ACM Trans. Graph.", issn: "1557-7368"),
  CSUR: (name: "ACM Computing Surveys", short: "ACM Comput. Surv.", issn: "1557-7341"),
  TOMS: (name: "ACM Transactions on Mathematical Software", short: "ACM Trans. Math. Softw.", issn: "1557-7295"),
  POMACS: (name: "Proceedings of the ACM on Measurement and Analysis of Computing Systems", short: "Proc. ACM Meas. Anal. Comput. Syst.", issn: "2476-1249"),
  PACMPL: (name: "Proceedings of the ACM on Programming Languages", short: "Proc. ACM Program. Lang.", issn: "2475-1421"),
)

#let lookup-journal(key) = {
  if key == none { return (name: none, short: none, issn: "XXXX-XXXX") }
  let s = str(key)
  journals.at(s, default: (name: s, short: s, issn: "XXXX-XXXX"))
}

#let pub-date(meta) = {
  let parts = ()
  if meta.acm-month != none { parts.push(month-names.at(meta.acm-month - 1)) }
  if meta.acm-year != none { parts.push(str(meta.acm-year)) }
  parts.join(" ")
}

// Join a list of name strings the ACM/amsart "andify" way.
#let andify(names) = {
  let n = names.len()
  if n == 0 { return none }
  if n == 1 { return names.at(0) }
  if n == 2 { return names.at(0) + " and " + names.at(1) }
  names.slice(0, n - 1).join(", ") + ", and " + names.at(n - 1)
}

// Title-block affiliation: institution, country (city/state go to contact info).
#let affil-short(aff) = {
  if aff == none { return none }
  let parts = ()
  if "institution" in aff and aff.institution != none { parts.push(aff.institution) }
  if "country" in aff and aff.country != none { parts.push(aff.country) }
  parts.join(", ")
}

// Group consecutive authors that share an identical affiliation.
#let group-authors(authors) = {
  let groups = ()
  for a in authors {
    let aff = a.at("affiliation", default: none)
    if groups.len() > 0 and groups.last().affiliation == aff {
      groups.last().authors.push(a)
    } else {
      groups.push((affiliation: aff, authors: (a,)))
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
  for (i, area) in areas.enumerate() {
    if i > 0 { [ ] }
    [• #strong(area)]
    let specs = by-area.at(area)
    if specs.len() > 0 {
      [ → ]
      specs.map(style-spec).join("; ")
    }
  }
  [.]
}

// A 9pt "Label: content" line used for CCS Concepts and Keywords.
#let special-line(cfg, label, content) = {
  v(cfg.medskip, weak: true)
  block(width: 100%, spacing: cfg.bls.small - cfg.size.small)[
    #set text(font: cfg.fonts.serif, size: cfg.size.small)
    #set par(justify: false, leading: cfg.bls.small - cfg.size.small,
      first-line-indent: 0pt, spacing: cfg.bls.small - cfg.size.small)
    #label: #content
  ]
}

// Assign footnote symbols to author notes (deduplicating identical notes), and
// compute each author's superscript marks (corresponding ✉ then note symbol).
#let collect-notes(authors) = {
  let notes = ()
  let seen = (:)
  let marks = ()
  for a in authors {
    let m = ()
    if a.at("corresponding", default: false) { m.push("✉") }
    let note = a.at("note", default: none)
    if note != none {
      let key = repr(note)
      if key not in seen {
        seen.insert(key, fnsymbols.at(notes.len()))
        notes.push((symbol: seen.at(key), body: note))
      }
      m.push(seen.at(key))
    }
    marks.push(m)
  }
  (notes: notes, marks: marks)
}

// Full contact line for one affiliation group: "Name, email" per author joined
// with "; ", then the shared affiliation appended after the last author.
#let contact-group(g) = {
  let aff = g.affiliation
  let people = g.authors.map(a => {
    let bits = (a.name,)
    if a.at("email", default: none) != none { bits.push(a.email) }
    bits.join(", ")
  }).join("; ")
  let affbits = ()
  if aff != none {
    for k in ("institution", "city", "state", "country") {
      if k in aff and aff.at(k) != none { affbits.push(aff.at(k)) }
    }
  }
  if affbits.len() > 0 { people + ", " + affbits.join(", ") } else { people }
}

// Copyright permission text by mode (currently the common acmlicensed wording,
// extracted from acmart output). Other modes fall back to this.
#let permission-text(copyright) = [
  Permission to make digital or hard copies of all or part of this work for
  personal or classroom use is granted without fee provided that copies are not
  made or distributed for profit or commercial advantage and that copies bear
  this notice and the full citation on the first page. Copyrights for components
  of this work owned by others than the author(s) must be honored. Abstracting
  with credit is permitted. To copy otherwise, or republish, to post on servers
  or to redistribute to lists, requires prior specific permission and\/or a fee.
  Request permissions from permissions\@acm.org.
]

#let copyright-line(copyright, year) = {
  let y = if year != none { str(year) } else { "" }
  if copyright == "acmlicensed" {
    [© #y Copyright held by the owner/author(s). Publication rights licensed to ACM.]
  } else if copyright == "rightsretained" {
    [© #y Copyright held by the owner/author(s).]
  } else if copyright == "acmcopyright" {
    [© #y Association for Computing Machinery.]
  } else {
    [© #y Copyright held by the owner/author(s).]
  }
}

// The page-1 footnote stack: author notes, authors' contact information, and the
// copyright/permission block, each with a rule above. Placed at the bottom of
// the first page's text area.
#let make-footnotes(cfg, meta) = {
  let fs = cfg.size.footnotesize
  let lead = cfg.bls.footnotesize - fs
  let ni = collect-notes(meta.authors)
  let j = lookup-journal(meta.journal)

  let rule(width) = {
    v(cfg.footnote-rule-kern-above, weak: true)
    line(length: width, stroke: 0.4pt)
    v(cfg.footnote-rule-kern-below, weak: true)
  }

  let stack = {
    set text(font: cfg.fonts.serif, size: fs)
    set par(justify: true, leading: lead, first-line-indent: 0pt, spacing: lead)

    // 1. Author notes (regular footnotes, symbol marks)
    if ni.notes.len() > 0 {
      rule(cfg.footnote-rule-short)
      for n in ni.notes {
        block(spacing: lead)[#super(n.symbol)#n.body]
      }
    }

    // 2. Authors' Contact Information
    if meta.authors.len() > 0 and meta.authors.any(a => a.at("affiliation", default: none) != none or a.at("email", default: none) != none) {
      rule(100%)
      let label = if meta.authors.len() > 1 { "Authors' Contact Information:" } else { "Author's Contact Information:" }
      let groups = group-authors(meta.authors).map(contact-group).join("; ")
      block(spacing: lead)[#label #groups.]
    }

    // 3. Copyright / permission
    rule(100%)
    block(spacing: lead, {
      permission-text(meta.copyright)
      parbreak()
      set par(justify: false)
      copyright-line(meta.copyright, meta.copyright-year)
      linebreak()
      [ACM #j.issn/#str(meta.acm-year)/#str(meta.acm-month)-ART#str(meta.acm-article)]
      if meta.doi != none {
        linebreak()
        link("https://doi.org/" + meta.doi)[https:\/\/doi.org\/#meta.doi]
      }
    })
  }

  // float: true so the block reserves space at the bottom of the first page and
  // the body text flows above it (rather than overlapping).
  place(bottom, float: true, block(width: 100%, spacing: 0pt, stack))
}

#let make-title(cfg, meta) = {
  // --- Title (LARGE sans bold, left-aligned) ---
  block(spacing: 0pt)[
    // top-edge: cap-height places the (tall) first line's cap-top at the top
    // margin, matching LaTeX \topskip behaviour for a first line taller than it.
    #set text(font: cfg.fonts.sans, weight: "bold", size: cfg.size.LARGE, top-edge: "cap-height")
    #set par(justify: false, leading: cfg.bls.LARGE - cfg.size.LARGE)
    #meta.title
    #if meta.subtitle != none {
      parbreak()
      set text(font: cfg.fonts.sans, weight: "regular", size: cfg.font-size)
      meta.subtitle
    }
  ]

  v(cfg.bigskip + cfg.smallskip, weak: true) // title \bigskip then \medskip (less Typst box-edge overlap)

  // --- Authors (grouped by affiliation) ---
  let ni = collect-notes(meta.authors)
  let marked = meta.authors.enumerate().map(((i, a)) => {
    let a2 = a
    a2.insert("_marks", ni.marks.at(i))
    a2
  })
  block(spacing: 0pt)[
    #set par(justify: false, leading: cfg.bls.large - cfg.size.large, spacing: 0pt)
    #for g in group-authors(marked) {
      let names = g.authors.map(a => {
        upper(a.name)
        // note marks (superscript symbols); the ✉ glyph is large, so shrink it
        for m in a._marks {
          if m == "✉" { super(text(size: 0.72em)[#m]) } else { super(m) }
        }
      })
      block(spacing: cfg.bls.large - cfg.size.large)[
        #text(font: cfg.fonts.sans, size: cfg.size.large)[#{
          // join names with "and"/", and" while preserving content marks
          let n = names.len()
          if n == 1 { names.at(0) }
          else if n == 2 { names.at(0) + " and " + names.at(1) }
          else {
            for (i, nm) in names.enumerate() {
              nm
              if i < n - 2 { ", " } else if i == n - 2 { ", and " }
            }
          }
        }]#{
          let aff = affil-short(g.affiliation)
          if aff != none {
            text(font: cfg.fonts.serif, size: cfg.size.small)[, #aff]
          }
        }
      ]
    }
  ]

  v(cfg.medskip, weak: true) // authors \par\medskip

  // --- Abstract (9pt, no heading label, first line not indented) ---
  if meta.abstract != none {
    block(width: 100%, spacing: 0pt)[
      #set text(font: cfg.fonts.serif, size: cfg.size.small)
      #set par(justify: true, leading: cfg.bls.small - cfg.size.small,
        first-line-indent: (amount: cfg.parindent, all: false),
        spacing: cfg.bls.small - cfg.size.small)
      #meta.abstract
    ]
  }

  // --- CCS Concepts ---
  if meta.ccs != none {
    special-line(cfg, [CCS Concepts], render-ccs-concepts(meta.ccs))
  }

  // --- Keywords ---
  if meta.keywords != none {
    let kw = if type(meta.keywords) == array { meta.keywords.join(", ") } else { meta.keywords }
    special-line(cfg, [Keywords], kw)
  }

  // --- ACM Reference Format ---
  if meta.show-ref {
    let j = lookup-journal(meta.journal)
    v(cfg.medskip, weak: true)
    context {
      let total = counter(page).final().first()
      block(width: 100%, spacing: 0pt)[
        #set text(font: cfg.fonts.serif, size: cfg.size.small)
        #set par(justify: true, leading: cfg.bls.small - cfg.size.small,
          first-line-indent: 0pt, spacing: cfg.bls.small - cfg.size.small)
        #strong[ACM Reference Format:]\
        #andify(meta.authors.map(a => a.name)). #str(meta.acm-year). #meta.title#{
          if meta.subtitle != none [: #meta.subtitle]
        }. #if j.short != none { emph(j.short) + " " }#{
          let parts = ()
          if meta.acm-volume != none { parts.push(str(meta.acm-volume)) }
          if meta.acm-number != none { parts.push(str(meta.acm-number)) }
          parts.join(", ")
        }#if meta.acm-article != none [, Article #str(meta.acm-article)] (#pub-date(meta)), #total #if total == 1 [page] else [pages].#{
          if meta.doi != none [ #link("https://doi.org/" + meta.doi)[https:\/\/doi.org\/#meta.doi]]
        }
      ]
    }
  }

  v(cfg.bigskip, weak: true) // \@printendtopmatter \par\bigskip
}
