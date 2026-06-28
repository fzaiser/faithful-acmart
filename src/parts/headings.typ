// Section heading styling for acmart.
//
// acmsmall uses amsart's \@startsection skips with acmart's fonts (the acmsmall
// per-format override is empty, so the generic acmart definitions apply):
//   section (1):       sffamily bfseries, mixed case, before .75bl, after .25bl
//   subsection (2):    sffamily bfseries, mixed case, before .75bl, after .25bl
//   subsubsection (3): sffamily itshape, run-in (negative afterskip), dot
//   paragraph (4):     itshape (serif),  run-in, indented \parindent, dot
// where bl = \baselineskip. Section number is followed by \quad (1em). secnumdepth
// is 3, so paragraphs (level 4) are unnumbered. The paragraph after a heading is
// not indented (Typst handles this via first-line-indent (all: false)). (acmart
// stopped uppercasing section titles in v2.08; the bundled class is v2.18.)

#import "spacing.typ": comp, tex-skip

#let heading-number(it) = {
  if it.numbering != none {
    numbering(it.numbering, ..counter(heading).at(it.location()))
  }
}

// Run-in heading: heading text flows inline, the following paragraph continues
// on the same line. Returning inline content from the show rule achieves this;
// a weak v() supplies the vertical space before without breaking the run-in.
#let run-in-heading(it, cfg, before: 0pt, indent: 0pt, font: none, style: "normal", num: none) = {
  v(before, weak: true)
  // Cancel the automatic first-line indent down to the desired `indent`.
  h(indent - cfg.parindent)
  set text(font: font, style: style, weight: "regular", size: cfg.font-size)
  if num != none [#num#h(1em)]
  [#it.body.]
  h(cfg.runin-sep) // horizontal gap to the body text (|afterskip|)
}

#let render-heading(it, cfg) = {
  let lvl = it.level
  let bls = cfg.baselineskip
  let num = heading-number(it)

  // \@startsection puts a heading a full \baselineskip + |beforeskip| below the
  // previous baseline, and the body a \baselineskip + afterskip below the
  // heading; tex-skip() converts those skips to Typst block gaps (the heading and
  // body lines are at the body size, so the default "normalsize" applies).
  if lvl <= 2 {
    // display heading: own line, sans bold, ragged right, mixed case as written.
    // section/subsection both: before .75bl, after .25bl.
    let title = it.body
    block(above: tex-skip(cfg, 0.75 * bls), below: tex-skip(cfg, 0.25 * bls), sticky: true)[
      #set text(font: cfg.fonts.sans, weight: "bold", size: cfg.font-size)
      #set par(justify: false, leading: comp(cfg))
      #if num != none [#num#h(1em)]
      #title
    ]
  } else if lvl == 3 {
    // subsubsection: before .5bl, run-in
    run-in-heading(it, cfg, before: tex-skip(cfg, 0.5 * bls), indent: 0pt,
      font: cfg.fonts.sans, style: "italic", num: num)
  } else {
    // paragraph: serif italic, indented, run-in, before .5bl
    run-in-heading(it, cfg, before: tex-skip(cfg, 0.5 * bls), indent: cfg.parindent,
      font: cfg.fonts.serif, style: "italic", num: none)
  }
}
