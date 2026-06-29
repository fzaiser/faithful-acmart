// sigchi format — two-column proceedings (legacy SIGCHI; now usually sigconf).
//
// A sigconf variant: same geometry/columns/9pt, but secnumdepth is 1 (only
// top-level sections are numbered, acmart.dtx:8442), the author name is bold
// (\bfseries, acmart.dtx:7225), and the section fonts are the generic
// \sffamily\bfseries (no size bump, acmart.dtx:8443). Geometry probed.
#import "_base.typ": tp, size-ladder, make-format

#let sigchi(font-size: "9pt") = make-format(
  name: "sigchi",
  ladder: size-ladder(font-size, format: "sigchi"),
  default-font-size: "9pt",
  paper: (width: 8.5in, height: 11in),
  margin: (inside: 54 * tp, outside: 54 * tp, top: 84 * tp, bottom: 84.97 * tp),
  head-skip: 57 * tp,
  foot-skip: 12 * tp,
  columns: 2,
  columnsep: 24 * tp,
  title-style: "conf-center",
  author-style: "grid",
  bibstrip: false,
  conf-footer: true,
  flushbottom: true,
  secnumdepth: 1,
  title-font: (family: "sans", weight: "bold", size: "Huge"),
  subtitle-font: (family: "sans", weight: "regular", size: "LARGE"),
  // \@authorfont = \bfseries (serif bold) ; \@affiliationfont = \mdseries (serif)
  author-font: (family: "serif", weight: "bold", size: "normalsize"),
  affil-font: (family: "serif", weight: "regular", size: "normalsize"),
  // \@secfont/\@subsecfont = generic \sffamily\bfseries (default make-format fonts)
)
