// Section heading styling for acmart.
//
// acmsmall uses amsart's \@startsection skips with acmart's fonts (the acmsmall
// per-format override is empty, so the generic acmart definitions apply):
//   section (1):       sffamily bfseries, UPPERCASE, before .75bl, after .25bl
//   subsection (2):    sffamily bfseries,            before .75bl, after .25bl
//   subsubsection (3): sffamily itshape, run-in (negative afterskip), dot
//   paragraph (4):     itshape (serif),  run-in, indented \parindent, dot
// where bl = \baselineskip. Section number is followed by \quad (1em). secnumdepth
// is 3, so paragraphs (level 4) are unnumbered. The paragraph after a heading is
// not indented (Typst handles this via first-line-indent (all: false)).

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
  // heading. Typst's line box is 1em (= font-size), not \baselineskip, so each
  // block gap is short by (\baselineskip - font-size); add it back so the
  // baseline-to-baseline gaps equal LaTeX's exactly.
  let comp = bls - cfg.font-size

  if lvl <= 2 {
    // display heading: own line, sans bold, ragged right.
    // section: before .75bl, after .25bl. Numbered level-1 sections are
    // uppercased; unnumbered ones (References, abstract) keep their case.
    let title = if lvl == 1 and num != none { upper(it.body) } else { it.body }
    block(above: 0.75 * bls + comp, below: 0.25 * bls + comp, sticky: true)[
      #set text(font: cfg.fonts.sans, weight: "bold", size: cfg.font-size)
      #set par(justify: false, leading: bls - cfg.font-size)
      #if num != none [#num#h(1em)]
      #title
    ]
  } else if lvl == 3 {
    // subsubsection: before .5bl, run-in
    run-in-heading(it, cfg, before: 0.5 * bls + comp, indent: 0pt,
      font: cfg.fonts.sans, style: "italic", num: num)
  } else {
    // paragraph: serif italic, indented, run-in, before .5bl
    run-in-heading(it, cfg, before: 0.5 * bls + comp, indent: cfg.parindent,
      font: cfg.fonts.serif, style: "italic", num: none)
  }
}
