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
  // LaTeX font-size steps (TeX pt) — size and baselineskip
  size: (
    footnotesize: 8 * tp, small: 9 * tp, normalsize: 10 * tp,
    large: 10.95 * tp, Large: 12 * tp, LARGE: 14.4 * tp,
    huge: 17.28 * tp, Huge: 20.74 * tp,
  ),
  bls: (
    footnotesize: 10 * tp, small: 11 * tp, normalsize: 12 * tp,
    large: 13 * tp, Large: 14 * tp, LARGE: 17 * tp,
    huge: 20 * tp, Huge: 24 * tp,
  ),
  // standard LaTeX skips (size-independent)
  smallskip: 3 * tp, medskip: 6 * tp, bigskip: 12 * tp,
  footnote-rule-short: 4 * 12 * tp, // 4pc (regular footnote rule)
  footnote-rule-kern-above: 3 * tp, footnote-rule-kern-below: 2.6 * tp,
  parindent: 10 * tp,
  parskip: 0pt,
  runin-sep: 3.5 * tp, // |afterskip| for run-in headings (subsubsection/paragraph)
  heading-numbering: "1.1.1", // secnumdepth=3 (paragraphs unnumbered, handled in show rule)
  fonts: (
    serif: "Libertinus Serif",
    sans: "Libertinus Sans",
    mono: "Inconsolatazi4", // acmart uses zi4 (Inconsolata) for \texttt

    math: "Libertinus Math",
  ),
)
