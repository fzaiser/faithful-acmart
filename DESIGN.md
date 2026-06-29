# Design notes

How this template is built, the key decisions, and — importantly — **where it
follows the LaTeX source faithfully versus where it matches the rendered output
empirically**. Read this before changing layout code.

## Goal & approach

Reproduce LaTeX `acmart` closely enough that a reader can't easily tell the Typst
and LaTeX outputs apart: same fonts, sizes, margins, and spacing. We do **not**
chase identical line/page breaks — the engines break differently, and that's
accepted.

All public acmart formats are accepted. They split into three families that
share the `parts/` machinery and mostly differ by a data dict in `formats/`; the
obsolete public names `siggraph` and `sigchi` are aliases to `sigconf`, matching
the bundled LaTeX class.

| family | formats | columns | top matter |
|---|---|---|---|
| single-column journal | manuscript, acmsmall, acmlarge | 1 | `@i` left title + author list, ACM bibstrip |
| two-column journal | acmtog | 2 | `@i` left title + author list, ACM bibstrip (spanning) |
| two-column proceedings | sigconf, sigplan, acmengage (`siggraph`/`sigchi` alias to `sigconf`) | 2 | `@iii` centered title + author grid, first-column copyright block |
| bespoke | sigchi-a (landscape), acmcp (cover) | 1 | best-effort (see Known limitations) |

Each format's geometry is **probed** from the bundled class (`tools/test.py probe
--format <name>`) via the kernel relation `body-top = 1in + topmargin + headheight
+ headsep` (validated exact against acmsmall's known 85/46/46/63.7); fonts and the
`\ifcase\ACM@format@nr` flags are **read** from `acmart.dtx`.

The spec is the upstream class in [`acmart/`](acmart/) (`acmart.dtx`, which
generates `acmart.cls`, itself built on `amsart`). Every measurement was either
**probed** from the compiled class or **read** from the `.dtx`.

## Architecture

```
src/lib.typ            public acmart() entry; page setup; show/set rules; re-exports
src/formats/
  _base.typ            shared font-size ladder + make-format() dict constructor
  <format>.typ         one builder per format (acmsmall, sigconf, …): probed
                       geometry + the format flags, everything else from _base
src/parts/
  spacing.typ          comp() / tex-skip() — the TeX→Typst baseline-grid helpers
  headings.typ         section / run-in heading show rule
  frontmatter.typ      title, authors, abstract, CCS, keywords, ref format, page-1 footnotes
  copyright.typ        permission text + © owner per copyright mode (incl. CC)
  theorems.typ         theorem/lemma/.../proof environments (+ shared counter, cfg state)
  body.typ             captions, lists, table, code, footnote, bibliography rules
