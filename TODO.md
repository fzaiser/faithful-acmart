# TODO

Outstanding work items that aren't tracked in the test matrix or DESIGN.md's
"Known limitations" (those are accepted approximations; these are things we'd
actually like to do).

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
