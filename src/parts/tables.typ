// booktabs-style tables for acmart.
//
// ACM's table style is booktabs: no vertical rules, three horizontal rule weights
// (heavy \toprule/\bottomrule, light \midrule), and specific vertical separation
// around each rule (\aboverulesep above it, \belowrulesep below it). Typst's
// `table.hline` carries none of that surrounding space — a stroke only draws a
// line, it never pushes rows apart — so a plain Typst table renders booktabs rules
// flush against the cell struts, visibly tighter than LaTeX.
//
// `tabular` is a drop-in wrapper for `table` that restores the booktabs rule
// spacing. It is a plain FUNCTION, not a `show table` rule: a show rule whose body
// emits a table re-matches its own output ("maximum show rule depth exceeded"), so
// the wrapper sidesteps recursion entirely and needs no re-entry guard. It builds
// `std.table` internally, so it is unaffected by any shadowing of `table`.
//
// booktabs.sty constants: \heavyrulewidth=.08em, \lightrulewidth=.05em,
// \aboverulesep=.4ex, \belowrulesep=.65ex (\abovetopsep=\belowbottomsep=0pt, so the
// OUTER edge of the top/bottom rule gets no separation — handled for free: that
// rule has no row beyond the table boundary to space against).

// Shared with the `set table` inset in parts/body.typ. Only the horizontal cell
// padding lives here; the vertical row strut (LaTeX's \@arstrut — height
// .7\baselineskip, depth .3) is modelled in the cell TEXT metrics by body.typ's
// `show table` rule (top-edge/bottom-edge), so the base top/bottom inset is 0 and
// tabular's rule seps are the only vertical inset it adds.
#let table-inset = (left: 0.6em, right: 0.6em, top: 0pt, bottom: 0pt)

#let heavy-rule = 0.08em // \heavyrulewidth
#let light-rule = 0.05em // \lightrulewidth

// \aboverulesep/\belowrulesep are font-relative (ex). Typst has no ex unit and
// `tabular` must not wrap its output in `context` (a context block hides the table
// from figure()'s kind detection, losing the "Table N" supplement), so measuring
// the x-height at render time is out. Express ex as em instead: Libertinus Serif's
// x-height is 0.429em (measured 4.29pt at 10pt), and acmart sets every format's
// body in the Libertine/Libertinus family, so this ratio is universal. em tracks
// the cell font size exactly as ex would.
#let _ex = 0.429em
#let aboverulesep = 0.4 * _ex // space above a rule = below the row before it
#let belowrulesep = 0.65 * _ex // space below a rule = above the row after it

// \toprule / \midrule / \bottomrule: `table.hline` at the booktabs weights. Extra
// arguments (start/end for a partial rule, or an explicit stroke) pass through.
#let toprule(..a) = std.table.hline(stroke: heavy-rule, ..a)
#let midrule(..a) = std.table.hline(stroke: light-rule, ..a)
#let bottomrule(..a) = std.table.hline(stroke: heavy-rule, ..a)

