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
#import "punct.typ": add-punct

// Adjacency tracking for the LaTeX kernel's `\if@nobreak` and for the run-in's
// ambient first-line indent. `_in-heading` is true while a heading (its number +
// title/run-in body) renders; `_body-since-heading` records whether an ordinary
// body paragraph has appeared since the previous heading. Together they let a
// heading tell, at render time, whether it directly follows another heading with
// no intervening text. The `show par` rule in lib.typ flips `_body-since-heading`
// (guarded by `_in-heading` so a heading's own title/body doesn't count).
#let _in-heading = state("acm-in-heading", false)
#let _body-since-heading = state("acm-body-since-heading", false)

#let heading-number(it) = {
  if it.numbering != none {
    numbering(it.numbering, ..counter(heading).at(it.location()))
  }
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
#let run-in-heading(body, cfg, f, before: 0pt, indent: 0pt, ambient: true, num: none, dot: true, sep: none) = {
  v(before, weak: true)
  // Reach the desired `indent`. When an ambient first-line indent is present
  // (this run-in continues after a body paragraph, or the paragraph-start shim
  // emitted after ACM block environments — figures/tables/lists/theorems), cancel
  // that \parindent down to `indent`; a figure immediately followed by a run-in
  // heading thus does not gain a second indent. When it is ABSENT — right after a
  // display heading, where the following paragraph is not indented — emit the
  // absolute indent (LaTeX's run-in indent is the unconditional \@startsection #3).
  h(if ambient { indent - cfg.parindent } else { indent })
  set text(font: f.font, style: f.style, weight: f.weight, size: f.size)
  if num != none [#num#h(1em)]
  // \@adddotafter's \@addpunct: no added dot when the title already ends
  // in punctuation.
  if dot { add-punct(body) } else { body }
  // horizontal gap to the body text: the |afterskip| (3.5pt), or a plain
  // interword space for amsart's subparagraph (afterskip -\fontdimen2\font).
  if sep == auto [ ] else { h(cfg.runin-sep) }
}

#let render-heading(it, cfg) = context {
  let lvl = it.level
  let bls = cfg.baselineskip
  // secnumdepth (acmart.dtx:8419): levels beyond it are unnumbered (sigchi=1,
  // sigchi-a=0). Paragraphs (level 4) are always unnumbered regardless.
  let num = if lvl <= cfg.secnumdepth { heading-number(it) }

  // Adjacency: the previous heading is the immediately-preceding flow element iff
  // no ordinary body paragraph has appeared since it. `query(...).at(-2)` is the
  // previous heading (`.at(-1)` is this heading itself). `_body-since-heading` is
  // flipped by the `show par` rule (lib.typ) — reliable for body markup paragraphs
  // and the ACM block-env shims, though it misses the frontmatter abstract's
  // pre-built content, which is why the frontmatter-label headings are excluded
  // below by `it.outlined`.
  let prevh = query(selector(heading).before(here())).at(-2, default: none)
  let body-since = _body-since-heading.get()
  // \if@nobreak (LaTeX kernel): right after a DISPLAY heading (\@afterheading set
  // \@nobreak), \@startsection SKIPS the next heading's beforeskip \addvspace, so
  // only the display heading's afterskip separates the two. Run-in headings do not
  // set \@nobreak, so a heading after a run-in keeps its beforeskip. Restricted to
  // real OUTLINE sections both ways: the frontmatter labels (Abstract / CCS /
  // Keywords) are `heading(outlined: false)` and are NOT \@startsection body
  // sections, so they neither trigger nor absorb the \if@nobreak suppression.
  let suppress-before = it.outlined and prevh != none and prevh.outlined and prevh.level <= 2 and not body-since
  // The run-in's ambient first-line indent (\parindent) is absent exactly when the
  // run-in directly follows a display heading — i.e. when its beforeskip is
  // suppressed — and present in every other case (after a paragraph, list, figure,
  // theorem …). So it is the complement of `suppress-before`.
  let ambient = not suppress-before
  // Mark the heading span so its own title/body paragraphs don't count as body
  // text, and clear the flag so the NEXT heading sees only text that follows this
  // one. (`body-since` was read above, before this reset.)
  _in-heading.update(true)
  _body-since-heading.update(false)

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
    block(above: if suppress-before { 0pt } else { tex-skip(cfg, 0.75 * bls) },
      below: tex-skip(cfg, 0.25 * bls), sticky: true)[
      #set text(font: f.font, weight: f.weight, style: f.style, size: f.size)
      #set par(justify: false, leading: comp(cfg))
      // Number then acmart's \quad (1em) before the title (\@seccntformat), modelled
      // as a 1em-wide box holding a single space — a quad-width space, exactly \quad.
      // The space inside the box is load-bearing for the PDF tag tree, not visible: a
      // bare h(), or an EMPTY box, abutting the title text makes Typst tag the first
      // title word glyph-by-glyph and scrambles the Tier 1.9 reading-order gate,
      // whereas a box carrying real text (the space) keeps the title one whole-word
      // run. The space extracts as an ordinary space, so the text gates are unaffected.
      #if num != none [#num#box(width: 1em, sym.space)#title] else { title }
    ]
  } else if lvl == 3 {
    // subsubsection: before .5bl, run-in. Right after a display heading \if@nobreak
    // drops the run-in's own beforeskip, leaving only the display's afterskip
    // (.25bl); a display block's `below` spacing does not reach a following
    // paragraph, so the run-in carries that gap itself.
    run-in-heading(it.body, cfg, sec-font(cfg, "subsubsection"),
      before: tex-skip(cfg, if suppress-before { 0.25 * bls } else { 0.5 * bls }),
      indent: 0pt, ambient: ambient, num: num)
  } else if lvl == 4 {
    // paragraph: indented, run-in, before .5bl (.25bl right after a display
    // heading, see above), unnumbered (secnumdepth 3)
    run-in-heading(it.body, cfg, sec-font(cfg, "paragraph"),
      before: tex-skip(cfg, if suppress-before { 0.25 * bls } else { 0.5 * bls }),
      indent: cfg.parindent, ambient: ambient, num: none)
  } else {
    // subparagraph: amsart's own definition (deps/amsart.cls:1124) — beforeskip
    // \z@ (no extra vertical space beyond the paragraph break), run-in gap of
    // one interword space (-\fontdimen2), unstyled body font, no added dot,
    // no paragraph indent.
    run-in-heading(it.body, cfg,
      (font: cfg.fonts.body, weight: "regular", style: "normal", size: cfg.size.normalsize),
      before: tex-skip(cfg, 0pt), indent: 0pt, ambient: ambient, num: none, dot: false, sep: auto)
  }
  _in-heading.update(false)
}

// \noindentparagraph (acmart.dtx:8376): the level-4 `paragraph` run-in, but at
// zero indent (\z@ instead of \parindent) and WITHOUT \@adddotafter — no trailing
// dot. acmart uses it internally for the journal CCS/keywords labels; exposed as a
// standalone function because a Typst heading element cannot carry the no-indent /
// no-dot variant. Not a heading, so it doesn't participate in the \if@nobreak
// adjacency — it is used mid-body (after a paragraph), where the ambient indent is
// present and the h(0 - parindent) reaches the margin.
#let noindentparagraph(cfg, body) = run-in-heading(body, cfg, sec-font(cfg, "paragraph"),
  before: tex-skip(cfg, 0.5 * cfg.baselineskip), indent: 0pt, num: none, dot: false)
