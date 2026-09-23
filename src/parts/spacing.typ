// Translate TeX baseline spacing into Typst leading and block gaps.

// With a one-em line box, Typst needs the remaining baseline distance as leading.
// For a gap before a block, use the following line's font-size step.

#let comp(cfg, sz: "normalsize") = cfg.bls.at(sz) - cfg.size.at(sz)

#let tex-skip(cfg, skip, sz: "normalsize") = skip + comp(cfg, sz: sz)

// TeX glue `natural plus stretch`: the natural gap, then fractional spacing weighted by the stretch.
// Fractional spacing deletes adjacent weak spacing, so a zero-height block separates the two.
// The natural gap stays next to the neighboring content, where it collapses and Typst drops it at a region boundary.

// Fractional spacing would expand an auto-height container to the end of its region.
// Only a style reaches every descendant of a container; this cost leaves line breaking unchanged.
#let _nested-cost = 100.0001%
#let mark-nested-flows(body) = {
  show selector.or(
    block, box, grid.cell, table.cell, terms, footnote.entry, place, columns, pad, stack,
    rect, square, circle, ellipse, rotate, scale, move, skew,
  ): set text(costs: (runt: _nested-cost))
  body
}
#let no-stretch(body) = { set text(costs: (runt: _nested-cost)); body }
#let nested-flow() = text.costs.runt == _nested-cost

// An author's own fractional spacing outweighs these, as \vfill does.
#let _fr(stretch) = v(stretch / 1pt * 1e-12 * 1fr, weak: true)
// \newpage fills with \vfil.
#let fill-region() = v(1e-6 * 1fr)

// A float above the flow hides a region's top from the position test.
#let _region-fresh = state("acm-glue-region-fresh", false)
#let region-start() = { _region-fresh.update(true); [#metadata(none)<acm-glue-break>] }
#let region-used() = _region-fresh.update(false)

#let region-foot(notes: false, ref: none) = [#metadata((notes: notes, ref: ref))<acm-glue-foot>]

// The first layout lacks everything that reads the document, such as citations, so its positions are ignored:
// every point stretches in the second layout, whose slack is then measured whole.
#let _measurable() = query(<acm-glue-complete>).any(m => m.value)

#let _region(pos) = (pos.page, calc.floor(pos.x / (page.width / page.columns)))

// \clearpage fills the last page, and the balance package levels its columns.
#let _region-stretches(cfg, at) = {
  let end = query(<acm-glue-end>)
  if end.len() > 0 and end.last().location().page() == at.page { return false }
  // A weak page break cannot carry the fill.
  if query(<acm-glue-break>).any(m => m.location().page() == at.page + 1) { return false }
  if cfg.flush-edges { return true }
  // TeX stretches \skip\footins and \textfloatsep far more than body glue, so without reserved height the slack stays above them.
  let below(m, wide) = {
    let foot = m.location().position()
    foot.page == at.page and foot.y > at.y and (wide or _region(foot) == _region(at))
  }
  not (query(<acm-glue-foot>).any(m => below(m, false)) or query(<acm-glue-float>).any(m => below(m, m.value.wide)))
}

// Whether a point stretched in the layout that put it at `at`.
// The decision must come from one layout: a flag stored with the point would be a pass older than its position.
#let _active(cfg, point, at) = {
  if point.fresh or not _region-stretches(cfg, at) { return false }
  if point.kind == "above" {
    // TeX discards glue at the top of a page.
    let margin = page.margin
    not (type(margin) == dictionary and "top" in margin and at.y < margin.top + 0.01pt)
  } else {
    // TeX discards glue at the end of a page; the trailing tag attaches to the next frame.
    let after = query(<acm-glue-after>).find(m => m.value == point.owner)
    after == none or {
      let after = after.location().position()
      _region(after) == _region(at) and after.y > at.y - 0.01pt
    }
  }
}

