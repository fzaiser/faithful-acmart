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

  // Enumerate labels: (1), (2), ... ; tight item spacing
  set enum(numbering: "(1)")

  body
}
