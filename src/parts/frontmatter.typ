// Title block / frontmatter for acmsmall (journal layout).
//
// Mirrors acmart's \maketitle for the journal formats: title (LARGE sans bold,
// left aligned), author lines (large sans uppercase names + small serif
// affiliation, grouped by shared affiliation), then abstract / CCS / keywords /
// ACM reference format. See the acmsmall-frontmatter-specs memory for sources.

#let fnsymbols = ("*", "†", "‡", "§", "¶", "‖", "**", "††", "‡‡")

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
  block(spacing: 0pt)[
    #set par(justify: false, leading: cfg.bls.large - cfg.size.large, spacing: 0pt)
    #for g in group-authors(meta.authors) {
      let names = g.authors.map(a => {
        upper(a.name)
        // note marks (superscript symbols)
        for m in a.at("marks", default: ()) {
          super(m)
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
}