// A `table` that adds booktabs rule separation around every horizontal rule. Same
// call signature as `table`; use `table.hline` (or toprule/midrule/bottomrule) for
// the rules. A child hline's resolved `y` is not exposed, so each rule's row
// boundary is inferred with the same row-major occupancy model as `table`, so
// colspan, rowspan, and explicitly positioned cells all contribute to the next
// automatic position.
// `header-rows` mirrors acmart's \tagpdfsetup{table/header-rows={1}}
// (acmart.dtx:4292): the first row of every table is a HEADER row, so assistive
// software reads each cell under its column heading instead of as loose data.
// Typst spells that `table.header`, which additionally REPEATS the row after a
// page break; acmart's declaration is tagging-only and moves nothing, so the
// header is built with `repeat: false` and the rendered table is unchanged. Pass
// `header-rows: 0` for a table whose first row is ordinary data, and a caller who
// builds their own `table.header` is left untouched.
#let tabular(header-rows: 1, ..args) = {
  let cols = args.named().at("columns", default: 1)
  let ncols = if type(cols) == array { cols.len() } else if type(cols) == int { cols } else { 1 }

  // `tabular` is a drop-in table wrapper: preserve a caller's inset and add the
  // booktabs separation to its top/bottom components. Accept the same scalar,
  // sides dictionary, or per-cell function forms as `table`.
  let caller-inset = args.named().at("inset", default: table-inset)
  let inset-at(x, y) = {
    let value = if type(caller-inset) == function { caller-inset(x, y) } else { caller-inset }
    if type(value) == dictionary {
      (
        left: value.at("left", default: value.at("x", default: 0pt)),
        right: value.at("right", default: value.at("x", default: 0pt)),
        top: value.at("top", default: value.at("y", default: 0pt)),
        bottom: value.at("bottom", default: value.at("y", default: 0pt)),
      )
    } else { (left: value, right: value, top: value, bottom: value) }
  }

  // Walk the children in order. A rule sits at the row boundary containing the
  // next automatic cell position. Occupied slots make rowspans and explicit
  // cells advance that cursor just as they do in Typst's table placement.
  // `below-top` rows have a rule directly above (top += \belowrulesep), `above-
  // bottom` rows have a rule directly below (bottom += \aboverulesep).
  let below-top = ()
  let above-bottom = ()
  let occupied = ()
  let cursor = 0
  let slot(x, y) = str(x) + ":" + str(y)
  let advance(position, cells) = {
    while slot(calc.rem(position, ncols), calc.quo(position, ncols)) in cells {
      position += 1
    }
    position
  }
  // Header selection must never move a cell, so it runs only when the children
  // can be read row-major with certainty: `columns` must be an explicit argument
  // (a `set table(columns: ..)` default is readable only from `context`, which
  // tabular must not enter), every cell must take its automatic position (an
  // explicit x/y can drop a cell into row 0 after later rows have been given),
  // and no header cell may span into the body. Anything else keeps the children
  // exactly as passed, tagging the table without a header rather than risking
  // the layout.
  let header-safe = "columns" in args.named()
  let header-start = none
  let header-end = none
  for (index, c) in args.pos().enumerate() {
    if c.func() == std.table.hline {
      let y-field = c.fields().at("y", default: auto)
      let y = if y-field == auto { calc.quo(cursor, ncols) } else { y-field }
      below-top.push(y)
      if y > 0 { above-bottom.push(y - 1) }
    } else if c.func() != std.table.vline {
      let fields = if c.func() == std.table.cell { c.fields() } else { (:) }
      let colspan = fields.at("colspan", default: 1)
      let rowspan = fields.at("rowspan", default: 1)
      let cell-x = fields.at("x", default: auto)
      let cell-y = fields.at("y", default: auto)
      cursor = advance(cursor, occupied)
      let x = if cell-x == auto { calc.rem(cursor, ncols) } else { cell-x }
      let y = if cell-y == auto { calc.quo(cursor, ncols) } else { cell-y }
      for dy in range(rowspan) {
        for dx in range(colspan) { occupied.push(slot(x + dx, y + dy)) }
      }
      if cell-x != auto or cell-y != auto { header-safe = false }
      if y < header-rows and y + rowspan > header-rows { header-safe = false }
      if header-start == none { header-start = index }
      if header-end == none and y >= header-rows { header-end = index }
      if cell-x == auto and cell-y == auto { cursor = y * ncols + x + colspan }
      cursor = advance(cursor, occupied)
    }
  }

  // Leading rules stay outside the header; it spans the cells of the first
  // `header-rows` rows (and any rule between them). A caller's own header or
  // footer, or a vline, inside that span means the run is not a plain row of
  // cells, so it is left alone.
  let children = args.pos()
  let stop = if header-end == none { children.len() } else { header-end }
  let plain(c) = (
    c.func() != std.table.header and c.func() != std.table.footer
      and c.func() != std.table.vline
  )
  let wrap = (
    header-safe and header-rows > 0 and header-start != none
      and children.all(c => c.func() != std.table.header)
      and children.slice(header-start, stop).all(plain)
  )
  let children = if wrap {
    let head = std.table.header(repeat: false, ..children.slice(header-start, stop))
    children.slice(0, header-start) + (head,) + children.slice(stop)
  } else { children }

  // A LaTeX `tabular` is a single box that never splits across a page/column
  // boundary — if it does not fit it moves whole to the next page. Typst tables
  // break across regions by default, so pin the box to LaTeX semantics with a
  // non-breakable wrapper. (Multi-page data belongs in `longtable`, which acmart
  // does not style; a floated `tabular` inside `figure` likewise never breaks.)
  // The wrapper keeps figure()'s table-kind detection (verified: "Table N").
  block(breakable: false, spacing: 0pt, std.table(
    ..children,
    ..args.named(),
    inset: (x, y) => {
      let base = inset-at(x, y)
      (
        ..base,
        top: base.top + (if y in below-top { belowrulesep } else { 0pt }),
        bottom: base.bottom + (if y in above-bottom { aboverulesep } else { 0pt }),
      )
    },
  ))
}
