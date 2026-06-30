# TODO

Outstanding work items that aren't tracked in the test matrix or DESIGN.md's
"Known limitations" (those are accepted approximations; these are things we'd
actually like to do).

## Formats

- **acmcp infobox vertical anchoring.** LaTeX runs a two-pass `zref-savepos`
  fixed-point (acmart.dtx:6733): it records the cover infobox's bottom and the
  tinted frame's bottom into the `.aux`, then on the next run inserts a `\vspace`
  that drives the box bottom onto the frame bottom (it converges in one correction
  because the adjustment is *added* to the prior vspace). Typst has no cross-run
  page-position feedback, so we approximate with a fixed `dy` (~3 baselineskips)
  from the body top — close for a short cover, but it doesn't track the body length.
  - **Idea:** put the body and the infobox in a 2-cell `grid` with the infobox cell
    `bottom`-aligned. The row height is the taller of the two, so the infobox bottom
    lands on the body bottom when the body is taller, and the body sits at the top
    when the infobox is taller — matching LaTeX's two regimes without a magic
    number. Cost: the whole body goes in a grid cell (acmcp is single-page by
    design, so the lost cross-page breakability is acceptable). Worth trying.

## Tooling

- **Proper vector overlay via `pikepdf` (`tools/test.py overlay`).** The current
  `overlay` command recolours each PDF's ink with Ghostscript and stacks them
  with `qpdf --overlay` (Normal blend, no new Python deps). Two limitations come
  from that being a pure gs+qpdf pipeline:
  - **No true dark-on-overlap.** `qpdf --overlay` is an opaque Normal blend, so
    where the two engines align the top layer (Typst red) wins instead of the
    inks compositing to dark. A **Multiply blend mode** (and/or ~50 % constant
    alpha) would make aligned ink read dark and overlap read purple, like the old
    raster overlay did. That needs authoring an `ExtGState` with `/BM /Multiply`
    (and `/ca`), i.e. real content-stream / graphics-state surgery.
  - **Spot/ICC-colour ink isn't recoloured.** Ink set through a Separation/ICC
    colourspace via `setcolor` — acmart's JDS cover panel and its body text
    (`acmcp`) — keeps its original colour, because the gs operator override only
    catches the device colour operators (`setrgbcolor`/`setgray`/`setcmykcolor`).
    A content-stream rewrite could recolour every colour-setting operator
    regardless of colourspace.

  **Plan:** add `pikepdf` (it builds on the `qpdf` we already depend on) and
  redo `_vector_overlay` / `_gs_recolor` to (a) tokenise the content streams and
  force every colour operator to the flat tint, and (b) place the two pages as
  form XObjects in an `ExtGState` Multiply group with constant alpha. This
  removes both limitations and the gs `ps2write` round-trip. See the
  `_gs_recolor` docstring in `tools/test.py` for the current coverage gap.
