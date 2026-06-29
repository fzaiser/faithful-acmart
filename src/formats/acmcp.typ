// acmcp format — ACM cover page (currently used by JDS), best-effort.
//
// Single-column, acmsmall-like geometry (6.75x10, probed), 9pt default. The title
// is narrowed by 6pc (acmart.dtx:6988) and sections are UNNUMBERED (secnumdepth
// -1, acmart.dtx:8501); the ACM reference format is off by default
// (\@ACM@printacmreffalse, acmart.dtx:3006). The bespoke cover frame and the
// top-right infobox (JDS logo over code/data links, keywords, contributions —
// acmart.dtx:5899/6724) ARE reproduced (drawn in lib.typ); the only approximation
// is the infobox's vertical anchoring (top-right corner, not zref against the
// frame bottom). See DESIGN.md "Known limitations".
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
  title-width-reduction: 6 * 12 * tp, // narrow the title by 6pc to clear the infobox
  // journal single-column top matter + generic sf-bold sections (acmsmall-like).
)
