// Direct unit tests for pure top-matter helpers (src/parts/frontmatter.typ).
//
// These run WITHOUT the LaTeX/pdftotext harness: the file compiles, and a failing
// #assert (or a panic in an exercised helper) aborts the Typst compile. Run
//   tools/tc compile tests/unit/frontmatter.typ /dev/null
// or via the harness as the "unit" tier (tools/test.py unit / test.py check).

#import "/src/parts/frontmatter.typ": format-received, render-ccs-concepts

// format-received returns content, so we assert on its type: the point of these
// cases is that malformed/edge input is handled without panicking.
#let is-content(x) = type(x) == content

// Regression: a bare date wrapped in a 1-element array used to panic on item.at(1)
// (index out of bounds). It is now treated as a bare date (stage defaults in).
#assert(is-content(format-received((("2020",),))))
// The documented forms still work: (stage, date) pairs and bare-date strings.
#assert(is-content(format-received((("Received", "2020"), ("revised", "2021")))))
#assert(is-content(format-received(("2020", ("revised", "2021")))))
// A non-array value passes through verbatim.
#assert.eq(format-received("2020"), "2020")

// render-ccs-concepts must tolerate both a 2-tuple (significance, area) with no
// specific and a full 3-tuple, exercising the .at(2, default: none) path.
#assert(is-content(render-ccs-concepts((
  (500, "Information systems"),
  (300, "Information systems", "Data management systems"),
))))
