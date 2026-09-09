#import "/src/parts/tables.typ": tabular, toprule, midrule, bottomrule, aboverulesep, belowrulesep, table-inset

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

#assert.eq(inset(0, 0), (
  left: 3pt, right: 3pt, top: 2pt, bottom: 2pt + aboverulesep,
))
#assert.eq(inset(1, 1), (
  left: 3pt, right: 3pt,
  top: 2pt + belowrulesep, bottom: 2pt + aboverulesep,
))

#let rested = tabular(columns: 2, inset: (top: 1pt, x: 3pt, rest: 6pt), [A], [B])
#assert.eq(inner(rested).fields().at("inset")(0, 0), (
  left: 3pt, right: 3pt, top: 1pt, bottom: 6pt,
))
#let rest-only = tabular(columns: 2, header-rows: 0, inset: (rest: 6pt), [A], [B])
#assert.eq(inner(rest-only).fields().at("inset")(0, 0), (
  left: 6pt, right: 6pt, top: 6pt, bottom: 6pt,
))

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

#let kids(t) = inner(t).children
#let headers(t) = kids(t).filter(c => c.func() == table.header)
#let headed = tabular(
  columns: 2,
  toprule(),
  [H1], [H2],
  midrule(),
  [a], [b],
  bottomrule(),
)
#assert.eq(kids(headed).at(0).func(), table.hline)
#let head = kids(headed).at(1)
#assert.eq(head.func(), table.header)
#assert.eq(head.at("repeat"), false)
#assert.eq(head.children.len(), 3)
#assert.eq(head.children.at(2).func(), table.hline)
#assert.eq(kids(headed).len(), 5)

// PDF header tagging must leave the rendered table size unchanged.
#let same-size(a, b) = context assert.eq(
  (measure(a).width, measure(a).height),
  (measure(b).width, measure(b).height),
)
#same-size(headed, tabular(
  columns: 2,
  header-rows: 0,
  toprule(), [H1], [H2], midrule(), [a], [b], bottomrule(),
))

#assert.eq(headers(tabular(columns: 2, header-rows: 0, [a], [b])).len(), 0)

// Skip automatic headers when wrapping could move cells.

#let spanning = tabular(
  columns: 2,
  table.cell(rowspan: 2)[A], [B],
  midrule(),
  [C],
  bottomrule(),
)
#assert.eq(headers(spanning).len(), 0)
#same-size(spanning, tabular(
  columns: 2,
  header-rows: 0,
  table.cell(rowspan: 2)[A], [B], midrule(), [C], bottomrule(),
))

// Inherited column counts require context, which would hide the table from figure kind detection.
#assert.eq(headers(tabular([H1], [H2], [A], [B])).len(), 0)

#assert.eq(headers(tabular(
  columns: 2,
  [H1], table.cell(x: 0, y: 1)[A],
  table.cell(x: 1, y: 0)[H2], [B],
)).len(), 0)

#assert.eq(headers(tabular(columns: 2, table.footer([A], [B]))).len(), 0)

#assert.eq(headers(tabular(columns: 2, table.header([H1], [H2]), [a], [b])).len(), 1)

// Rule placement must count the cells inside an explicit header.
#let own-header = tabular(
  columns: 2,
  toprule(), table.header(repeat: false, [H1], [H2]), midrule(), [a], [b], bottomrule(),
)
#same-size(own-header, tabular(
  columns: 2,
  toprule(), [H1], [H2], midrule(), [a], [b], bottomrule(),
))
#assert.eq(inner(own-header).fields().at("inset")(0, 1), (
  left: table-inset.left, right: table-inset.right,
  top: table-inset.top + belowrulesep, bottom: table-inset.bottom + aboverulesep,
))

// Plain string and numeric cells are accepted, like Typst's own table.
#assert.eq(kids(tabular(columns: 2, header-rows: 0, "A", 5)).len(), 2)
#assert.eq(headers(tabular(columns: 2, "A", "B")).len(), 1)

#let footed = tabular(columns: 2, [H1], [H2], [a], [b], table.footer([F1], [F2]))
#assert.eq(headers(footed).len(), 1)
#assert.eq(kids(footed).last().func(), table.footer)
