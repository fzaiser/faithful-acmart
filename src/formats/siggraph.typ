// siggraph format — two-column proceedings (SIGGRAPH and similar).
//
// A sigconf variant: same geometry, two columns, 9pt; the differences are the
// author/affiliation fonts (\normalsize, acmart.dtx:7219) and the section fonts
// (\sffamily\bfseries\Large, acmart.dtx:8433). Geometry probed from the class.
#import "_base.typ": tp, size-ladder, make-format, generic-sec-fonts

#let siggraph(font-size: "9pt") = make-format(
  name: "siggraph",
  ladder: size-ladder(font-size, format: "siggraph"),
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
  title-font: (family: "sans", weight: "bold", size: "Huge"),
  subtitle-font: (family: "sans", weight: "regular", size: "LARGE"),
  // \@authorfont/\@affiliationfont = \normalsize\normalfont (serif)
  author-font: (family: "serif", weight: "regular", size: "normalsize"),
  affil-font: (family: "serif", weight: "regular", size: "normalsize"),
  // \@secfont/\@subsecfont = \sffamily\bfseries\Large
  sec-fonts: generic-sec-fonts + (
    section:    (family: "sans", weight: "bold", style: "normal", size: "Large"),
    subsection: (family: "sans", weight: "bold", style: "normal", size: "Large"),
  ),
)
