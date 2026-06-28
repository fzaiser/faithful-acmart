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
  acmsmall.typ         acmsmall measurements as a builder fn of the base font size
src/parts/
  spacing.typ          comp() / tex-skip() — the TeX→Typst baseline-grid helpers
  headings.typ         section / run-in heading show rule
  frontmatter.typ      title, authors, abstract, CCS, keywords, ref format, page-1 footnotes
  copyright.typ        permission text + © owner per copyright mode (incl. CC)
  theorems.typ         theorem/lemma/.../proof environments (+ shared counter, cfg state)
  body.typ             captions, lists, table, code, footnote, bibliography rules
```

**Format-as-data.** A format is a dict of measurements built by a function of the
base font size (`src/formats/acmsmall.typ`). `lib.typ` is format-agnostic; adding
`sigconf` etc. means adding a builder (and handling two-column in `lib.typ`), not
rewriting the parts.

### Configurable base font size
acmart selects a base size via the `8pt|9pt|10pt|11pt|12pt` option and passes it
to amsart (`\LoadClass[\ACM@fontsize]{amsart}`, acmart.dtx:3090). The size steps
(`scriptsize`…`Huge`) and their baselineskips come from amsart's `\@typesizes`
table — a clamped window into one master font ladder with `normalsize` at the
chosen base; the amsart `\small`/`\med`/`\bigskip` are then `0.7·baselineskip`
halved (amsart's `\@adjustvertspacing`). `acmsmall(font-size:)` computes all of
this; **geometry, margins, and `\parindent` do NOT scale** — acmart fixes them
across font sizes (acmart.dtx:3750). Because every part already reads sizes from
the format dict (`cfg.font-size`/`cfg.baselineskip`/`cfg.size`/`cfg.bls` and the
skip fields), nothing else changes. Default is 10pt, so 10pt output is unchanged;
8/9/11/12pt are validated against LaTeX twins (`tests/fontsize-*-test`).

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

### Heading / block vertical spacing (the line-box compensation)
`\@startsection` places a heading a full `\baselineskip` **plus** `beforeskip`
below the previous baseline, and the body a `\baselineskip` plus `afterskip`
below the heading. Typst's line box is `1em` (= font size), **not**
`\baselineskip`, so a Typst block gap of `g` yields a baseline-to-baseline
distance of `g + 1em`. To reproduce LaTeX's `\baselineskip + skip` we therefore
set the block gap to `skip + (\baselineskip − font-size)`. For acmsmall sections
this gives `above = 0.75bl + (bl − 10pt)` and `below = 0.25bl + (bl − 10pt)`.
Verified against a descender-free probe: before-gap 20.92 vs LaTeX 20.96pt,
after-gap 14.94 vs 14.90pt — exact. (The same `(bl − font-size)` term is why the
inter-paragraph `spacing` is `bl − font-size`, giving a solid 12pt grid.)

The **same compensation applies to every `\baselineskip + skip` gap**, not just
`\@startsection` headings: amsthm theorem/proof environments (trivlist `\topsep`,
`theorems.typ`) and the frontmatter `\medskip`/`\bigskip` gaps (`frontmatter.typ`)
all add `(bl_next − size_next)` to the explicit skip. `bl_next`/`size_next` are
the *following* block's baselineskip/size (the interline glue uses the new line's
metrics), so e.g. a `\medskip` before 9pt text uses `4.2pt + (11 − 9)`.

Both pieces are centralized in [`src/parts/spacing.typ`](src/parts/spacing.typ):
`comp(cfg, sz)` = `bl − size` (the intra-block `leading`, and the compensation
term) and `tex-skip(cfg, skip, sz)` = `skip + comp` (a TeX skip as a Typst block /
`v()` gap). `sz` names the following line's size step (default `"normalsize"`).
Every `leading`, block gap, and `v()` in the template goes through these, so the
baseline model lives in exactly one place.

> **The amsart skips are NOT the article defaults.** acmsmall loads `amsart`,
> which sets `\smallskip`/`\medskip`/`\bigskip` to **2.1 / 4.2 / 8.4pt** (0.7× the
> familiar 3 / 6 / 12pt). `src/formats/acmsmall.typ` encodes the amsart values;
> run `make probe` to re-confirm. Float spacing (`\intextsep`, `\abovecaptionskip`
> = 12pt) is kept as its own constant so it does not ride on the `\bigskip` value.

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
`\baselineskip`, skips (amsart `\small/\med/\bigskip` = 2.1/4.2/8.4pt), float
spacing (`\intextsep`/`\abovecaptionskip`), heading skips/fonts, the run-in
separator (`-3.5pt`, the `\@startsection` afterskip), theorem styles
(acmplain/acmdefinition) and their `\topsep`, title→authors gap (title `\bigskip`
+ authors `\medskip`), caption setup, copyright permission texts and owner lines,
journal name/ISSN table, link colours, line-number colour. All of these are read
from the class — re-derive any value with `make probe` (geometry/sizes/skips) or
by reading the relevant macro in [`acmart/acmart.dtx`](acmart/acmart.dtx).

**Matched to rendered output (empirical, because TeX glue ≠ Typst spacing):**
the first-baseline placement of the (taller-than-`\topskip`) title line.

> Section titles are **mixed case** (bold sans), not uppercased — this matches
> the **bundled** acmart (v2.18; uppercasing was removed in v2.08). Beware: the
> system-installed acmart may be older (e.g. v2.03) and *does* uppercase level-1
> titles, so always validate against the bundled class — the LaTeX build is wired
> to generate it from [`acmart/`](acmart/) (see `tools/latex-build.sh`).

**Deliberate approximations:**
- Bibliography uses Typst's built-in ACM CSL, not `ACM-Reference-Format.bst`.
- The corresponding-author ✉ mark itself is faithful: acmart's `\correspondingauthor`
  (new in v2.18) emits a superscript envelope `\textsuperscript{\ding{41}}`
  (`acmart.dtx:5430`). What differs is *ordering* — we emit ✉-then-note in a fixed
  order, not LaTeX's source-declaration order, because our author model stores a
  boolean `corresponding` and a `note` with no declaration order to honour.
- **Author *contact-info* field order is fixed (affiliation, then email last),
  not source order.** acmart's `\@mkauthorsaddresses` replays each author's fields
  in the order they were declared, so an author who wrote `\email` before
  `\affiliation` shows the email first. Our author dict has no declaration order,
  so we always emit affiliation-then-email (the common acmart convention; the
  upstream sample's Tobin, who declares email first, is the lone exception).
- Author *line grouping* IS faithful (not an approximation): `group-authors`
  (`frontmatter.typ`) implements acmart's exact `\@mkauthors@i` rule
  (`acmart.dtx:7337`) — authors accumulate onto a line and an `\affiliation`
  closes it for everyone accumulated so far; affiliation values are never
  compared. To put two authors on one shared-affiliation line, give the
  affiliation to the *second* and omit it on the first (the acmart idiom; see the
  Trovato/Tobin pair in `sample-acmsmall.typ`).
- Lists: body indents are tuned to land at `\leftmargin` (24.5pt, level 1) for the
  common single-level case, but Typst has no fixed hanging-label box (LaTeX's
  `\llap`), so on deeply nested or width-varied markers the body drifts with the
  marker width. Labels/markers, item spacing, and the level-1 indent do match.
- `screen` link colours are stored as CMYK (`ACMPurple`/`ACMDarkBlue`, faithful to
  acmart). Typst writes CMYK 8-bit in the PDF (58% → 148/255), so the rendered
  on-screen RGB can differ from LaTeX's full-precision CMYK by ~1/255 per channel —
  imperceptible, and not "fixed" to RGB because that would lose print-CMYK fidelity.

## Known limitations / not done

- Only `acmsmall`. No `sigconf`/`sigplan`/… (no two-column support yet).
- Math fidelity untuned (Libertinus Math ≈ newtxmath, best-effort).
- No automated pass/fail thresholds; validation is visual + mismatch %.
- **Vertical justification (flushbottom-like fill) is not replicable in Typst.**
  acmsmall does *not* call `\flushbottom` (only acmtog/sigconf… do — see
  `acmart.dtx`'s `\ifcase\ACM@format@nr … \flushbottom`); nor does `amsart` or
  the LaTeX kernel set it for this format. Instead acmart redefines, for *all*
  formats, `\@textbottom` to `\vskip \z@ \@plus 1pt` (`acmart.dtx:3936`): the page
  bottom can absorb at most 1pt of slack, so on a *full* page the rubber glue in
  the section skips (`.75bl \@plus -2pt` etc.) stretches to fill the text to the
  bottom margin — observationally identical to `\flushbottom`. Typst has no
  vertical justification, so our
  pages are effectively ragged-bottom. Our section spacing is *exactly* correct
  — verified by forcing `\raggedbottom` in LaTeX, after which LaTeX's section
  positions match ours to within 0.2pt (increments 191.3 vs 191.3pt). The only
  difference is that LaTeX additionally stretches a full page by a few pt per
  section to reach the bottom; this shows as gradual vertical drift on full pages
  (e.g. `tests/full-test` page 1) but not on partial/last pages (page 2 matches).
  Each page's content and spacing are correct; only the bottom-fill stretch is
  missing. Not worked around — there is no clean Typst mechanism for it.

## Test harness robustness

LaTeX references are built via `tools/latex-build.sh`, which **reruns pdflatex
until stable** (cross-references / `TotPages` / lastpage resolved) and **fails if
a "Temporary page!" placeholder survives**. A single pdflatex pass leaves acmart
with an unresolved `TotPages`, producing a spurious extra page — the builder
prevents that from polluting diffs. `tools/build-reference.sh` and the Makefile
`test`/`test-references` targets all route through it.

`latex-build.sh` also **generates `acmart.cls` from the bundled [`acmart/`](acmart/)
sources** (into `tests/out/latex/`) and prepends that dir to `TEXINPUTS`, so every
reference is built against the repo's acmart, never whatever is installed in the
system TeX tree. This keeps the Typst target and the validator on the same class
version (see the section-title note above).

## Validation

See the [README](README.md#development--validation) and the `Makefile`. The loop
is: build the LaTeX reference (`make reference`), build the Typst output, and diff
page-by-page (`tools/pdfdiff.py`) / measure (`tools/linepitch.py`). Fonts come
from the bundled OTFs via `tools/tc` (see the README "Fonts" section).

To audit the *numbers* in `src/formats/acmsmall.typ` against the class itself, run
**`make probe`**: it compiles [`tools/probe.tex`](tools/probe.tex) against the
bundled acmart and dumps the geometry, font-size steps, baselineskips, and skips
(`PROBE …`/`SIZE …` lines). Every length in the format dict should trace back to a
probe line or a macro in `acmart/acmart.dtx` — prefer that over eyeballing pixels.
