// Direct unit tests for shared ACM bibliography helpers (src/parts/acmref-*.typ).
//
// These run WITHOUT the LaTeX/pdftotext harness: the file compiles, and a failing
// #assert.eq aborts the Typst compile. Run standalone
//   tools/tc compile tests/unit/acmref.typ /dev/null
// or via the harness as the "unit" tier (tools/test.py unit / test.py check).

#import "/src/parts/acmref-common.typ": year-value

// year-value: prefer `year`, else the leading 4 chars of an ISO `date`, else "[n.d.]".
#let e(..f) = (fields: f.named())
#assert.eq(year-value(e(year: "1999")), (c: "1999", p: false))
#assert.eq(year-value(e(date: "2020-05-01")), (c: "2020", p: false))
#assert.eq(year-value(e(date: "2020")), (c: "2020", p: false))
#assert.eq(year-value(e()), (c: "[n.d.]", p: false))
// Regression: a `date` shorter than four characters used to panic on .slice(0, 4)
// (index out of bounds); it must now fall back to "[n.d.]" like a missing date.
#assert.eq(year-value(e(date: "99")), (c: "[n.d.]", p: false))
#assert.eq(year-value(e(date: "")), (c: "[n.d.]", p: false))
