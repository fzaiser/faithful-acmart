// acmsmall format — single-column journal layout.
//
// All measurements are taken from the real acmart.cls (format=acmsmall) via a
// layout probe (tools/probe.tex; run `make probe`). LaTeX reports lengths in TeX points
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
    scriptsize: 7 * tp,
    footnotesize: 8 * tp, small: 9 * tp, normalsize: 10 * tp,
    large: 10.95 * tp, Large: 12 * tp, LARGE: 14.4 * tp,
    huge: 17.28 * tp, Huge: 20.74 * tp,
  ),
  bls: (
    scriptsize: 8 * tp,
    footnotesize: 10 * tp, small: 11 * tp, normalsize: 12 * tp,
    large: 13 * tp, Large: 14 * tp, LARGE: 17 * tp,
    huge: 20 * tp, Huge: 24 * tp,
  ),
  // amsart skips (size-independent). NB: amsart redefines these to 0.7x the
  // standard article values (3/6/12pt), so they are 2.1/4.2/8.4pt — NOT 3/6/12.
  // Probed from the compiled class (\smallskipamount etc.); see tools/probe.tex.
  smallskip: 2.1 * tp, medskip: 4.2 * tp, bigskip: 8.4 * tp,
  // float spacing (independent of the \bigskip value above, which they used to
  // coincide with): \intextsep around in-text floats, \abovecaptionskip between
  // a figure body and its caption. Both 12pt for acmsmall.
  intextsep: 12 * tp, abovecaptionskip: 12 * tp,
  footnote-rule-short: 4 * 12 * tp, // 4pc (regular footnote rule)
  footnote-rule-kern-above: 3 * tp, footnote-rule-kern-below: 2.6 * tp,
  footins-skip: 7 * tp, // \skip\footins — body-to-footnote-rule glue
  parindent: 10 * tp,
  parskip: 0pt,
  // List geometry (acmart.dtx:4426). Labels hang left via \llap so labelwidth is
  // ~irrelevant; what matters is the body position (\leftmargin) and \labelsep.
  //   leftmargini  = parindent + 2*labelsep + labelwidth = 10 + 8 + 6.5 = 24.5pt
  //   leftmarginii = 0.5*labelsep + labelwidth           =      2 + 6.5 =  8.5pt
  // Top-of-list skip = \listisep = \smallskip. (Typst can't right-align the
  // hanging label in a fixed box, so the body indent is approximate; see DESIGN.)
  list-labelsep: 4 * tp,
  list-leftmargin: 24.5 * tp,
  list-leftmargin-ii: 8.5 * tp,
  runin-sep: 3.5 * tp, // |afterskip| for run-in headings (subsubsection/paragraph)
  // Artifact-evaluation badges in the first-page header (acmart.dtx:5581/5603):
  // each badge image is 3pc wide, consecutive badges separated by 1pt.
  badge-width: 3 * 12 * tp, badge-skip: 1 * tp,
  heading-numbering: "1.1.1", // secnumdepth=3 (paragraphs unnumbered, handled in show rule)
  fonts: (
    serif: "Libertinus Serif",
    sans: "Libertinus Sans",
    mono: "Inconsolatazi4", // acmart uses zi4 (Inconsolata) for \texttt

    math: "Libertinus Math",
  ),
)
