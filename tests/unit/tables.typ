// Structural tests for tabular's drop-in arguments and row-boundary inference.

#import "/src/parts/tables.typ": tabular, toprule, midrule, bottomrule, aboverulesep, belowrulesep

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

// --- header rows ---------------------------------------------------------
// acmart declares row 1 of every table a header (\tagpdfsetup{table/header-rows=
// {1}}, acmart.dtx:4292). `tabular` builds that as a non-repeating table.header:
// leading rules stay outside it, and it ends at the first cell of the next row.
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
// LaTeX's declaration is tagging-only, so the row must not repeat after a break.
#assert.eq(head.at("repeat"), false)
// The header holds the two heading cells plus the rule that closes them; the
// body cells and the bottom rule stay outside it.
#assert.eq(head.children.len(), 3)
#assert.eq(head.children.at(2).func(), table.hline)
#assert.eq(kids(headed).len(), 5)

// Inserting the header must not move anything: same rendered size as with the
// feature off. Sizes are compared under `context`, so this exercises layout
// rather than the element fields alone.
#let same-size(a, b) = context assert.eq(
  (measure(a).width, measure(a).height),
  (measure(b).width, measure(b).height),
)
#same-size(headed, tabular(
  columns: 2,
  header-rows: 0,
  toprule(), [H1], [H2], midrule(), [a], [b], bottomrule(),
))

// `header-rows: 0` leaves the children untouched.
#assert.eq(headers(tabular(columns: 2, header-rows: 0, [a], [b])).len(), 0)

// Header selection is skipped whenever the children cannot be read row-major
// with certainty, because a wrong split silently moves cells. Each of these
// must compile AND come back with no header inserted.

// (a) a header cell spanning into the body would drag the body row up with it
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

// (b) without an explicit `columns` the row width is unknown here: a
// `set table(columns: ..)` default is only visible from `context`, which
// `tabular` must not enter, and guessing one column splits the first row.
#assert.eq(headers(tabular([H1], [H2], [A], [B])).len(), 0)

// (c) explicitly positioned cells can supply row 0 after row 1
#assert.eq(headers(tabular(
  columns: 2,
  [H1], table.cell(x: 0, y: 1)[A],
  table.cell(x: 1, y: 0)[H2], [B],
)).len(), 0)

// (d) a caller's own footer must not be swallowed by the header
#assert.eq(headers(tabular(columns: 2, table.footer([A], [B]))).len(), 0)

// (e) a caller's own header is kept as-is, not re-wrapped
#assert.eq(headers(tabular(columns: 2, table.header([H1], [H2]), [a], [b])).len(), 1)

// A footer that follows a normal first row is fine: the header stops at the
// first body cell, well before it.
#let footed = tabular(columns: 2, [H1], [H2], [a], [b], table.footer([F1], [F2]))
#assert.eq(headers(footed).len(), 1)
#assert.eq(kids(footed).last().func(), table.footer)