```

**Format-as-data.** A format is a dict of measurements built by a function of the
base font size. The shared font-size ladder and the `make-format()` constructor
(which fills the format-independent constants — float/list/footnote/badge
geometry, fonts) live in `formats/_base.typ`; each `formats/<name>.typ` passes
only what differs (probed geometry + the `\ifcase` flags: `columns`,
`title-style`, `author-style`, `sec-fonts`, `bibstrip`/`conf-footer`,
`secnumdepth`, the title/author/affiliation fonts, …). `lib.typ` is
format-agnostic; the only format-shaped logic there is the two-column branch
(below).

### Two-column layout
`set page(columns: cfg.columns)` + `set columns(gutter: cfg.columnsep)` gives the
exact `\columnsep`. The title/author box spans both columns via
`place(top, scope: "parent", float: true, …)` — Typst's `scope: "parent"` escapes
the column to the full text width, reproducing LaTeX's `\twocolumn[\box\mktitle@bx]`
(acmart.dtx:6849). The abstract/CCS/keywords (`\@mkabstract` et seq.,
acmart.dtx:6665) follow the box in the **first column**, so `make-title` is split
into `make-title-head` (spanning) and `make-title-body` (in-column); for one
column the two are contiguous and the output is render-identical to before. The
conference copyright block (`\footnotetextcopyrightpermission`) is a column-scoped
`place(bottom, float: true)` so it lands at the bottom of the first column; the
journal bibstrip (acmtog) is instead the page footer, exactly as in print.

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
8/9/11/12pt are validated against LaTeX twins (`tests/twins/fontsize-*-test`).

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
with `tools/test.py linepitch` (pitch 11.94 vs 11.95pt; first baseline 92.07pt exact).

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
> run `tools/test.py probe` to re-confirm. Float spacing (`\intextsep`, `\abovecaptionskip`
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
from the class — re-derive any value with `tools/test.py probe`
(geometry/sizes/skips) or by reading the relevant macro in
[`acmart/acmart.dtx`](acmart/acmart.dtx).

**Matched to rendered output (empirical, because TeX glue ≠ Typst spacing):**
the first-baseline placement of the (taller-than-`\topskip`) title line.

> Section titles are **mixed case** (bold sans), not uppercased — this matches
> the **bundled** acmart (v2.18; uppercasing was removed in v2.08). Beware: the
> system-installed acmart may be older (e.g. v2.03) and *does* uppercase level-1
> titles, so always validate against the bundled class — the LaTeX build is wired
> to generate it from [`acmart/`](acmart/) (see `tools/test.py`'s `ensure_class`).

**Bibliography — two backends (`bibliography-backend`):**
- **`"csl"` (default)** — idiomatic Typst: native `bibliography()` with a vendored
  fork of the upstream ACM CSL at [`src/styles/acm-reference-format.csl`](src/styles/acm-reference-format.csl),
  edited to track the bundled `.bst` (DOI prints `doi:<id>`, abbreviated months,
  report genre label, thesis trailing note, conference-location parens — see the
  file's header). Native `@key` citations work. The residual divergences are
  hayagriva BibTeX→CSL *data-mapping* limits, not style choices, so they're
  unreachable from the CSL: dropped `lastaccessed` access dates, `@periodical`
  journal names, thesis `school`/advisor, conference `address`, the `genre` wording
  (`Doctoral dissertation` vs the .bst's `Ph. D. Dissertation`), and full-URL `doi`
  fields the .bst's `strip.doi` would trim.
- **`"bst"` — exact, no extra dependencies.** A pure-Typst port of
  `ACM-Reference-Format.bst`: [`parts/bibtex.typ`](src/parts/bibtex.typ) parses the
  `.bib` (via `read()`), [`parts/acmref.typ`](src/parts/acmref.typ) reimplements the
  `.bst`'s output state machine + `format.*` helpers + every entry-type handler +
  the sort/cite layer (native `state`/`query`), and [`parts/bib-data.typ`](src/parts/bib-data.typ)
  carries the `.bst`'s built-in journal MACRO table + `journal.canon.abbrev`
  (auto-extracted, so `journal = csur` → "Comput. Surveys" like bibtex). DOI / URL /
  arXiv-eprint / `\url`-in-note render as **real Typst hyperlinks** (acmart loads
  hyperref). Reached via the exported `acm-cite` (`\citep`) / `acm-citet` /
  `acm-citeyear` / `acm-citeauthor` / `acm-bibliography` (Typst exposes
  no hook to drive native `@key` numbering from a custom renderer, so the backend
  owns its cite layer). It reproduces the `.bst`'s reference text *exactly*: the
  `bib-all` (20 entry-type handlers), `bib-edge` (field/path edge cases),
  `crossref` (crossref + org→key + distinctURL) and `authoryear` (author-year mode)
  twins gate the full char bag against real bibtex with **no exemption**, plus a
  `link_check` gate on the `/URI` set and word-level assertions for what the
  whitespace-free char bag can't see. The von/Last/Jr name split follows the
  `biblatex` crate's `Person::parse` algorithm (von = up to the last lowercase word
  for `von Last, First`; the leading-cap / lowercase / trailing-cap partition for
  `First von Last`), verified field-by-field against it.

  **Implemented (each validated against real bibtex):**
  - **Author-year citation mode** — `cite-style: "author-year"` (acmart's
    `\citestyle{acmauthoryear}`). Short `format.lab.names` labels (von+Last only,
    `" and "` for two, `"et al."` for >2), the `\natexlab` `a`/`b`/`c`
    year-disambiguation suffix assigned over `(label, year)`-equal entries in sort
    order (the `forward.pass`/`reverse.pass` algorithm), a reference list with **no
    leading numbers**, and the natbib `\citep`/`\citet` renderers with same-author
    year compression (`[Smith and Doe 2020a,b]`). `acm-cite` = `\citep`, `acm-citet`
    = `\citet`, plus `acm-citeyear`/`acm-citeauthor`.
  - **`crossref`** — BibTeX *engine* behaviour (not in the `.bst`): the parent's
    missing fields are inherited into the child; the parent is listed only when
    crossref'd ≥ `min_crossrefs` (=2) times or cited directly; a child whose parent
    is listed renders the `.bst`'s `format.{article,book,incoll.inproc}.crossref`
    ("See [N]" / "In ⟨ed⟩ [N]"), and a child whose parent is *not* listed has its
    `crossref` dropped and renders in full from the inherited fields. Both thresholds
    + inheritance verified against bibtex.
  - **`organization`-as-label `format.key` fallback** for proceedings/manual (the
    `.bst`'s `organization format.key output`): an entry with neither name field nor
    organization leads with its `key` — both in the reference text *and* the sort key.
  - **`distinctURL`** — the per-entry field that prints the URL alongside a DOI
    (`output.url`'s `distinctURL empty.or.zero not`).
  - **Inline math (`$…$`) in fields** — a curated subset, enough for the maths that
    actually appears in titles (`$\lambda$-calculus`, `$\chi^2$`, `$\Theta(n)$`,
    `$O(n\log n)$`). `bibtex.typ`'s `decode-math` maps greek + relations + text
    operators to **base** Unicode and `^`/`_` to Unicode super/subscripts; these
    NFKC-fold to exactly what LaTeX's math-italic output extracts as
    (`𝜆`→`λ`, `²`→`2`), so the `mathfields` twin gates them with no exemption.
    Beyond the table, the **`tex-macros` option** (keyed by bare command name) lets a
    user supply replacements for custom commands — in both text and math — covering
    the `\newcommand` case without a TeX engine. Full equations / arbitrary nested
    constructs are still out of scope (unknown commands pass through verbatim).

  **Not ported** (genuinely out of reach, or faithful to omit — the exhaustive list):
  - **ISBN / ISBN-13 / ISSN / CODEN / LCCN.** Emitted by the `.bst` but suppressed by
    acmart (`\showISBNx` etc. left **undefined in every format** → the `.bbl`'s
    `\unskip` fallback eats them), so omitting them is *faithful to stock acmart*. A
    user who redefines `\showISBNx` to surface them can't via this backend; the
    `show-isbn-10-and-13` branch is unimplemented because no acmart format reaches it.
  - **Native `@key` / `#bibliography`** don't route to the bst engine — a deliberate
    omission, **not** an impossibility. A document-level `show ref:`/`show cite:` rule
    *can* intercept `@key` and render a custom citation (this is exactly how the
    `alexandria` and `pergamon` packages drive their own bibliographies; verified: a
    `show ref: it => …` rule renders `@foo` with no `bibliography()` loaded and no
    "label not found" error). We currently expose `acm-cite` & friends +
    `acm-bibliography` instead; wiring `@key` through a show-rule (numbering via the
    same `state` pass we already run) is a viable future addition.
  - **Arbitrary / full-equation TeX** beyond the `decode-math` table and `tex-macros`
    — *unbounded by nature*. A field can contain any TeX (multi-line display math,
    macros that expand to layout, `\newcommand`s pulled from the preamble);
    interpreting all of it would mean embedding a TeX engine. We decode the finite set
    titles use, let `tex-macros` patch the rest, and pass anything unknown through
    verbatim.
  - **BibTeX warnings** (missing year, empty author, bad page ranges…) are not emitted
    — by choice, not necessity. Rendering is best-effort and silent;
    `\begin{thebibliography}{width}` label-width (`longest.label`) is moot since Typst
    numbers the list natively.
  - **`, Article N` comma** is emitted unconditionally; the `.bst` keys it on output
    state (equivalent in practice — every reachable call site is post-`new.block`).

  **One rendering caveat:** the `\LaTeX`/`\TeX` *logos* — pdftotext extracts the
  LaTeX logo as `LATEX`, so logo-bearing entries don't char-match; the twins avoid
  them. (The text itself is correct; it's a glyph-extraction artifact.)
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

- **Vertical fill (`\flushbottom` / `\@textbottom`) is not replicable in Typst,**
  which has no vertical justification — so all formats are effectively
  ragged-bottom. Two distinct LaTeX mechanisms are missing:
  - *Two-column* formats (proceedings + acmtog) call `\flushbottom`
    (`acmart.dtx`'s `\ifcase\ACM@format@nr … \flushbottom`), so their columns are
    ragged-bottom and a page's two columns may differ in height; last-column
    balancing (`balance`) is likewise absent.
  - *All* formats — including single-column acmsmall, which does **not** call
    `\flushbottom` (nor does `amsart`/the kernel) — have acmart redefine
    `\@textbottom` to `\vskip \z@ \@plus 1pt` (`acmart.dtx:3936`): a full page
    absorbs ≤1pt of slack, so the rubber glue in the section skips
    (`.75bl \@plus -2pt` etc.) stretches the text to the bottom margin —
    observationally identical to `\flushbottom`.

  Each page's content and spacing are *exactly* correct — verified by forcing
  `\raggedbottom` in LaTeX, after which section positions match ours to within
  0.2pt (increments 191.3 vs 191.3pt). Only the bottom-fill stretch is missing; it
  shows as gradual downward drift on *full* pages (e.g. `tests/twins/full-test` page 1)
  but not on partial/last pages (page 2 matches). No clean Typst workaround exists.
- **`sigchi-a`** (best-effort): geometry, sans default, the 2pt-rule title,
  unnumbered sections and the "Legacy document" watermark are reproduced; footnotes
  are **not** moved into the margin (`\marginpar`, acmart.dtx:3533) and the `@iv`
  5pc title leftskip is omitted.
- **`acmcp`**: geometry, unnumbered sections, the suppressed ACM reference format,
  the light-tinted cover **frame** (`@ACM@Article@color!10!white`, default ACMBlue
  — acmart.dtx:5899), and the top-right cover **infobox** — the bundled JDS logo
  (`src/assets/acm-jdslogo.png`, from acmart's `acm-jdslogo.png`) over the optional
  `code-data-link` / `keywords` / `contributions` / author contact information —
  are reproduced; the top matter is narrowed by 6pc to clear the box. The only
  approximation is the box's vertical position: acmart uses two-pass `zref`
  measurement (acmart.dtx:6733) to butt it against the frame bottom on short
  documents; we anchor it to the top-right corner. Normal contact/copyright
  footnotes and normal keyword top matter are suppressed for `acmcp`, as in LaTeX.
- **Conference Huge title vertical position** differs from LaTeX by ~4–5pt of
  glyph-bbox overshoot: we pin the title cap-top to the top margin (the faithful
  `\topskip` model, as for acmsmall), whereas LaTeX places the baseline and lets
  the cap-top fall where the font's cap height puts it. Imperceptible; the sigplan
  twin marks its Tier-2 top check report-only for this reason.
- Math fidelity untuned (Libertinus Math ≈ newtxmath, best-effort).

## Test harness robustness

LaTeX references are built by `tools/test.py`'s `latex_build` helper, which
**reruns pdflatex until stable** (cross-references / `TotPages` / lastpage
resolved) and fails on surviving "Temporary page!" placeholders or final LaTeX
errors. A single pdflatex pass leaves acmart with an unresolved `TotPages`,
producing a spurious extra page — the builder prevents that from polluting diffs.
The sample-reference and `build`/`check` paths all route through it.

The harness also **generates `acmart.cls` from the bundled [`acmart/`](acmart/)
sources** (into `tests/out/latex/`) and prepends that dir to `TEXINPUTS`, so every
reference is built against the repo's acmart, never whatever is installed in the
system TeX tree. This keeps the Typst target and the validator on the same class
version (see the section-title note above).

## Validation

See the [README](README.md#development--validation). The harness is one Python
program, `tools/test.py`, driven by the matrix in `tools/test_matrix.py`. The
main loop is `tools/test.py check`: it builds the LaTeX references, compiles every
Typst test once, then runs the gates (warning/page-count smoke checks, Typst
raster goldens, extracted-text equality/semantic assertions, expected compile
errors, and cross-engine layout metrics). `tools/test.py validate` separately
builds copyright and option variants and reports page-1 mismatch percentages.
Fonts come from the bundled OTFs via `tools/tc` (see the README "Fonts" section).

To audit the *numbers* in `src/formats/acmsmall.typ` against the class itself, run
**`tools/test.py probe`**: it compiles [`tools/probe.tex`](tools/probe.tex)
against the bundled acmart and dumps the geometry, font-size steps, baselineskips,
and skips (`PROBE …`/`SIZE …` lines). Every length in the format dict should trace
back to a probe line or a macro in `acmart/acmart.dtx` — prefer that over
eyeballing pixels.
