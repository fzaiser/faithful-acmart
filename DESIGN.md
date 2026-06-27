# Design notes

How this template is built, the key decisions, and — importantly — **where it
follows the LaTeX source faithfully versus where it matches the rendered output
empirically**. Read this before changing layout code.

## Goal & approach

Reproduce LaTeX `acmart` (format `acmsmall` so far) closely enough that a reader
can't easily tell the Typst and LaTeX outputs apart: same fonts, sizes, margins,
and spacing. We do **not** chase identical line/page breaks — the engines break
differently, and that's accepted.

The spec is the upstream class in [`acmart/`](acmart/) (`acmart.dtx`, which
generates `acmart.cls`, itself built on `amsart`). Every measurement was either
**probed** from the compiled class or **read** from the `.dtx`.

## Architecture

```
src/lib.typ            public acmart() entry; page setup; show/set rules; re-exports
src/formats/
  acmsmall.typ         ALL acmsmall measurements as a data dict (the only format yet)
src/parts/
  headings.typ         section / run-in heading show rule
  frontmatter.typ      title, authors, abstract, CCS, keywords, ref format, page-1 footnotes
  copyright.typ        permission text + © owner per copyright mode (incl. CC)
  theorems.typ         theorem/lemma/.../proof environments (+ shared counter, cfg state)
  body.typ             captions, lists, table, code, footnote, bibliography rules
```

**Format-as-data.** A format is a dict of measurements (`src/formats/acmsmall.typ`).
`lib.typ` is format-agnostic; adding `sigconf` etc. means adding a dict (and
handling two-column in `lib.typ`), not rewriting the parts.

**Config plumbing.** `acmart()` collects all user metadata into a `meta` dict
passed to the part functions. The format dict `cfg` is passed alongside, and also
published via `state` (`theorems.typ:cfg-state`) so the user-facing theorem
*functions* (called in the body, outside `acmart()`'s scope) can read it.

## Key mechanisms

### TeX points vs PostScript points
LaTeX lengths are **TeX points** (1pt = 1/72.27in); Typst's `pt` is a
**PostScript point** (1/72in). `src/formats/acmsmall.typ` defines
`tp = 72/72.27 * 1pt` and expresses every probed length as `N * tp`, so geometry
matches exactly. Paper sizes use `in` directly.

### The baseline grid (leading model)
TeX sets lines on a rigid `\baselineskip` independent of font metrics. Typst's
`leading` is the gap between line boxes, which *does* depend on font metrics. To
get a font-independent grid we pin the line box to the font size:

```
set text(top-edge: 1em, bottom-edge: 0pt)
set par(leading: baselineskip - font-size)   // => baseline pitch == baselineskip
```

`top-edge: 1em` also places the first baseline at `top-margin + \topskip`, which
matches LaTeX. The **title** overrides `top-edge: "cap-height"` so its (tall)
first line's cap-top sits at the top margin, matching TeX's `\topskip` behaviour
for a first line taller than `\topskip`. This is **matched to output**, verified
with `tools/linepitch.py` (pitch 11.94 vs 11.95pt; first baseline 92.07pt exact).

### Run-in headings
subsubsection/paragraph headings flow inline with the following text. A heading
show rule that returns *inline* content (not a block) achieves this; a weak
`v()` supplies the before-skip without breaking the run-in. The first-line indent
is cancelled with `h(indent - parindent)`.

### Page-1 footnote block
The author-notes / contact-info / copyright stack is emitted with
`place(bottom, float: true, …)` so it **reserves space** and the body flows above
it. (An earlier non-float `place(bottom)` overlapped body text on full pages.)

### Captions
`singlelinecheck` (caption package default): a caption that fits one line is
centred, otherwise left-justified. Implemented with `measure()` inside the
caption show rule.

## Faithful to source vs matched to output

**Faithful (probed/transcribed values):** page geometry, font-size steps,
`\baselineskip`, skips (`\bigskip` etc.), heading skips/fonts, theorem styles
(acmplain/acmdefinition), caption setup, copyright permission texts and owner
lines, journal name/ISSN table, link colours, line-number colour.

**Matched to rendered output (empirical, because TeX glue ≠ Typst spacing):**
title→authors gap, figure/caption float spacing, run-in separator width, and the
"numbered sections are uppercased, starred ones aren't" rule (the exact `.dtx`
macro that uppercases was never located — the rule was inferred from rendering).

**Deliberate approximations:**
- Bibliography uses Typst's built-in ACM CSL, not `ACM-Reference-Format.bst`.
- Authors' contact-info field order is consistent (name, email, affiliation); it
  does not reproduce LaTeX's source-order quirk.
- CC licence badge image (88×31) is omitted; the linked text statement is kept.
- Canada/other-gov copyright variants fall back to the acmlicensed wording.

## Known limitations / not done

- Only `acmsmall`. No `sigconf`/`sigplan`/… (no two-column support yet).
- Math fidelity untuned (Libertinus Math ≈ newtxmath, best-effort).
- No cumulative multi-page diff vs the real sample beyond the bundled test.
- No automated pass/fail thresholds; validation is visual + mismatch %.

## Validation

See the [README](README.md#development--validation) and the `Makefile`. The loop
is: build the LaTeX reference (`make reference`), build the Typst output, and diff
page-by-page (`tools/pdfdiff.py`) / measure (`tools/linepitch.py`). Fonts come
from the bundled OTFs via `tools/tc` (see the README "Fonts" section).