// Fractional spacing never moves a line, but reserved height counts against Typst's widow and orphan rules,
// so a region's slack can change after it reserved; withdrawing the height would need more passes than Typst allows.
// The check sits outside the glue contexts because a failing context emits nothing, which would erase the record.
#let _check-reservations(cfg) = {
  let (heights, records) = ((), (:))
  let key(region) = str(region.at(0) * 100 + region.at(1))
  for (point, share) in query(<acm-glue-point>).zip(query(<acm-glue-share>)) {
    let (p, q) = (point.location().position(), share.location().position())
    if point.value.edge != none { records.insert(key(_region(p)), point.value.edge.slack) }
    if _region(q) == _region(p) { heights.push((key(_region(p)), calc.abs(q.y - p.y))) }
  }
  for edge in query(<acm-glue-edge>) { heights.push((key(_region(edge.location().position())), edge.value.height)) }
  let floats = query(<acm-glue-float>).filter(m => m.value.stretches)
  for extra in query(<acm-glue-float-extra>) {
    let marker = floats.find(m => m.value.owner == extra.value.owner)
    if marker != none { heights.push((key(_region(marker.location().position())), extra.value.height)) }
  }
  let moved = records.pairs().filter(((region, recorded)) => {
    let slack = heights.filter(h => h.at(0) == region).map(h => h.at(1)).sum(default: 0pt)
    calc.abs((recorded - slack).pt()) > 0.05
  }).map(((region, _)) => int(region))
  let first = moved.sorted().at(0, default: 0)
  let where = "page " + str(calc.quo(first, 100))
  if cfg.columns > 1 { where += ", column " + str(calc.rem(first, 100) + 1) }
  let next = if cfg.columns > 1 { "column" } else { "page" }
  assert(moved.len() == 0, message:
    "faithful-acmart: " + where + " changed after `flush-bottom: true` reserved space above its footnotes and around its floats, "
    + "usually because that space pushed a line to the next " + next + ".\n"
    + "Possible fixes:\n"
    + "(1) move the footnote or float;\n"
    + "(2) wrap every heading, list, and display on that page in `no-stretch`, so the page keeps its natural spacing;\n"
    + "(3) set `flush-bottom: \"body\"`.")
}

#let document-end(cfg) = {
  [#metadata(none)<acm-glue-end>]
  context [#metadata(query(<acm-glue-end>).len() > 0)<acm-glue-complete>]
  if cfg.flush-edges { context _check-reservations(cfg) }
}

// Typst cannot stretch the gaps at a region's edges: above footnotes, beside a float, and \@textbottom.
// Their share of the slack is reserved as fixed height, and fractional spacing divides the rest.
// The slack is what the previous pass gave to both, so it does not depend on the split.
#let _region-slack(cfg, region) = {
  if not cfg.flush-edges or not _measurable() { return none }
  let (points, shares) = (query(<acm-glue-point>), query(<acm-glue-share>))
  if points.len() != shares.len() { return none }
  let (slack, body, previous) = (0pt, 0pt, none)
  for (point, share) in points.zip(shares) {
    let (p, q) = (point.location().position(), share.location().position())
    if _region(p) != region { continue }
    if point.value.edge != none { previous = point.value.edge }
    // The share marker of the region's last point can sit in the next region.
    if _region(q) != region { continue }
    slack += calc.abs(q.y - p.y)
    if _active(cfg, point.value, p) { body += point.value.stretch }
  }
  if body == 0pt { return none }
  let reserved = (:)
  for edge in query(<acm-glue-edge>) {
    if _region(edge.location().position()) != region { continue }
    slack += edge.value.height
    reserved.insert(edge.value.owner, edge.value.height)
  }
  let feet = query(<acm-glue-foot>).filter(m => _region(m.location().position()) == region)
  // Typst commits a footnote entry to the column's insertions and only then restarts the column
  // with a smaller area, so a reference line that no longer fits leaves its entry behind.
  // Whether that happens depends on the area the first attempt saw, which reserved height changes,
  // so a region holding such an orphaned entry cannot predict its own slack.
  let stranded = feet.any(m => m.value.ref != none and _region(m.value.ref.position()) != region)
  let floats = query(<acm-glue-float>).filter(m => m.value.stretches and _region(m.location().position()) == region)
  for extra in query(<acm-glue-float-extra>) {
    if floats.any(m => m.value.owner == extra.value.owner) {
      slack += extra.value.height
      reserved.insert(repr(extra.value.owner), extra.value.height)
    }
  }
  // The recorded value stays put once written, or the record itself would never settle.
  // A stranded region still records, so a reservation that strands an entry later is caught.
  let record = if previous != none { previous.slack } else { slack }
  let edge = cfg.textbottom-stretch + floats.len() * cfg.float-stretch
  if feet.len() > 0 { edge += cfg.footins-stretch }
  // One line of the slack cannot be reserved. Typst's widow check sets a line only when the next line
  // fits too; when that next line then moves out because its footnote does not fit, the height it
  // leaves behind is measured as slack, but the widow check of the line before it still needs that
  // height free. A margin of one line passes 200 generated documents; any smaller margin fails 16.
  let room = calc.max(0pt, slack - cfg.baselineskip)
  let per-stretch = if stranded { 0 } else {
    calc.min(slack / (body + edge), if edge > 0pt { room / edge } else { 0 })
  }
  (slack: record, per-stretch: per-stretch, reserved: reserved,
    footnotes: feet.len() > 0, notes: feet.any(m => m.value.notes), floats: floats)
}

// A recomputed height differs from the recorded one by rounding, which would never settle.
#let _settle(height, slack, owner) = {
  let previous = slack.reserved.at(owner, default: none)
  if previous != none and calc.abs((previous - height).pt()) < 0.01 { previous } else { height }
}
#let _edge-record(owner, height) = [#metadata((owner: owner, height: height))<acm-glue-edge>]

