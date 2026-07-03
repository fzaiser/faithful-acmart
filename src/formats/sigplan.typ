// sigplan format — two-column proceedings (SIGPLAN conferences).
//
// Two columns, 10pt default (acmart.dtx:3078), 1in/0.75in margins (probed; note
// includeheadfoot=false). Distinct from sigconf: the title is \Huge\bfseries with
// NO sans (serif bold, acmart.dtx:6926), the sections are serif bold
// (\bfseries\Large section, \bfseries subsection, \bfseries\itshape paragraph;
// acmart.dtx:8435), and URLs are set in sans (\urlstyle{sf}, acmart.dtx:3623).
#import "_base.typ": tp, size-ladder, make-format, bottom-margin, generic-sec-fonts

#let sigplan(font-size: 10pt) = make-format(
  name: "sigplan",
  kind: "proceedings",
  ladder: size-ladder(font-size, format: "sigplan"),
  paper: (width: 8.5in, height: 11in),
  margin: (inside: 54.2025 * tp, outside: 54.2025 * tp, top: 72.27 * tp,
    // heightrounded \textheight per base size (probed; 646 at the 10pt default)
    bottom: bottom-margin(font-size, 794.97, 72.27, ("8": 650, "9": 648, "10": 646, "11": 647, "12": 654))), // head top 45.27
  foot-skip: 12 * tp,
  columns: 2,
  columnsep: 24 * tp,
  // centered conf title + author grid, first-column copyright block (no journal
  // footer). acmart \flushbottom-justifies these pages; Typst can't (ragged-bottom).
  title-style: "conf-center",
  bibstrip: false,
  urlstyle-sans: true,
  // \@titlefont \Huge\bfseries (serif) ; \@subtitlefont \LARGE\mdseries (serif)
  title-font: (family: "serif", weight: "bold", size: "Huge"),
  subtitle-font: (family: "serif", weight: "regular", size: "LARGE"),
  // \@authorfont \Large\normalfont (serif) ; \@affiliationfont \normalsize (serif)
  author-font: (family: "serif", weight: "regular", size: "Large"),
  affil-font: (family: "serif", weight: "regular", size: "normalsize"),
  // \@secfont \bfseries\Large ; \@subsecfont \bfseries ; \@subsubsecfont \bfseries ;
  // \@parfont \bfseries\itshape (all serif) — acmart.dtx:8435-8440.
  sec-fonts: (
    section:       (family: "serif", weight: "bold", style: "normal", size: "Large"),
    subsection:    (family: "serif", weight: "bold", style: "normal", size: "normalsize"),
    subsubsection: (family: "serif", weight: "bold", style: "normal", size: "normalsize"),
    paragraph:     (family: "serif", weight: "bold", style: "italic", size: "normalsize"),
  ),
  // sigplan swaps both amsthm styles to bold heads at zero indent with
  // \normalfont notes (acmart.dtx:8566-8570/8639-8643), and the proof label to
  // italic \noindent (acmart.dtx:8740-8742).
  thm: (
    plain-head: "bold", def-head: "bold", indent: 0pt,
    note-inherits-head: false, proof-head: "italic", proof-indent: 0pt,
  ),
)
