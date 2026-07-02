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

## Publishing to Typst Universe

The port is packaged as the **`faithful-acmart`** template — manifest, `LICENSE`
(MIT) + `template/LICENSE` (MIT-0), `thumbnail.png`, and the `@preview` template
import are all committed, the harness is green, and the shipped bundle is verified
self-sufficient (a fresh `typst init`-style project compiles against the bundle with
only user `--font-path` fonts).

- **Confirm identity/repository.** DONE. `authors` = `Fabian Zaiser
  <fzaiser@mit.edu>`; `repository = "https://github.com/fzaiser/faithful-acmart"`;
  `LICENSE`/`template/LICENSE` copyright holder + year confirmed (2026 Fabian Zaiser).
- **Run `typst-package-check`.** DONE (installed from git: `cargo install --git
  https://github.com/typst/package-check --locked`, needs rustc ≥1.85.1). Ran on the
  assembled bundle: passes except the `manifest/package/repository/unreachable` error,
  which is expected until the repo is pushed (the URL 404s), and four advisory
  `readme/link/repository-url-permalink` warnings (README links to excluded files use
  `/blob/main/`; pin to a `v0.1.0` tag/commit permalink to silence them — non-blocking).
- **Optional:** `oxipng` the thumbnail. DONE — 1.45 MiB → 304 KiB (lossless, still
  1688×2500).
- **Submit.** NOT DONE (needs the user's GitHub account; `gh` isn't installed here and
  there is no git remote). Steps: (1) create + push the GitHub repo
  `fzaiser/faithful-acmart` (make `repository` reachable), ideally tag `v0.1.0`;
  (2) fork `typst/packages` (sparse checkout; do not copy `.git` or use submodules);
  (3) copy the bundle to `packages/preview/faithful-acmart/0.1.0/`; (4) open a PR
  (first-time author). Publication can take ~30 min after merge + CI.
- **Local dev note:** building the example (`tools/test.py example`) or running
  `typst init` needs the package linked into the Typst data dir —
  `ln -sfn "$PWD" "$HOME/Library/Application Support/typst/packages/preview/faithful-acmart/0.1.0"`
  (documented in DESIGN.md). `tools/test.py check` does not need it (the twins import
  `/src/lib.typ`).

## Bibliography

- **In-text citation hyperlinks on the `bibtex`/`biblatex` backends.** On the default
  `"bibtex"` (and `"biblatex"`) backend, `@key` / `#cite` render `[N]` as plain text
  that is *not* anchored to the reference list: the `show ref:` rule routes to
  `bbl-cite` (a text bracket), and the rendered entries carry no link targets. LaTeX +
  hyperref links them, and the `"typst"` backend keeps Typst's native cite links, so
  this is a fidelity + usability gap. **Plan:** emit a `label`/`link` target per
  reference entry in the bst/biblatex renderer (`parts/acmref-bst.typ` /
  `acmref-biblatex.typ`) and have `bbl-cite` link to it. DOI/arXiv/URL links *inside*
  entries already work.

- **Latent `bibtex` cite-path convergence edge.** Certain multi-cite paragraphs make
  `bib-path-state.final()` read `none` inside `prepared()` (`parts/acmref-cite.typ`) —
  cite resolution reads the path on an introspection pass before the `#bibliography`
  call registers it — so `read-merged(none)` → `read(none)` errors. Reproduces on the
  old bib-test fixture (8 `@key`s incl. dotted keys like
  `@Li:2008:PUC:1358628.1358946` in one sentence, `bib-backend: "bibtex"`). It does
  **not** affect the template or any pinned-`bibtex` twin (keycite / crossref /
  bib-all / sample-* all pass), and minimal single-/few-cite dotted-key cases compile;
  bib-test was demoted to a typst-only CSL smoke, so nothing exercises it now. Best
  fixed together with the cite-anchoring work above — both touch cite resolution.
