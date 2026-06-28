// Body elements for acmsmall: captions, lists, and figure spacing.
//
// acmsmall (journal) caption: sans-serif small (9pt), label and text same
// weight, period label separator; figure named "Fig.", table caption on top.
// The caption package's singlelinecheck centers captions that fit one line and
// left-justifies longer ones. Enumerate labels are parenthesized: (1), (2), ...

#import "spacing.typ": comp, tex-skip

#let apply-body(cfg, body) = {
  // Figure/table supplements and caption separator
  // Figure name is "Fig." in every language (acmart sets it globally, not via a
  // babel caption; acmart.dtx:4199). The table name follows the main language.
  show figure.where(kind: image): set figure(supplement: [Fig.])
  show figure.where(kind: table): set figure(supplement: cfg.strings.table)
  show figure.where(kind: table): set figure.caption(position: top)
  set figure.caption(separator: [. ])

  // Caption typography + singlelinecheck (center if one line, else left-justify)
  show figure.caption: it => context {
    set text(font: cfg.fonts.sans, size: cfg.size.small)
    set par(leading: comp(cfg, sz: "small"))
    layout(size => {
      let w = measure(it).width
      if w <= size.width {
        align(center, it)
      } else {
        set par(justify: true)
        align(left, it)
      }
    })
  }

  // Float spacing: \intextsep (12pt) around [h] floats, \abovecaptionskip (12pt)
  // between figure body and caption. (Floats sit on \lineskip, not \baselineskip,
  // so unlike text blocks they take no line-box compensation.)
  show figure: set block(above: cfg.intextsep, below: cfg.intextsep)
  set figure(gap: cfg.abovecaptionskip)

  // Tables: booktabs-like tight rows (Typst's default inset is too tall).
  set table(inset: (x: 0.6em, y: 0.28em), stroke: none)

  // amsart list labels (inherited by acmsmall; amsart.cls:870-884):
  //   enumerate: (1) / (a) / (i) / (A)   itemize: • / bold – / ∗ / ·
  // Geometry (acmart.dtx:4426): body at \leftmargin (≈24.5pt, level 1), label
  // hanging left with \labelsep=4pt, items one baselineskip apart (tight). Typst
  // has no fixed hanging-label box (\llap), so we land the body at \leftmargin via
  // `indent` + marker width + `body-indent`(=\labelsep): for the wide "(1)" the
  // marker hangs at ~\parindent; for the narrow bullet we widen `indent` so its
  // body still reaches \leftmargin (= leftmargin - labelsep - bullet width). See DESIGN.
  // Vertical spacing: amsart sets level-1 \topsep = \listisep = \smallskipamount
  // (acmart.dtx:4446-4451) with \itemsep = \parsep = 0, i.e. items sit one
  // \baselineskip apart (the global par leading) and the whole list is offset
  // from the surrounding text by a \smallskip. tex-skip() converts that topsep
  // to the block gap; tight items inherit the baseline-grid leading.
  let list-gap = tex-skip(cfg, cfg.smallskip)
  set enum(numbering: "(1)(a)(i)(A)", indent: cfg.parindent, body-indent: cfg.list-labelsep,
    spacing: list-gap)
  set list(marker: ([•], text(weight: "bold")[–], [∗], [·]),
    indent: cfg.list-leftmargin - 2 * cfg.list-labelsep, body-indent: cfg.list-labelsep,
    spacing: list-gap)

  // Monospace (Inconsolata/zi4) for inline and block code.
  show raw: set text(font: cfg.fonts.mono)

  // Bibliography: ACM CSL, footnotesize (8pt), "References" heading.
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
