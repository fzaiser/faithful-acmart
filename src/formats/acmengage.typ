// acmengage format — two-column ACM EngageCSEdu course materials.
//
// A sigconf variant: two columns, 9pt, centered conference title + author grid.
// Same author/section fonts as sigconf (\@authorfont \LARGE serif; \@secfont
// \bfseries\Large, acmart.dtx:7231/8450). Slightly taller bottom margin (probed).
// The engage copyright line uses the booktitle rather than a conference (handled
// by conf-info-line's booktitle branch). Geometry probed from the class.
#import "_base.typ": tp, size-ladder, make-format, generic-sec-fonts

#let acmengage(font-size: "10pt") = make-format(
  name: "acmengage",
  ladder: size-ladder(font-size, format: "acmengage"),
  default-font-size: "10pt",
  paper: (width: 8.5in, height: 11in),
  margin: (inside: 54 * tp, outside: 54 * tp, top: 84 * tp, bottom: 88.97 * tp),
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
  author-font: (family: "serif", weight: "regular", size: "LARGE"),
  affil-font: (family: "serif", weight: "regular", size: "large"),
  sec-fonts: generic-sec-fonts + (
    section:    (family: "serif", weight: "bold", style: "normal", size: "Large"),
    subsection: (family: "serif", weight: "bold", style: "normal", size: "Large"),
  ),
)
