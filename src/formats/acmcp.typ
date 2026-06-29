// acmcp format — ACM cover page (currently used by JDS), best-effort.
//
// Single-column, acmsmall-like geometry (6.75x10, probed), 9pt default. The title
// is narrowed by 6pc (acmart.dtx:6988) and sections are UNNUMBERED (secnumdepth
// -1, acmart.dtx:8501); the ACM reference format is off by default
// (\@ACM@printacmreffalse, acmart.dtx:3006). The bespoke cover infobox (JDS logo,
// colour frame, code/data links — acmart.dtx:6724) is NOT reproduced; this gives
// the cover-page typography and geometry, not the full ornamented cover.
#import "_base.typ": tp, size-ladder, make-format

#let acmcp(font-size: "9pt") = make-format(
  name: "acmcp",
  ladder: size-ladder(font-size, format: "acmcp"),
  default-font-size: "9pt",
  paper: (width: 6.75in, height: 10in),
  margin: (inside: 46 * tp, outside: 46 * tp, top: 85 * tp, bottom: 66.7 * tp),
  head-skip: 58 * tp,
  foot-skip: 24 * tp,
  secnumdepth: -1,         // no section numbers (acmart.dtx:8501)
  // journal single-column top matter + generic sf-bold sections (acmsmall-like).
)
