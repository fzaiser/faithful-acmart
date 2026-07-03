// Section heading styling for acmart.
//
// acmsmall uses amsart's \@startsection skips with acmart's fonts (the acmsmall
// per-format override is empty, so the generic acmart definitions apply):
//   section (1):       sffamily bfseries, mixed case, before .75bl, after .25bl
//   subsection (2):    sffamily bfseries, mixed case, before .75bl, after .25bl
//   subsubsection (3): sffamily itshape, run-in (negative afterskip), dot
//   paragraph (4):     itshape (serif),  run-in, indented \parindent, dot
//   subparagraph (5):  inherited amsart run-in body font, no added dot
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

// Best-effort \@addpunct: true when the (plain-text tail of the) content
// already ends in punctuation, so the run-in heading dot is suppressed
// ("Results?" stays "Results?", not "Results?."). Only text tails are
// inspected; content ending in math/boxes keeps the dot, like TeX's
// \spacefactor heuristic usually would.
#let _ends-with-punct(c) = {
  if type(c) == str { return c.trim().match(regex("[.!?]$")) != none }
  if type(c) != content { return false }
  if c.has("text") { return _ends-with-punct(c.text) }
  if c.has("body") { return _ends-with-punct(c.body) }
  if c.has("children") and c.children.len() > 0 { return _ends-with-punct(c.children.last()) }
  false
}

// Resolve a per-level entry of cfg.sec-fonts (family role -> actual font, size
// step -> length). Each format supplies its own \@secfont/\@subsecfont/… via the
// format dict (acmart.dtx:8415); the level STRUCTURE (skips, run-in, indent) is
// format-independent (acmart.dtx:8356), so only the fonts come from data.
#let sec-font(cfg, level) = {
  let f = cfg.sec-fonts.at(level)
  (font: cfg.fonts.at(f.family), weight: f.weight, style: f.style, size: cfg.size.at(f.size))
}

// Run-in heading: heading text flows inline, the following paragraph continues
// on the same line. Returning inline content from the show rule achieves this;
// a weak v() supplies the vertical space before without breaking the run-in.
#let run-in-heading(it, cfg, f, before: 0pt, indent: 0pt, num: none, dot: true, sep: none) = {
  v(before, weak: true)
  // Cancel the automatic first-line indent down to the desired `indent`. This
  // also absorbs the paragraph-start shim emitted after ACM block environments
  // (figures/tables/lists), so a figure immediately followed by a run-in heading
  // does not gain a second indent.
  h(indent - cfg.parindent)
  set text(font: f.font, style: f.style, weight: f.weight, size: f.size)
  if num != none [#num#h(1em)]
  it.body
  // \@adddotafter's \@addpunct: no added dot when the title already ends
  // in punctuation.
  if dot and not _ends-with-punct(it.body) [.]
  // horizontal gap to the body text: the |afterskip| (3.5pt), or a plain
  // interword space for amsart's subparagraph (afterskip -\fontdimen2\font).
  if sep == auto [ ] else { h(cfg.runin-sep) }
}

#let render-heading(it, cfg) = {
  let lvl = it.level
  let bls = cfg.baselineskip
  // secnumdepth (acmart.dtx:8419): levels beyond it are unnumbered (sigchi=1,
  // sigchi-a=0). Paragraphs (level 4) are always unnumbered regardless.
  let num = if lvl <= cfg.secnumdepth { heading-number(it) }

  // \@startsection puts a heading a full \baselineskip + |beforeskip| below the
  // previous baseline, and the body a \baselineskip + afterskip below the
  // heading; tex-skip() converts those skips to Typst block gaps (the heading and
  // body lines are at the body size, so the default "normalsize" applies).
  if lvl <= 2 {
    // display heading: own line, ragged right, mixed case as written. Font per
    // format (acmsmall sf bold; sigconf serif Large bold; …). before .75bl, after .25bl.
    let f = sec-font(cfg, if lvl == 1 { "section" } else { "subsection" })
    let title = it.body
    // (Known approximation: LaTeX's \@hangfrom aligns a WRAPPED title's
    // continuation lines after "N\quad"; here they return to the margin. A
    // measured hanging indent breaks the tagged-PDF reading order the Tier 1.9
    // gate checks, so the rare two-line numbered title keeps the simple form.)
    block(above: tex-skip(cfg, 0.75 * bls), below: tex-skip(cfg, 0.25 * bls), sticky: true)[
      #set text(font: f.font, weight: f.weight, style: f.style, size: f.size)
      #set par(justify: false, leading: comp(cfg))
      #if num != none [#num#h(1em)]
      #title
    ]
  } else if lvl == 3 {
    // subsubsection: before .5bl, run-in
    run-in-heading(it, cfg, sec-font(cfg, "subsubsection"),
      before: tex-skip(cfg, 0.5 * bls), indent: 0pt, num: num)
  } else if lvl == 4 {
    // paragraph: indented, run-in, before .5bl, unnumbered (secnumdepth 3)
    run-in-heading(it, cfg, sec-font(cfg, "paragraph"),
      before: tex-skip(cfg, 0.5 * bls), indent: cfg.parindent, num: none)
  } else {
    // subparagraph: amsart's own definition (deps/amsart.cls:1124) — beforeskip
    // \z@ (no extra vertical space beyond the paragraph break), run-in gap of
    // one interword space (-\fontdimen2), unstyled body font, no added dot,
    // no paragraph indent.
    run-in-heading(it, cfg,
      (font: cfg.fonts.body, weight: "regular", style: "normal", size: cfg.size.normalsize),
      before: tex-skip(cfg, 0pt), indent: 0pt, num: none, dot: false, sep: auto)
  }
}
