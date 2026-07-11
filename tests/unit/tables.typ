// Structural tests for tabular's drop-in arguments and row-boundary inference.

#import "/src/parts/tables.typ": tabular, midrule, bottomrule, aboverulesep, belowrulesep

// `tabular` wraps its std.table in a non-breakable block (LaTeX tabulars never
// split across a page); the underlying table element is the block's body.
#let inner(t) = t.body

#let custom-inset = (x: 3pt, y: 2pt)
#let custom-stroke = 0.7pt
#let grid = tabular(
  columns: 2,
  inset: custom-inset,
  stroke: custom-stroke,
  table.cell(rowspan: 2)[A], [B],
  midrule(),
  [C],
  bottomrule(),
)

#let fields = inner(grid).fields()
#assert.eq(repr(fields.stroke), repr(custom-stroke))
#let inset = fields.inset

// The first rule is between rows 0 and 1; the bottom rule follows row 1 even
// though the first cell spans both rows. Caller padding is retained and the
// booktabs padding is added on the correct sides.
#assert.eq(inset(0, 0), (
  left: 3pt, right: 3pt, top: 2pt, bottom: 2pt + aboverulesep,
))
#assert.eq(inset(1, 1), (
  left: 3pt, right: 3pt,
  top: 2pt + belowrulesep, bottom: 2pt + aboverulesep,
))

// Per-cell inset functions and explicitly positioned cells use the same path.
#let positioned = tabular(
  columns: 2,
  inset: (x, y) => (left: x * 1pt, right: 0pt, top: y * 1pt, bottom: 0pt),
  table.cell(x: 1, y: 0)[A],
  [B],
  table.hline(y: 1),
)
#assert.eq(inner(positioned).fields().at("inset")(1, 1), (
  left: 1pt, right: 0pt, top: 1pt + belowrulesep, bottom: 0pt,
))
