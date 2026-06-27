// Body elements for acmsmall: captions, lists, and figure spacing.
//
// acmsmall (journal) caption: sans-serif small (9pt), label and text same
// weight, period label separator; figure named "Fig.", table caption on top.
// The caption package's singlelinecheck centers captions that fit one line and
// left-justifies longer ones. Enumerate labels are parenthesized: (1), (2), ...

#let apply-body(cfg, body) = {
  // Figure/table supplements and caption separator
  show figure.where(kind: image): set figure(supplement: [Fig.])
  show figure.where(kind: table): set figure(supplement: [Table])
  show figure.where(kind: table): set figure.caption(position: top)
  set figure.caption(separator: [. ])

  // Caption typography + singlelinecheck (center if one line, else left-justify)
  show figure.caption: it => context {
    set text(font: cfg.fonts.sans, size: cfg.size.small)
    set par(leading: cfg.bls.small - cfg.size.small)
    layout(size => {
      let rendered = box(width: size.width, it)
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
  // between figure body and caption.
  show figure: set block(above: cfg.bigskip, below: cfg.bigskip)
  set figure(gap: cfg.bigskip)

  // Tables: booktabs-like tight rows (Typst's default inset is too tall).
  set table(inset: (x: 0.6em, y: 0.28em), stroke: none)

  // Enumerate labels: (1), (2), ... ; tight item spacing
  set enum(numbering: "(1)")

  // Monospace (Inconsolata/zi4) for inline and block code.
  show raw: set text(font: cfg.fonts.mono)

  // Footnotes: footnotesize (8pt), short 4pc rule (\footnoterule).
  set footnote.entry(
    separator: line(length: cfg.footnote-rule-short, stroke: 0.4pt),
    gap: cfg.footnote-rule-kern-below,
    indent: 0pt,
  )
  show footnote.entry: set text(size: cfg.size.footnotesize)
  show footnote.entry: set par(leading: cfg.bls.footnotesize - cfg.size.footnotesize)

  body
}
