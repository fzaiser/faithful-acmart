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
