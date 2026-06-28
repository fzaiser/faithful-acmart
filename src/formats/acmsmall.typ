// acmsmall format — single-column journal layout.
//
// All measurements are taken from the real acmart.cls (format=acmsmall) via a
// layout probe (tools/probe.tex; run `make probe`). The shared font-size ladder
// and TeX->PS point conversion live in `_base.typ`.
#import "_base.typ": tp, size-ladder

// Build the acmsmall format dict for a given base font size (one of
// "8pt".."12pt"; acmsmall's own default is 10pt — acmart.dtx:3068). Geometry,
// margins, parindent, and the float/list/footnote/badge constants do NOT depend
// on the font size (acmart.dtx:3750, "the present margins do not depend on the
// font size option"); only the typography (font-size, baselineskip, the
// size/bls step tables, and the amsart \small/\med/\bigskip) scales.
#let acmsmall(font-size: "10pt") = {
  let l = size-ladder(font-size, format: "acmsmall")

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
    columnsep: 0pt,
    default-font-size: "10pt",
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
    font-size: l.font-size,
    baselineskip: l.baselineskip,
    size: l.size,
    bls: l.bls,
    // amsart skips (derived from the normalsize baselineskip via
    // \@adjustvertspacing; 0.7x the standard article values). At 10pt:
    // 2.1/4.2/8.4pt — NOT the article 3/6/12.
    smallskip: l.smallskip, medskip: l.medskip, bigskip: l.bigskip,
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
    secnumdepth: 3,
    // --- Format-specific layout flags (the acmart \ifcase\ACM@format@nr switch) ---
    // acmsmall is the generic single-column journal: left title, author list,
    // journal bibstrip footer, generic section fonts (acmart.dtx:8415).
    title-style: "journal-left",   // \@mktitle@i (acmart.dtx:6877)
    author-style: "list",          // \@mkauthors@i (acmart.dtx:7337)
    bibstrip: true,                // journal footer (\if@ACM@journal, acmart.dtx:2982)
    conf-footer: false,            // no first-column conference copyright block
    sans-default: false,
    flushbottom: false,            // doc-only marker (Typst can't flushbottom)
    urlstyle-sans: false,
    // Per-level section fonts (acmart.dtx:8415, generic definitions). family is a
    // role into `fonts`; size is a step name in `size`. The level structure
    // (skips/run-in/indent) is shared in headings.typ.
    sec-fonts: (
      section:       (family: "sans", weight: "bold", style: "normal", size: "normalsize"),
      subsection:    (family: "sans", weight: "bold", style: "normal", size: "normalsize"),
      subsubsection: (family: "sans", weight: "regular", style: "italic", size: "normalsize"),
      paragraph:     (family: "serif", weight: "regular", style: "italic", size: "normalsize"),
    ),
    fonts: (
      serif: "Libertinus Serif",
      sans: "Libertinus Sans",
      mono: "Inconsolatazi4", // acmart uses zi4 (Inconsolata) for \texttt
      math: "Libertinus Math",
    ),
  )
}
