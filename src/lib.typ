// typst-acmart — a Typst port of the LaTeX acmart class.
//
// Public entry point: apply with a show rule, e.g.
//   #import "@preview/acmart:0.0.1": acmart
//   #show: acmart.with(format: "acmsmall", title: [...], ...)
//
// Status: early. Only the `acmsmall` format is implemented, and only page
// geometry + body typography so far (Phase 1/2). Title block, theorems, floats,
// and bibliography styling come later.

#import "formats/acmsmall.typ": acmsmall

#let _formats = (
  acmsmall: acmsmall,
)

#let acmart(
  format: "acmsmall",
  ..rest,
  body,
) = {
  assert(
    format in _formats,
    message: "unknown/unimplemented acmart format: " + format,
  )
  let cfg = _formats.at(format)

  set page(
    width: cfg.paper.width,
    height: cfg.paper.height,
    margin: cfg.margin,
  )

  // Pin the line box to the font size (top-edge - bottom-edge = 1em) so that the
  // baseline-to-baseline distance is font-metric-independent and equals
  //   leading + 1em = (baselineskip - font-size) + font-size = baselineskip,
  // matching TeX's rigid \baselineskip. top-edge = 1em also puts the first
  // baseline at `top margin + \topskip`, as LaTeX does.
  set text(
    font: cfg.fonts.serif,
    size: cfg.font-size,
    top-edge: 1em,
    bottom-edge: 0pt,
    lang: "en",
  )

  set par(
    leading: cfg.baselineskip - cfg.font-size,
    first-line-indent: (amount: cfg.parindent, all: false),
    spacing: cfg.baselineskip - cfg.font-size, // inter-paragraph = one blank baselineskip step (parskip=0)
    justify: true,
  )

  body
}
