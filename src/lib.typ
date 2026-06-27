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
#import "parts/headings.typ": render-heading
#import "parts/frontmatter.typ": make-title

#let _formats = (
  acmsmall: acmsmall,
)

#let acmart(
  format: "acmsmall",
  title: none,
  subtitle: none,
  authors: (),
  abstract: none,
  ccs: none,
  keywords: none,
  // publication metadata
  journal: none,
  acm-volume: none,
  acm-number: none,
  acm-article: none,
  acm-year: none,
  acm-month: none,
  doi: none,
  copyright: "acmlicensed",
  copyright-year: none,
  ..rest,
  body,
) = {
  assert(
    format in _formats,
    message: "unknown/unimplemented acmart format: " + format,
  )
  let cfg = _formats.at(format)

  let meta = (
    title: title,
    subtitle: subtitle,
    authors: authors,
    abstract: abstract,
    ccs: ccs,
    keywords: keywords,
    journal: journal,
    acm-volume: acm-volume,
    acm-number: acm-number,
    acm-article: acm-article,
    acm-year: acm-year,
    acm-month: acm-month,
    doi: doi,
    copyright: copyright,
    copyright-year: copyright-year,
  )

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

  set heading(numbering: cfg.heading-numbering)
  show heading: it => render-heading(it, cfg)

  if meta.title != none {
    make-title(cfg, meta)
  }

  body
}
