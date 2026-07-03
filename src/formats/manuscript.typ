// manuscript format — single-column draft layout (acmart's default format).
//
// Letterpaper, generic geometry (acmart.dtx:3756 sets only head/marginpar, so the
// margins are geometry's letterpaper defaults), 9pt default (acmart.dtx:3066).
// Same single-column journal topmatter and generic section fonts as acmsmall.
// Geometry probed from the bundled class (`tools/test.py probe`); values in TeX points.
// acmart loads setspace and applies \onehalfspacing for every manuscript-format
// document, which is a 1.25 \baselinestretch over amsart's 9/11pt size table.
#import "_base.typ": tp, size-ladder, make-format, bottom-margin

#let manuscript(font-size: 9pt) = make-format(
  name: "manuscript",
  // setspace's \onehalfspacing factor depends on \@ptsize (1.25 default and
  // for 10pt, 1.213 at 11pt, 1.241 at 12pt) — confirmed by the probed
  // per-size \baselineskip (15/15.769/17.374 = 12·1.25/13·1.213/14·1.241).
  ladder: size-ladder(font-size, format: "manuscript",
    baseline-stretch: ("8": 1.25, "9": 1.25, "10": 1.25, "11": 1.213, "12": 1.241)
      .at(str(int(calc.round(font-size / 1pt))))),
  paper: (width: 8.5in, height: 11in),
  // Asymmetric (twoside): marginparwidth=6pc is reserved in the outer margin.
  margin: (
    inside: 73.71614 * tp,
    outside: 110.57424 * tp,
    top: 95.39738 * tp,    // 1in + topmargin(-3.87262) + 13 + 14 (head top 68.39738)
    // heightrounded \textheight per base size (probed — rounded at the
    // \onehalfspacing-STRETCHED baselineskip; 560 at the 9pt default)
    bottom: bottom-margin(font-size, 794.97, 95.39738, ("8": 560, "9": 560, "10": 550, "11": 561.91383, "12": 548.59283)),
  ),
  foot-skip: 12 * tp,      // \footskip = 12pt (no foot=2pc override)
)
