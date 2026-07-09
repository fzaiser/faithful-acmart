// urlbreak-test — the `url-break-on-hyphens: false` path (compile + golden, no twin).
//
// Not a matched twin: acmart's `url-break-on-hyphens` only changes *where* a long
// URL may wrap, and Typst and LaTeX choose different break points, so a
// page-by-page raster diff against LaTeX isn't meaningful. Instead we pin the
// Typst output with a golden hash to guard the feature: with the option false a
// long hyphenated URL must NOT break at its hyphens (it breaks only at `/`),
// because the hyphens are re-rendered as U+2011. The default (true) path is the
// native Typst behaviour exercised by every other test (e.g. the DOI links).
#import "/src/lib.typ": acmart

#show: acmart.with(
  format: "acmsmall",
  title: "Forbidding URL Breaks on Hyphens",
  doi: none,
  url-break-on-hyphens: false,
)

= Test
Padding text to push the link toward the right margin so that it is forced to wrap
onto the next line, in order to show that with `url-break-on-hyphens` disabled the
hyphenated URL wraps as a unit (only at the slash) rather than breaking after one of
its hyphens. See
#link("https://example.com/a-hyphenated-path-that-stays-on-one-line")
for the remainder of this sentence, and keep writing until the line is full enough.