// The gap above the first page's notes, which the caller adds to their clearance.
#let notes-gap(cfg) = {
  let notes = query(<acm-glue-foot>).find(m => m.value.notes)
  if not cfg.flush-bottom or notes == none { return 0pt }
  let slack = _region-slack(cfg, _region(notes.location().position()))
  if slack == none { 0pt } else { _settle(slack.per-stretch * cfg.footins-stretch, slack, "notes") }
}
#let notes-record(height) = _edge-record("notes", height)

// Typst sends an `auto` float to the top or bottom by the height used before it, which reserved height
// would change; `before` is what the caller hides from that decision with spacing around the float.
#let float-gap(cfg, owner) = {
  let marker = query(<acm-glue-float>).find(m => m.value.owner == owner)
  if marker == none { return (extra: 0pt, before: 0pt) }
  let region = _region(marker.location().position())
  let slack = _region-slack(cfg, region)
  if slack == none { return (extra: 0pt, before: 0pt) }
  let earlier = query(selector(<acm-glue-edge>).before(here()))
    .filter(m => _region(m.location().position()) == region).map(m => m.value.height)
  earlier += query(selector(<acm-glue-float-extra>).before(here()))
    .filter(m => slack.floats.any(f => f.value.owner == m.value.owner)).map(m => m.value.height)
  let extra = if marker.value.stretches { _settle(slack.per-stretch * cfg.float-stretch, slack, repr(owner)) } else { 0pt }
  (extra: extra, before: earlier.sum(default: 0pt))
}
#let float-marker(float) = [#metadata(float)<acm-glue-float>]
#let float-record(owner, height) = [#metadata((owner: owner, height: height))<acm-glue-float-extra>]

// The last stretch point of a region reserves the height above footnotes and at \@textbottom.
// It also records the region's slack, so the next pass can detect a change after reserving.
#let _region-edge(cfg, own) = {
  if own == none { return none }
  let region = _region(own.at)
  let next = own.points.at(own.i + 1, default: none)
  if next != none and _region(next.location().position()) == region { return none }
  let slack = _region-slack(cfg, region)
  if slack == none { return none }
  let stretch = cfg.textbottom-stretch
  if slack.footnotes and not slack.notes { stretch += cfg.footins-stretch }
  (height: _settle(slack.per-stretch * stretch, slack, "bottom"), slack: slack.slack)
}
#let _reserve-edge(edge) = if edge != none and edge.height > 0pt {
  place(bottom, float: true, clearance: 0pt, block(width: 100%, height: edge.height, _edge-record("bottom", edge.height)))
}

// A counter would resolve two layout passes later than the owner's location.
// A context created during relayout is not yet ordered among the known points, hence the owner check.
#let _own-point(owner) = {
  let points = query(<acm-glue-point>)
  let i = query(selector(<acm-glue-point>).before(owner)).len()
  let point = points.at(i, default: none)
  if point != none and point.value.owner == owner { (points: points, i: i, at: point.location().position()) }
}
#let _point(point) = [#metadata(point)<acm-glue-point>]
#let _share() = [#metadata(none)<acm-glue-share>]

// The element after this glue carries no top spacing of its own.
// `override` behaves like `v(natural, weak: true)`, which replaces a preceding gap instead of taking the maximum.
#let glue-above(cfg, natural, stretch, override: false) = context {
  let stretches = cfg.flush-bottom and text.costs.runt != _nested-cost
  let own = if stretches and _measurable() { _own-point(here()) }
  let edge = if stretches { _region-edge(cfg, own) }
  let point = (owner: here(), stretch: stretch, kind: "above", fresh: _region-fresh.get(), edge: edge)
  let active = stretches and not point.fresh and (own == none or _active(cfg, point, own.at))
  if override { v(natural, weak: true) }
  block(above: if override { 0pt } else { natural }, below: 0pt, height: 0pt, width: 100%, sticky: true,
    if stretches { _point(point) })
  if not stretches { return }
  if active { _fr(stretch) }
  // A tag attaches to the next frame, below the stretch.
  _share()
  _reserve-edge(edge)
  region-used()
}

// The element before this glue carries no bottom spacing of its own.
// With `carry: false`, the following content supplies the natural gap.
#let glue-below(cfg, natural, stretch, carry: true) = context {
  let stretches = cfg.flush-bottom and text.costs.runt != _nested-cost
  let own = if stretches and _measurable() { _own-point(here()) }
  let edge = if stretches { _region-edge(cfg, own) }
  let point = (owner: here(), stretch: stretch, kind: "below", fresh: false, edge: edge)
  let active = stretches and (own == none or _active(cfg, point, own.at))
  if stretches {
    // A placed marker stays above the stretch.
    place(_share())
    if active { _fr(stretch) }
  }
  block(above: 0pt, below: if carry { natural } else { 0pt }, height: 0pt, width: 100%,
    if stretches { _point(point) })
  if stretches {
    [#metadata(here())<acm-glue-after>]
    _reserve-edge(edge)
  }
  region-used()
}
