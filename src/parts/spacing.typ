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

// A counter would resolve two layout passes later than the owner's location.
#let _marker(role, owner) = metadata((acm-glue: role, owner: owner))
#let _position(role, owner) = {
  let found = query(metadata.where(value: (acm-glue: role, owner: owner)))
  if found.len() == 1 { found.first().location().position() }
}
// An author's own fractional spacing outweighs these, as \vfill does.
#let _fr(stretch) = v(stretch / 1pt * 1e-12 * 1fr, weak: true)
// \newpage fills with \vfil.
#let fill-region() = v(1e-6 * 1fr)

// A float above the flow hides a region's top from the position test.
#let _region-fresh = state("acm-glue-region-fresh", false)
#let region-start() = { _region-fresh.update(true); [#metadata(none)<acm-glue-break>] }
#let region-used() = _region-fresh.update(false)

#let region-foot(wide: false) = [#metadata(wide)<acm-glue-foot>]
#let document-end() = [#metadata(none)<acm-glue-end>]

// TeX stretches \skip\footins and \textfloatsep far more than body glue; Typst cannot, so the slack stays above them.
// \clearpage fills the last page, and the balance package levels its columns.
#let _region-stretches(at) = {
  let end = query(<acm-glue-end>)
  if end.len() > 0 and end.last().location().page() == at.page { return false }
  // A weak page break cannot carry the fill.
  if query(<acm-glue-break>).any(m => m.location().page() == at.page + 1) { return false }
  let column = x => calc.floor(x / (page.width / page.columns))
  not query(<acm-glue-foot>).any(m => {
    let foot = m.location().position()
    foot.page == at.page and foot.y > at.y and (m.value or column(foot.x) == column(at.x))
  })
}

// The element after this glue carries no top spacing of its own.
// `override` behaves like `v(natural, weak: true)`, which replaces a preceding gap instead of taking the maximum.
#let glue-above(cfg, natural, stretch, override: false) = context {
  let stretches = cfg.flush-bottom and text.costs.runt != _nested-cost
  if override { v(natural, weak: true) }
  block(above: if override { 0pt } else { natural }, below: 0pt, height: 0pt, width: 100%, sticky: true,
    if stretches { _marker("at", here()) })
  if not stretches { return }
  let at = _position("at", here())
  let margin = page.margin
  // TeX discards glue at the top of a page.
  let top = _region-fresh.get() or (
    at != none and type(margin) == dictionary and "top" in margin and at.y < margin.top + 0.01pt)
  if not top and (at == none or _region-stretches(at)) { _fr(stretch) }
  region-used()
}

// The element before this glue carries no bottom spacing of its own.
// With `carry: false`, the following content supplies the natural gap.
#let glue-below(cfg, natural, stretch, carry: true) = context {
  let stretches = cfg.flush-bottom and text.costs.runt != _nested-cost
  if stretches {
    let (at, after) = (_position("at", here()), _position("after", here()))
    // TeX discards glue at the end of a page; the trailing tag attaches to the next frame.
    let at-region-end = at != none and after != none and (
      at.page != after.page or calc.abs((at.x - after.x).pt()) > 1 or after.y < at.y - 0.01pt)
    if not at-region-end and (at == none or _region-stretches(at)) { _fr(stretch) }
  }
  block(above: 0pt, below: if carry { natural } else { 0pt }, height: 0pt, width: 100%,
    if stretches { _marker("at", here()) })
  if stretches { _marker("after", here()) }
  region-used()
}
