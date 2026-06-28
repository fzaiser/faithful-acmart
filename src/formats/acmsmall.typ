// acmsmall format — single-column journal layout.
//
// All measurements are taken from the real acmart.cls (format=acmsmall) via a
// layout probe (tools/probe.tex; run `make probe`). LaTeX reports lengths in TeX points
// (1pt = 1/72.27in); Typst's pt is a PostScript point (1/72in). `tp` converts a
// TeX-point count into Typst length so the geometry matches exactly.
#let tp = 72.0 / 72.27 * 1pt

// --- Font-size ladder (amsart's \@typesizes; amsart.cls) -------------------
//
// acmart selects a base size via the `8pt|9pt|10pt|11pt|12pt` option and passes
// it to amsart (`\LoadClass[\ACM@fontsize]{amsart}`). amsart's `\@typesizes`
// table is a clamped 11-entry window into a single master font ladder, with
// `normalsize` at the entry for the chosen base. The master ladder's (size,
// baselineskip) pairs, in TeX points (sizes are the \@viipt…\@xxvpt step
// macros: 10.95/14.4/17.28/20.74/24.88), 0-indexed:
#let _ladder-size = (5, 6, 7, 8, 9, 10, 10.95, 12, 14.4, 17.28, 20.74, 24.88)
#let _ladder-bls = (6, 7, 8, 10, 11, 12, 13, 14, 17, 20, 24, 30)
// Our 9 named steps are amsart \@typesizes indices 3..11, i.e. offsets -3..+5
// from `normalsize`. (Indices 1/2 — Tiny/tiny — are unused here.)
#let _step-offset = (
  scriptsize: -3, footnotesize: -2, small: -1, normalsize: 0,
  large: 1, Large: 2, LARGE: 3, huge: 4, Huge: 5,
)

// Build the acmsmall format dict for a given base font size (one of
// "8pt".."12pt"; acmsmall's own default is 10pt — acmart.dtx:3068). Geometry,
// margins, parindent, and the float/list/footnote/badge constants do NOT depend
// on the font size (acmart.dtx:3750, "the present margins do not depend on the
// font size option"); only the typography (font-size, baselineskip, the
// size/bls step tables, and the amsart \small/\med/\bigskip) scales.
#let acmsmall(font-size: "10pt") = {
  assert(
    font-size in ("8pt", "9pt", "10pt", "11pt", "12pt"),
    message: "acmart: option `font-size` must be one of 8pt/9pt/10pt/11pt/12pt "
      + "for the acmsmall format (got " + repr(font-size) + ").",
  )
  let base = int(font-size.slice(0, -2)) // "10pt" -> 10
  // 0-based index of `normalsize` in the master ladder (10pt -> index 5 = 10/12).
  let ni = base - 5
  // Map a named step to a (clamped) ladder entry.
  let pick(arr, step) = arr.at(calc.clamp(ni + _step-offset.at(step), 0, _ladder-size.len() - 1))
  let size = (:)
  let bls = (:)
  for step in _step-offset.keys() {
    size.insert(step, pick(_ladder-size, step) * tp)
    bls.insert(step, pick(_ladder-bls, step) * tp)
  }
  // amsart's \@adjustvertspacing derives the skips from the normalsize
  // baselineskip: \bigskip = .7\baselineskip, \medskip = \bigskip/2,
  // \smallskip = \medskip/2. At 10pt (bls 12) this is 8.4 / 4.2 / 2.1.
  let bigskip = 0.7 * bls.normalsize
  let medskip = bigskip / 2
  let smallskip = medskip / 2

  // Ground-truth geometry (in TeX points) from the probe — font-size-independent:
  //   paper 6.75in x 10in
  //   textwidth   = 395.8225  (= paper - 2*46)
  //   textheight  = 574.0
  //   inner/outer = 46
  //   top (to head)   = 58 ; head = 13 ; headsep = 14  -> body top = 85
  //   footskip    = 24
  //   parindent   = 10 ; parskip = 0
  (
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
    // typography (scales with the base font size)
    font-size: size.normalsize,
    baselineskip: bls.normalsize,
    size: size,
    bls: bls,
    // amsart skips (derived from the normalsize baselineskip via
    // \@adjustvertspacing; 0.7x the standard article values). At 10pt:
    // 2.1/4.2/8.4pt — NOT the article 3/6/12.
    smallskip: smallskip, medskip: medskip, bigskip: bigskip,
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
}
