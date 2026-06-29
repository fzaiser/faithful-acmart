// sigchi-a format — landscape SIGCHI extended abstracts, best-effort.
//
// Landscape 11x8.5, single wide column with a large (314pt) left margin for
// marginal notes, sans-serif document default (acmart.dtx:4073), 10pt. The title
// is @mktitle@iv (a leading 2pt rule above a ragged title, acmart.dtx:7039) and
// sections are unnumbered (secnumdepth 0). Geometry probed from the class.
//
// Approximations (documented): footnotes are NOT moved into the margin
// (acmart.dtx:3533 \marginpar), the @iv 5pc title leftskip is omitted, and the
// "Legacy document" watermark is not drawn. The geometry, sans default, rule
// title and unnumbered sections are reproduced.
#import "_base.typ": tp, size-ladder, make-format

#let sigchia(font-size: "10pt") = make-format(
  name: "sigchi-a",
  ladder: size-ladder(font-size, format: "sigchi-a"),
  default-font-size: "10pt",
  paper: (width: 11in, height: 8.5in),
  twoside: false,
  // one-sided with a wide left margin (marginpar 170pt sits inside the 314pt
  // left margin via \reversemarginpar).
  margin: (left: 314 * tp, right: 72 * tp, top: 99 * tp, bottom: 84 * tp),
  head-skip: 58 * tp,
  foot-skip: 24 * tp,
  sans-default: true,
  urlstyle-sans: true,
  secnumdepth: 0,
  title-style: "sigchi-rule",
  author-style: "list",
  bibstrip: false,
  conf-footer: true,
  // \@titlefont \Huge\bfseries (serif bold) ; \@subtitlefont \mdseries
  title-font: (family: "serif", weight: "bold", size: "Huge"),
  subtitle-font: (family: "sans", weight: "regular", size: "normalsize"),
  // \@authorfont \bfseries ; \@affiliationfont \mdseries (sans, the default family)
  author-font: (family: "sans", weight: "bold", size: "normalsize"),
  affil-font: (family: "sans", weight: "regular", size: "normalsize"),
)
