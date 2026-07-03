// Body elements: captions, lists, tables, code, display math, footnotes.
//
// acmsmall (journal) caption: sans-serif small (9pt), label and text same
// weight, period label separator; figure named "Fig.", table caption on top.
// The caption package's singlelinecheck centers captions that fit one line and
// left-justifies longer ones. Enumerate labels are parenthesized: (1), (2), ...

#import "spacing.typ": comp, tex-skip
#import "../formats/_base.typ": tp
#import "theorems.typ": cfg-state

// True while the title head renders a teaser figure: the figure show rule
// below must not add its \intextsep float spacing or the paragraph-indent shim
// there — \@mkteasers places the figure with its own \bigskip/\medskip skips
// (set by parts/frontmatter.typ's teaser-figure).
#let in-topmatter = state("acm-in-topmatter", false)

// The rules below need measure() for the amsart list-label geometry, so the
// whole body scope is one context block. `amsart-lists` selects the list
// geometry model (see the list section): true under review/nonacm, where an
// acmart hook-ordering bug lets amsart's begin-document values win.
#let apply-body(cfg, body, amsart-lists: false) = context {
  // Figure/table supplements and caption separator. Journals use "Fig.";
  // proceedings keep caption's default "Figure" name. The table name follows the
  // main language, as in acmart's babel caption hooks.
  show figure.where(kind: image): set figure(supplement: if cfg.bibstrip { [Fig.] } else { [Figure] })
  show figure.where(kind: table): set figure(supplement: cfg.strings.table)
  show figure.where(kind: table): set figure.caption(position: top)
  // In LaTeX, figure/table environments are floats unless the source opts into a
  // non-floating placement. Typst's figure() is in-flow by default, so give ACM
  // body figures a floating default and let special wrappers opt out explicitly.
  set figure(placement: auto)
  set figure.caption(separator: if cfg.bibstrip or cfg.name == "sigplan" { [. ] } else { [: ] })

  // Caption typography + singlelinecheck (center if one line, else left-justify).
  // The label ("Figure 1.") and text can carry different weights (sigplan:
  // labelfont={bf}, textfont={normalfont}, acmart.dtx:4211-4213), so the caption
  // is assembled from its fields rather than rendered wholesale.
  show figure.caption: it => context {
    let cap-font = if cfg.bibstrip { cfg.fonts.sans } else { cfg.fonts.body }
    let cap-weight = if cfg.bibstrip or cfg.name == "sigplan" { "regular" } else { "bold" }
    // sigchi-a captions are {bf, small} (acmart.dtx:4220-4223), one size step
    // below the other proceedings formats' bold normalsize.
    let cap-step = if cfg.bibstrip or cfg.name == "sigchi-a" { "small" } else { "normalsize" }
    let label-weight = if cfg.name == "sigplan" { "bold" } else { cap-weight }
    set text(font: cap-font, weight: cap-weight, size: cfg.size.at(cap-step))
    set par(leading: comp(cfg, sz: cap-step))
    let cap = {
      if it.numbering != none {
        text(weight: label-weight)[#it.supplement #it.counter.display(it.numbering)#it.separator]
      }
      it.body
    }
    layout(size => {
      let w = measure(cap).width
      if w <= size.width {
        align(center, cap)
      } else {
        set par(justify: true)
        align(left, cap)
      }
    })
  }

  // Float spacing: \intextsep (12pt) around [h] floats, \abovecaptionskip (12pt)
  // between figure body and caption. (Floats sit on \lineskip, not \baselineskip,
  // so unlike text blocks they take no line-box compensation.)
  let env-block(it, above: 0pt, below: 0pt) = {
    block(above: above, below: 0pt, it)
    // LaTeX environments such as list/quote end with normal paragraph
    // indentation enabled. The h() shim forms an invisible zero-height
    // paragraph after the block, which makes the NEXT paragraph take the
    // native first-line-indent ("follows a paragraph"). The shim also owns
    // the whole below-gap as its par `spacing`: measured, a block's `below`
    // and the follower's own above-spacing ADD across the shim (so a nonzero
    // `below` here double-counts), while the shim's spacing collapses by max
    // against whatever follows — exactly LaTeX's \addvspace semantics for
    // consecutive \topsep-carrying environments.
    // If the next item is a heading, this does not visibly indent it: display
    // headings are blocks, and run-in headings cancel/adjust the ambient indent
    // in parts/headings.typ.
    {
      set par(spacing: below)
      h(cfg.parindent)
    }
  }
  show figure: it => context {
    if in-topmatter.get() {
      // teaser figures carry \@mkteasers' own skips (frontmatter.typ)
      it
    } else {
      set block(above: cfg.intextsep, below: cfg.intextsep)
      it
      h(cfg.parindent)
    }
  }
  set figure(gap: cfg.abovecaptionskip)

  // Tables: booktabs-like tight rows. booktabs.sty v1.61803398 sets
  // \lightrulewidth=.05em and \heavyrulewidth=.08em; the default hline is the
  // light rule, with top/bottom rules opt-in at the table source.
  set table(
    inset: (left: 0.6em, right: 0.6em, top: 0.11em, bottom: 0.36em),
    stroke: none,
  )
  set table.hline(stroke: 0.05em)

  // Display equations in acmart/amsart are numbered by default and carry
  // generous \abovedisplayskip/\belowdisplayskip. Typst's native display math is
  // visually too tight, so wrap only block equations in TeX-like vertical space.
  set math.equation(numbering: "(1)")
  show math.equation.where(block: true): set block(
    above: tex-skip(cfg, cfg.medskip),
    below: tex-skip(cfg, cfg.medskip),
  )

  // --- List geometry (PROBED from the live class; OPTION-DEPENDENT!) --------
  //
  // acmart registers its list dimensions in an \AtBeginDocument block
  // (acmart.dtx:4425): \labelsep 4pt, \leftmargini = \parindent + 2\labelsep +
  // 6.5pt (24.5pt), \leftmarginii..vi = 8.5pt. amsart registers its own block
  // (deps/amsart.cls:942): \labelsep 5pt and \settowidth-derived margins —
  // \leftmargini = width of the level's enum label at counter 13 + \labelsep
  // (+ \normalparindent at level 1), \leftmarginv/vi = 10pt.
  //
  // WHICH block wins depends on the CLASS OPTIONS (an upstream acmart bug):
  // `review` and `nonacm` run \AtBeginDocument inside their \DeclareOption
  // code, BEFORE \LoadClass{amsart} — the LaTeX kernel merges each class's
  // hook code into one labeled chunk ordered by first registration, so the
  // whole acmart chunk (list block included) then executes before amsart's
  // and amsart's \settowidth values overwrite it. Probed: plain/screen
  // acmsmall gives labelsep 4pt / leftmargini 24.5pt; review or nonacm gives
  // 5pt / 30.26pt (verified with \ShowHook{begindocument}: execution order
  // "acmart, amsart, ..." under nonacm, the reverse without). The port
  // replicates the class bug-for-bug via `amsart-lists`.
  //
  // Labels are \llap'd in both models: right-aligned ending \labelsep before
  // the body, overhanging leftward when wide. Typst's enum/list reserve the
  // widest marker instead, so every marker is drawn as a zero-width box with
  // the label overhanging left, and the body pinned at indent + body-indent =
  // the level's \leftmargin.
  //
  // Vertical spacing (same in both models): level-1 \topsep = \listisep =
  // \smallskipamount with \itemsep = \parsep = 0 (items sit one \baselineskip
  // apart); level-2+ \topsep = 0, so nested lists add NO gap and only the
  // outermost list carries the \listisep block gap + the post-environment
  // paragraph indent.
  let enum-pats = if cfg.name == "sigplan" { ("1.", "a.", "i.", "A.") } else { ("(1)", "(a)", "(i)", "(A)") }
  let list-marks = ([$bullet$], text(weight: "bold")[–], [∗], [·])
  let llap(c) = context { h(-measure(c).width); c }
  let labelsep = if amsart-lists { 5 * tp } else { 4 * tp }
  // \leftmargin per (1-based) level; the amsart model measures like \settowidth
  // at counter 13.
  let label-w(k) = measure(numbering(enum-pats.at(k), 13)).width
  let leftmargin = if amsart-lists {
    (
      label-w(0) + labelsep + cfg.parindent,
      label-w(1) + labelsep,
      label-w(2) + labelsep,
      label-w(3) + labelsep,
      10 * tp, 10 * tp,
    )
  } else {
    let nested = 0.5 * labelsep + 6.5 * tp // \leftmarginii..vi = 8.5pt
    (cfg.parindent + 2 * labelsep + 6.5 * tp, nested, nested, nested, nested, nested)
  }
  let list-depth = counter("acm-list-depth")
  let list-gap = tex-skip(cfg, cfg.smallskip)
  let list-block(it) = {
    list-depth.update(n => n + 1)
    context {
      let d = list-depth.get().first()
      let inner = {
        // Children of THIS list are at depth d+1: their level's leftmargin and
        // llap'd label, pattern/symbol picked by depth (clamped like LaTeX,
        // whose \@itemdepth/\@enumdepth error out past 4 — we saturate).
        let li = calc.min(d, leftmargin.len() - 1)
        let pi = calc.min(d, 3)
        set enum(indent: leftmargin.at(li) - labelsep,
          numbering: (..ns) => llap(numbering(enum-pats.at(pi), ..ns)))
        set list(indent: leftmargin.at(li) - labelsep, marker: llap(list-marks.at(pi)))
        it
      }
      if d == 1 { env-block(inner, above: list-gap, below: list-gap) } else { inner }
    }
    list-depth.update(n => n - 1)
  }
  show enum: it => list-block(it)
  show list: it => list-block(it)
  // amsart labels are (1)/(a)/(i)/(A); sigplan redefines them to 1./a./i./A.
  // (acmart.dtx:4402-4406).
  set enum(numbering: (..ns) => llap(numbering(enum-pats.at(0), ..ns)),
    indent: leftmargin.at(0) - labelsep, body-indent: labelsep,
    spacing: comp(cfg))
  set list(marker: llap(list-marks.at(0)),
    indent: leftmargin.at(0) - labelsep, body-indent: labelsep,
    spacing: comp(cfg))

  // quote (amsart, deps/amsart.cls:900-905): a label-less list — leftmargin =
  // \leftmargini, rightmargin = leftmargin, \topsep = \listisep, no paragraph
  // indent. (Typst's quote maps to LaTeX's `quote`; the 3pc-margin `quotation`
  // variant with indented paragraphs is not modelled.)
  show quote.where(block: true): it => env-block(
    above: list-gap, below: list-gap,
    block(width: 100%, inset: (left: leftmargin.at(0), right: leftmargin.at(0)), {
      set par(first-line-indent: 0pt)
      it.body
      if it.attribution != none { linebreak(); align(end, [— #it.attribution]) }
    }),
  )

  // Monospace (Inconsolata/zi4) for inline and block code. Typst's raw default
  // is smaller than LaTeX \texttt/verbatim; force it back to the surrounding
  // font size, and give display code the same smallskip-style breathing room as
  // LaTeX's verbatim/trivlist.
  show raw: it => {
    set text(font: cfg.fonts.mono, size: 1.25em)
    if it.block {
      block(above: tex-skip(cfg, cfg.smallskip), below: tex-skip(cfg, cfg.smallskip))[
        #set par(justify: false, first-line-indent: 0pt, leading: comp(cfg), spacing: 0pt)
        #it.lines.map(l => l.body).join(linebreak())
      ]
    } else {
      it.lines.first().body
    }
  }

  // Bibliography (fires only on the "typst" backend): Typst's built-in ACM CSL,
  // footnotesize (8pt), "References". The faithful default is the "bibtex" backend (the
  // ACM-Reference-Format.bst port); "typst" is the CSL approximation.
  set bibliography(style: "association-for-computing-machinery", title: [References])
  show bibliography: set text(size: cfg.size.footnotesize)
  show bibliography: set par(leading: comp(cfg, sz: "footnotesize"))

  // Footnotes: footnotesize (8pt), short 4pc rule (\footnoterule).
  set footnote.entry(
    separator: line(length: cfg.footnote-rule-short, stroke: 0.4pt),
    // \skip\footins (7pt) of glue, then \footnoterule's \kern-3pt pulls the rule
    // up, so the body-to-rule gap is ~4pt; \kern2.6pt below the rule = gap.
    clearance: cfg.footins-skip - cfg.footnote-rule-kern-above,
    gap: cfg.footnote-rule-kern-below,
    indent: 0pt,
  )
  show footnote.entry: set text(size: cfg.size.footnotesize)
  show footnote.entry: set par(leading: comp(cfg, sz: "footnotesize"))

  body
}

// --- sigchi-a margin notes (acmart.dtx:4266-4341) --------------------------
//
// sidebar / marginfigure / margintable set their body in a \marginpar: a
// \small box of \marginparwidth in the wide left margin (\reversemarginpar
// puts it there), \marginparsep left of the text edge, top-aligned with the
// invocation point. marginfigure/margintable centre their content; captions
// come from the user's own figure() (kind: image/table, or kind: "sidebar"
// with supplement [Sidebar] for a captioned sidebar). The in-topmatter flag
// suppresses the body float spacing + indent shim inside the note, like the
// teaser path.
#let _marginpar(body, centering: false) = context {
  let cfg = cfg-state.get()
  let mp = cfg.marginpar
  assert(mp != none, message: "faithful-acmart: sidebar/marginfigure/margintable need a margin-note column (format: \"sigchi-a\")")
  // horizontal alignment only: the note's TOP stays at the invocation point in
  // the flow (a `top` alignment would pin it to the container top instead).
  // dy is MATCHED TO OUTPUT: \marginpar aligns the note's first baseline with
  // the line it attaches to; measured on sigchi-a-test p2 the Typst place
  // anchor sits 14.65tp below LaTeX's note baseline (281.3bp in both after
  // this shift).
  place(left, dx: -(mp.width + mp.sep), dy: -14.65 * tp, box(width: mp.width, {
    set text(size: cfg.size.small)
    set par(leading: comp(cfg, sz: "small"), spacing: comp(cfg, sz: "small"), justify: false, first-line-indent: 0pt)
    // Re-render figures bare — body + \abovecaptionskip + caption (table
    // captions on top) — replacing the figure element entirely so the global
    // float show rule (\intextsep + indent shim) never fires inside the note.
    show figure: it => block(width: 100%, spacing: 0pt, {
      if it.kind == table and it.caption != none { it.caption; v(cfg.abovecaptionskip) }
      it.body
      if it.kind != table and it.caption != none { v(cfg.abovecaptionskip); it.caption }
    })
    if centering { align(center, body) } else { body }
  }))
}

#let sidebar(body) = _marginpar(body)
#let marginfigure(body) = _marginpar(body, centering: true)
#let margintable(body) = _marginpar(body, centering: true)

// \fulltextwidth (acmart.dtx:4337): sigchi-a's figure*/table* span the text
// PLUS the margin column (textwidth + marginparsep + marginparwidth),
// extending leftward. Wrap a figure to give it that width. (LaTeX's figure*
// additionally floats to the page top; place the wrapper where the figure
// should sit.)
#let fulltextwidth(body) = context {
  let cfg = cfg-state.get()
  let mp = cfg.marginpar
  assert(mp != none, message: "faithful-acmart: fulltextwidth needs a margin-note column (format: \"sigchi-a\")")
  let off = mp.width + mp.sep
  in-topmatter.update(true)
  pad(left: -off, block(width: 100% + off, {
    set figure(placement: none)
    body
  }))
  in-topmatter.update(false)
}
