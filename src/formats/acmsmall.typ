// acmsmall format — single-column journal layout.
//
// All measurements are taken from the real acmart.cls (format=acmsmall) via a
// layout probe (see reference/probe.tex). LaTeX reports lengths in TeX points
// (1pt = 1/72.27in); Typst's pt is a PostScript point (1/72in). `tp` converts a
// TeX-point count into Typst length so the geometry matches exactly.
#let tp = 72.0 / 72.27 * 1pt

// Ground-truth values (in TeX points) from the probe:
//   paper 6.75in x 10in
//   textwidth   = 395.8225  (= paper - 2*46)
//   textheight  = 574.0
//   inner/outer = 46
//   top (to head)   = 58 ; head = 13 ; headsep = 14  -> body top = 85
//   footskip    = 24
//   parindent   = 10 ; parskip = 0 ; baselineskip = 12 ; fontsize = 10
#let acmsmall = (
  name: "acmsmall",
  twoside: true,
  columns: 1,
  paper: (width: 6.75in, height: 10in),
  // body text box position/size, expressed via page margins
  margin: (
    inside: 46 * tp,
    outside: 46 * tp,
    top: 85 * tp,     // 58 (to head top) + 13 (head) + 14 (headsep)
    bottom: (722.7 - 85 - 574) * tp, // = 63.7tp; paperheight - bodytop - textheight
  ),
  head: (height: 13 * tp, sep: 14 * tp, skip: 58 * tp),
  foot: (skip: 24 * tp),
  // typography
  font-size: 10 * tp,
  baselineskip: 12 * tp,
  parindent: 10 * tp,
  parskip: 0pt,
  fonts: (
    serif: "Libertinus Serif",
    sans: "Libertinus Sans",
    mono: "Libertinus Mono",
    math: "Libertinus Math",
  ),
)
