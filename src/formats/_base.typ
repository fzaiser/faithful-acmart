// Shared machinery for the per-format builders in this directory.
//
// Every acmart format is `\LoadClass[<size>]{amsart}` (acmart.dtx:3090) with a
// per-format default size, then geometry/columns/fonts layered on top. The font
// ladder and the amsart skip derivation are therefore identical across formats;
// only the chosen base size and the geometry differ. This file holds the shared
// pieces so each `formats/<name>.typ` is just its measurements + format flags.

// LaTeX lengths are TeX points (1pt = 1/72.27in); Typst's pt is a PostScript
// point (1/72in). `tp` converts a TeX-point count into a Typst length so the
// geometry matches exactly. Paper sizes use `in` directly.
#let tp = 72.0 / 72.27 * 1pt

// --- Font-size ladder (amsart's \@typesizes; amsart.cls) -------------------
//
// amsart's `\@typesizes` table is a clamped 11-entry window into a single master
// font ladder, with `normalsize` at the entry for the chosen base. The master
// ladder's (size, baselineskip) pairs, in TeX points (sizes are the
// \@viipt…\@xxvpt step macros: 10.95/14.4/17.28/20.74/24.88), 0-indexed:
#let _ladder-size = (5, 6, 7, 8, 9, 10, 10.95, 12, 14.4, 17.28, 20.74, 24.88)
#let _ladder-bls = (6, 7, 8, 10, 11, 12, 13, 14, 17, 20, 24, 30)
// Our 9 named steps are amsart \@typesizes indices 3..11, i.e. offsets -3..+5
// from `normalsize`. (Indices 1/2 — Tiny/tiny — are unused here.)
#let _step-offset = (
  scriptsize: -3, footnotesize: -2, small: -1, normalsize: 0,
  large: 1, Large: 2, LARGE: 3, huge: 4, Huge: 5,
)

// Resolve the amsart size ladder for a base font size (one of "8pt".."12pt").
// Returns the `size`/`bls` step dicts, the resolved normalsize font-size and
// baselineskip, and the amsart \small/\med/\bigskip (0.7x the article values,
// via amsart's \@adjustvertspacing). `allowed` names the sizes a given format
// accepts (acmsmall takes the full 8..12 range).
#let size-ladder(font-size, allowed: ("8pt", "9pt", "10pt", "11pt", "12pt"), format: "") = {
  assert(
    font-size in allowed,
    message: "acmart: option `font-size` must be one of " + allowed.join("/")
      + (if format != "" { " for the " + format + " format" } else { "" })
      + " (got " + repr(font-size) + ").",
  )
  let base = int(font-size.slice(0, -2)) // "10pt" -> 10
  // 0-based index of `normalsize` in the master ladder (10pt -> index 5 = 10/12).
  let ni = base - 5
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
  (
    size: size,
    bls: bls,
    font-size: size.normalsize,
    baselineskip: bls.normalsize,
    bigskip: bigskip,
    medskip: bigskip / 2,
    smallskip: bigskip / 4,
  )
}
