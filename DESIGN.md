# Design notes

How this template is built and the key decisions — in particular, **where it
follows the LaTeX source faithfully vs. matches the rendered output empirically**.
Read this before changing layout code.

## Goal & approach

Reproduce LaTeX `acmart` closely enough that a reader can't easily tell the Typst
and LaTeX outputs apart: same fonts, sizes, margins, spacing. We do **not** chase
identical line/page breaks — the engines break differently, and that's accepted.

All public acmart formats are accepted, in three families that share the `parts/`
machinery and differ mainly by a data dict in `formats/`:

| family | formats | columns | top matter |
|---|---|---|---|
| single-column journal | manuscript, acmsmall, acmlarge | 1 | `@i` left title + author list, ACM bibstrip |
| two-column journal | acmtog | 2 | `@i` left title + author list, spanning bibstrip |
| two-column proceedings | sigconf, sigplan, acmengage | 2 | `@iii` centered title + author grid, first-column copyright block |
| bespoke | sigchi-a (landscape), acmcp (cover) | 1 | best-effort (see Known limitations) |

Obsolete `siggraph`/`sigchi` alias to `sigconf`, matching the bundled class.

Each format's geometry is **probed** from the bundled class (`tools/test.py probe
--format <name>`) via `body-top = 1in + topmargin + headheight + headsep` (exact
against acmsmall's 85/46/46/63.7); fonts and the `\ifcase\ACM@format@nr` flags are
**read** from `acmart.dtx`. The spec is [`acmart/`](acmart/) (`acmart.dtx` →
`acmart.cls`, built on `amsart`); every measurement is probed or read from the `.dtx`.

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
  tables.typ           booktabs `tabular` wrapper + `toprule`/`midrule`/`bottomrule`
```

**Format-as-data.** A format is a dict of measurements built as a function of the
base font size. The font-size ladder and `make-format()` constructor (the
format-independent constants — float/list/footnote/badge geometry, fonts) live in
`formats/_base.typ`; each `formats/<name>.typ` passes only what differs (probed
geometry + the `\ifcase` flags: `columns`, `title-style`, `author-style`,
`sec-fonts`, `bibstrip`/`conf-footer`, `secnumdepth`, title/author/affiliation
fonts). `lib.typ` is format-agnostic except the two-column branch.

**Config plumbing.** `acmart()` collects user metadata into a `meta` dict passed to
the part functions, alongside the format dict `cfg` — also published via `state`
(`theorems.typ:cfg-state`) so body-level theorem *functions* can read it.

### Two-column layout
`set page(columns: cfg.columns)` + `set columns(gutter: cfg.columnsep)` gives the
exact `\columnsep`. The title/author box spans both columns via
`place(top, scope: "parent", float: true, …)` — `scope: "parent"` escapes to the
full text width, reproducing `\twocolumn[\box\mktitle@bx]` (acmart.dtx:6849). The
abstract/CCS/keywords (`\@mkabstract`, acmart.dtx:6665) follow it in the **first
column**, so `make-title` splits into `make-title-head` (spanning) and
`make-title-body` (in-column). The conference copyright block
(`\footnotetextcopyrightpermission`) is a column-scoped `place(bottom, float: true)`;
the acmtog journal bibstrip is the page footer instead.

### Configurable base font size
acmart picks a base size via `8pt|9pt|10pt|11pt|12pt` and passes it to amsart
(`\LoadClass[\ACM@fontsize]{amsart}`, acmart.dtx:3090). The size steps
(`scriptsize`…`Huge`) and their baselineskips come from amsart's `\@typesizes`
table (a clamped window into one master ladder with `normalsize` at the base);
`\small`/`\med`/`\bigskip` are `0.7·baselineskip` halved (`\@adjustvertspacing`).
**Geometry, margins, and `\parindent` do NOT scale** (acmart.dtx:3750). Every part
reads sizes from the dict (`cfg.font-size`/`baselineskip`/`size`/`bls` + skip
fields), so nothing else changes. Default 10pt; 8/9/11/12pt are validated against
`tests/twins/fontsize-*-test`.

## Key mechanisms

### TeX points vs PostScript points
LaTeX lengths are **TeX points** (1/72.27in); Typst's `pt` is a **PostScript
point** (1/72in). `formats/acmsmall.typ` defines `tp = 72/72.27 * 1pt` and
expresses every probed length as `N * tp`. Paper sizes use `in`.

### The baseline grid (leading model)
TeX sets lines on a rigid `\baselineskip`; Typst's `leading` depends on font
metrics. Pin the line box to the font size:

```
set text(top-edge: 1em, bottom-edge: 0pt)
set par(leading: baselineskip - font-size)   // => baseline pitch == baselineskip
```

`top-edge: 1em` also puts the first baseline at `top-margin + \topskip` (matches
LaTeX). The **title** uses `top-edge: "cap-height"` so its tall first line's cap-top
sits at the top margin (TeX's `\topskip` for a first line taller than `\topskip`) —
**matched to output**, verified with `tools/test.py linepitch` (pitch 11.94 vs
11.95pt; first baseline 92.07pt exact).

### Heading / block vertical spacing (line-box compensation)
`\@startsection` places a heading `\baselineskip + beforeskip` below the previous
baseline, and the body `\baselineskip + afterskip` below the heading. Typst's line
box is `1em` (= font size), **not** `\baselineskip`, so a block gap `g` yields a
baseline distance `g + 1em`. To reproduce LaTeX's `\baselineskip + skip` we set the
gap to `skip + (\baselineskip − font-size)`. For acmsmall sections this gives
`above = 0.75bl + (bl − 10pt)` and `below = 0.25bl + (bl − 10pt)` — verified against
a descender-free probe (before 20.92 vs 20.96pt, after 14.94 vs 14.90pt). The same
`(bl − font-size)` term makes the inter-paragraph `spacing` a solid 12pt grid.

The **same compensation applies to every `\baselineskip + skip` gap**: amsthm
theorem/proof (`\topsep`, `theorems.typ`) and the frontmatter `\medskip`/`\bigskip`
(`frontmatter.typ`) all add `(bl_next − size_next)` — the *following* block's metrics
— so a `\medskip` before 9pt text uses `4.2pt + (11 − 9)`. Both pieces are
centralized in [`spacing.typ`](src/parts/spacing.typ): `comp(cfg, sz)` = `bl − size`
and `tex-skip(cfg, skip, sz)` = `skip + comp` (`sz` names the following line's step,
default `normalsize`). Every leading, block gap, and `v()` routes through these.

> **The amsart skips are NOT the article defaults.** amsart sets
> `\smallskip`/`\medskip`/`\bigskip` to **2.1 / 4.2 / 8.4pt** (0.7× the familiar
> 3/6/12pt). `formats/acmsmall.typ` encodes them; `tools/test.py probe` re-confirms.
> Float spacing (`\intextsep`/`\abovecaptionskip` = 12pt) is its own constant, not
> derived from `\bigskip`.

The **number → title separator** is acmart's `\@seccntformat` `\quad` (1em),
modelled as a 1em-wide box holding a single space (`box(width: 1em, sym.space)`) —
literally a quad-width space. The space is load-bearing for the tagged PDF, not
visible: a bare `h(1em)` (or an *empty* box) abutting the title makes Typst tag the
first word glyph-by-glyph, scrambling the Tier 1.9 reading-order gate, whereas a box
carrying real text keeps the title one *word run*. It extracts as an ordinary space,
so the text gates are unaffected. See the harness note below on why the section
number itself is no longer a text-gate problem.

### Run-in headings
subsubsection/paragraph headings flow inline: a heading show rule returning *inline*
content (not a block), with a weak `v()` for the before-skip and
`h(indent - parindent)` cancelling the first-line indent.

### Page-1 footnote block
The author-notes / contact-info / copyright stack is emitted with
`place(bottom, float: true, clearance: …)` so it **reserves space** and the body
flows above. The `clearance` is `\skip\footins − \kern` (~4pt — the same body→
footnote gap the in-body footnotes use), **not** Typst's 1.5em float default;
without it the body stopped 1–2 lines short of where LaTeX fills. (The gap
*between* the manyfoot streams — contact vs copyright — is still tighter than
LaTeX's per-stream `\skip\footins`; the reported symptom was the space *above* the
whole block, which the clearance addresses.)

### Captions
`singlelinecheck`: a caption that fits one line is centred, otherwise justified to
the **full column** with a ragged-left last line
(`block(width: 100%, align(left, …))`, matching acmart's `margin=\z@` caption) —
branch chosen by `measure()` in the caption show rule. (`align()` alone leaves a
justified paragraph at its natural break width, ~4pt narrow, and inherits the
figure's centring on the last line.)

## Faithful to source vs matched to output

**Faithful (probed/transcribed):** page geometry, font-size steps, `\baselineskip`,
skips (2.1/4.2/8.4pt), float spacing, heading skips/fonts, the run-in separator
(`-3.5pt`, the `\@startsection` afterskip), theorem styles (acmplain/acmdefinition)
+ `\topsep`, title→authors gap, caption setup, copyright texts + owner lines,
journal name/ISSN table, link colours, line-number colour. Re-derive any value with
`tools/test.py probe` or by reading the macro in [`acmart.dtx`](acmart/acmart.dtx).

**Matched to rendered output (empirical):** the first-baseline placement of the
taller-than-`\topskip` title line.

> Section titles are **mixed case** (bold sans), not uppercased — matches the
> **bundled** acmart (v2.18; uppercasing removed in v2.08). A system acmart may be
> older (v2.03) and *does* uppercase level-1 titles, so always validate against the
> bundled class (`tools/test.py`'s `ensure_class` generates it from [`acmart/`](acmart/)).

## Package policy

Two deliberate policies where LaTeX's semantics have no direct Typst analog. Both
are *package conventions*, not "the LaTeX fact" — flagged here so they aren't
mistaken for faithfulness bugs.

- **Explicit arguments override format defaults.** LaTeX distinguishes a preamble
  option from a post-`\begin{document}` `\settopmatter`, and several class options
  (`nonacm`, `acmcp`) flip a `\settopmatter` key off via an
  `\AtBeginDocument{\@ACM@…false}` hook (acmart.dtx:2717/3006) that a *preamble*
  setting cannot beat but a *body* one can. This package has no such timing, so it
  resolves the ambiguity by letting an explicit user argument always win over a
  format default. The motivating case is `print-acm-reference`: `nonacm`/`acmcp`
  flip its **default** to false, but `print-acm-reference: true` re-enables the ACM
  Reference Format block — matching a reachable LaTeX `\settopmatter{printacmref=true}`
  after `\begin{document}` (probe-verified on acmcp). `options.typ` resolves `auto`
  to the format default and passes any explicit value straight through.
- **`conference: auto` vs `none`.** `auto` reproduces acmart's *untouched* default —
  on proceedings formats that is the class's placeholder "Conference'17" line
  (`\acmConference` defaults, acmart.dtx), none on journal/manuscript. Explicit
  `none` is a **Typst-only suppression** of that line: acmart offers no way to blank
  the conference, so `none` is a deliberate extension, distinct from `auto`.
- **Author notes dedup by content.** acmart's `\authornote` attaches a footnote to a
  specific author and repeats an *identical* note under a fresh symbol only if
  written twice; two authors sharing one note use `\authornotemark[n]` to reuse the
  first symbol. Our API stores each author's `note` as content, and `collect-notes`
  deduplicates by content — two authors with the *same* note content share one
  symbol automatically (the `\authornotemark`-equivalent comes for free), while
  distinct notes each get their own symbol. This is an intentional API mapping, not
  a divergence.

## Bibliography — three backends (`bib-backend`)

- **`"typst"` — idiomatic, an approximation.** Native `bibliography()` with Typst's
  built-in ACM CSL (`association-for-computing-machinery`); native `@key` keeps
  Typst's cite hyperlinks. *Not* faithful: bounded by the style's own choices (full
  month names, `https://doi.org/<id>` DOIs, `Doctoral dissertation` wording, no
  report genre label) and by hayagriva's BibTeX→CSL data-mapping limits (dropped
  `lastaccessed`, `@periodical` journal names, thesis `school`/advisor, conference
  `address`). For `.bst`-exact output use `"bibtex"`.
- **`"bibtex"` (default) — exact, no extra dependencies.** A pure-Typst port of
  `ACM-Reference-Format.bst`: [`bibtex.typ`](src/parts/bibtex.typ) parses the `.bib`
  (`read()`), [`acmref.typ`](src/parts/acmref.typ) reimplements the `.bst` output
  state machine + `format.*` helpers + every entry-type handler + the sort/cite layer
  (native `state`/`query`), and [`bib-data.typ`](src/parts/bib-data.typ) carries the
  journal MACRO table + `journal.canon.abbrev` (so `journal = csur` → "Comput.
  Surveys"). DOI/URL/arXiv/`\url` render as real Typst hyperlinks; in-text citations
  are anchored to the reference list (each entry carries `entry-label(key)`; cite
  numbers / author-year groups `link` to it — ACMPurple in screen mode, matching
  acmart's `citecolor`; uncoloured in print). Reached via `@key` (a `show ref:` rule),
  the shadowed `cite`/`bibliography`, and `cite-text`/`cite-year`/`cite-author`.
  Reproduces the `.bst` text **exactly**: the `bib-all` (20 entry-type handlers),
  `bib-edge`, `crossref`, `authoryear`, `mathfields`, and `keycite` twins gate the
  full char bag against real bibtex with **no exemption**, plus a `link_check` gate on
  the `/URI` set and word-level assertions. The von/Last/Jr split tokenizes on **raw
  TeX** per BibTeX's `format.name$` (`von_name_ends`+`von_token_found` from
  `bibtex.web`): a token's case is its first brace-level-0 letter (or a `{\..}` foreign
  letter), so `{de la}`/`{Barnes & Co.}` are Last; the von part may lead with uppercase
  (`De la`); a bare `\ss` doesn't split (`Stra\ss e` → Last). Verified against the
  bibtex binary (`tests/unit/bibtex.typ`).
- **`"biblatex"` — ACM BibLaTeX, no extra dependencies.** A sibling renderer in
  [`acmref.typ`](src/parts/acmref.typ) ports the visible formatting of `acmnumeric.bbx`,
  the `acmauthoryear.bbx` deltas, and `biblatex-software` (`software.bbx`/`.dbx`,
  `english-software.lbx`), reusing the same reader, sort/cite state, `@key`/
  `#bibliography` routing, and `cite-style: "numeric" | "author-year"` switch. Covers
  sentence-cased numeric titles, preserved/quoted author-year titles, full journal
  names, `doi: <id>` punctuation, `lastaccessed` dates, `In:`/booktitle and journal
  italics, software-family inheritance, SWHID source-map normalization, ACM's software
  labels (`[SW]`, `[SW Rel.]`, `[SW Mod.]`, `[SW exc.]`), and HAL/URL/VCS/SWHID
  identifier blocks. The `biblatex-test` twin gates acmnumeric against biber with no
  exemption; the full samples exercise the software cite block against upstream.

### Implemented (each validated against real bibtex)
- **Author-year mode** (`cite-style: "author-year"`, `\citestyle{acmauthoryear}`):
  short `format.lab.names` labels (von+Last, `" and "` for two, `"et al."` for >2), the
  `\natexlab` a/b/c suffix over `(label, year)`-equal entries in sort order
  (forward/reverse pass), a list with **no leading numbers**, and natbib `\citep`/
  `\citet` with same-author year compression (`[Smith and Doe 2020a,b]`).
- **`crossref`** (BibTeX *engine* behaviour, not the `.bst`): parent fields inherited
  into the child; the parent is listed only when crossref'd ≥ `min_crossrefs` (=2) or
  cited directly; a listed-parent child renders `format.{article,book,incoll.inproc}.
  crossref` ("See [N]" / "In ⟨ed⟩ [N]"), an unlisted-parent child drops `crossref` and
  renders in full from inherited fields.
- **`organization`-as-label `format.key` fallback** (proceedings/manual): an entry
  with no name field nor organization leads with its `key`, in text and sort key.
- **`distinctURL`**: prints the URL alongside a DOI.
- **Native `@key`/`#cite`/`#bibliography` routing**, via two mechanisms in `lib.typ`:
  - `@key` is Typst *syntax* (a `ref`, unshadowable), so a document-level `show ref:`
    rule (gated `bib-backend != "typst"`) routes it to the engine — the hook
    `alexandria`/`pergamon` use. A `ref` resolving to no label (`it.element == none`) is
    a citation; real elements (figures/headings/equations) pass through.
  - `cite`/`bibliography` are *functions*, so they are **shadowed**. `cite` groups keys
    into one bracket; `bibliography` renders through the engine — required because Typst
    validates a native `#bibliography` source through hayagriva *at element construction*
    (before any show rule fires), so a `.bst`-only feature such as a journal-abbreviation
    macro (`journal = csur`) would error; the shadow never constructs a native element.
    The engines `read()` the `.bib` lazily; Typst resolves a `read()` path against where
    the path value was *written*, which survives only on an un-indexed `arguments` value
    — so the shadow threads a single positional path as `arguments` to `read(..args)`
    (**relative paths work**). Indexing (several files, or an array) loses the origin, so
    those require a **project-absolute** path (`"/refs.bib"`, asserted).

  For `"typst"` the `show ref:` rule is the identity and both shadows delegate to
  `std.cite`/`std.bibliography` (the ACM CSL `set bibliography(style: …)` in `body.typ`
  styles the list), so relative and multi-file paths both work; `cite-text`/`cite-year`/
  `cite-author` map to `std.cite(form: "prose"/"year"/"author")`.
- **TeX-string handling follows BibTeX literally** (`tex.typ`). BibTeX never
  normalizes to Unicode — it carries the **raw** TeX and applies only `purify$` (sort
  keys) and `change.case$` (display case), both math-blind and brace-aware. Both ported
  exactly (quoting `bibtex.web`'s `x_purify`/`x_change_case` + the 13-entry
  `control_seq_ilk` foreign-letter table; oracle-tested in `tests/unit/tex.typ`). Fields
  stay raw TeX until the **render seam**: one mode-independent tokenizer (text runs,
  control words/symbols, `{groups}`, `$math$`, catcode-special `~ ^ _`) feeding
  evaluators — to content (`tex-to-content`), to a plain string for sort/cite labels
  (`tex-to-string`, never overridable), or to a Typst-math string that is `eval`'d. Name
  tokens are tie-joined per `format.name$` (a `~` before the last token / after a single
  letter), so `Stra\ss e` renders `Straß e`.
- **Inline math (`$…$`) is real Typst math**: symbols (`\alpha`→`alpha`, `\leq`→`<=`,
  `\oplus`→`plus.o`), 1-/2-arg functions (`\frac{a}{b}`→`frac(a,b)`, `\mathbb{R}`→
  `bb(R)`, `\sqrt`), `^{..}`/`_{..}` → `^(..)`/`_(..)`, then `eval`'d. Extracts to the
  same char-bag as LaTeX math-italic (`𝜆`, plain-digit sub/superscripts, `ℝ`→`R` under
  NFKC), so `mathfields` gates with no exemption.
- **Formatting commands**: `\emph`/`\textit`→`emph`, `\textbf`→`strong`, `\textsc`→
  `smallcaps`, `\texttt`→`raw`, `\underline`, `\textsuperscript`/`\textsubscript`;
  `\url`/`\href`→links; accents + foreign letters (`\ss`)→Unicode; `\LaTeX`/`\TeX`→logos.
- **Unknown commands raise an error** (never silent), naming the command and pointing at
  the **`tex-render`** override: a callback `(raw-tex: str) => content` (default `auto` =
  `tex-to-content`), composable with the exported `default-tex-render`, e.g.
  `tex-render: s => default-tex-render(s.replace("\\myunit", "kg"))`. A small allowlist
  of no-ops (`\noopsort`, `\relax`, `\protect`, …) is recognized.

### Not ported (out of reach, or faithful to omit)
- **ISBN/ISSN/CODEN/LCCN**: emitted by the `.bst` but suppressed by acmart (`\showISBNx`
  etc. undefined in every format → the `.bbl`'s `\unskip` eats them), so omitting them is
  *faithful to stock acmart*. Redefining `\showISBNx` to surface them isn't supported.
- **Arbitrary/full-equation TeX** beyond the command tables + `tex-render` —
  *unbounded* (a field can hold any TeX; interpreting all of it means a TeX engine). We
  support the finite set references use and **error on anything unknown**.

### tex-render accepted approximations (correct for the common case)
- Math-symbol table is curated and only spot-verified: `mathfields` oracle-tests greek +
  `\leq \frac \oplus \mathbb \log`; the other ~110 entries compile but aren't diffed, so
  a wrong-but-valid mapping renders silently. Greek + tested set trusted; long tail
  best-effort.
- `/` inside `$…$` becomes a Typst fraction, not a literal slash (rare in refs).
- `\left`/`\right` are dropped, so delimiters don't auto-size (the bare delimiter prints).
- Accents render as combining sequences (`o`+◌̈), not precomposed — NFKC-fold
  identically, so invisible (we just don't NFC-normalize).
- `edition` is lowercased with `lower()`, not brace-aware `change.case$` (differs only
  for a braced edition).
- Multi-token first-name tie placement may not match BibTeX exactly — inter-token
  spacing is whitespace, dropped by the char bag.
- `url`/`doi`/`eprint` bypass the render seam (linked with the raw string; URLs rarely
  contain TeX).
- `tex-to-string` (sort/cite labels) errors on inline math — labels never carry `$…$`.
- Recursion vs Typst's ~72 call-depth: the evaluator loops over the token list (field
  length unbounded); only structural nesting recurses, so overflow needs ~70+ nested
  braces/math.
- BibTeX warnings aren't emitted (best-effort, silent); `thebibliography` label-width is
  moot (Typst numbers natively).
- `, Article N` comma is emitted unconditionally (every reachable call site is
  post-`new.block`).
- **Caveat:** the `\LaTeX`/`\TeX` logos extract as `LATEX` under pdftotext, so
  logo-bearing entries don't char-match; the twins avoid them (the text is correct — a
  glyph-extraction artifact).

## Author top matter

- **Corresponding-author ✉ is faithful**: acmart's `\correspondingauthor` (v2.18) emits
  `\textsuperscript{\ding{41}}` (acmart.dtx:5430). What differs is *ordering* — we emit
  ✉-then-note in a fixed order, not source-declaration order (our model stores a boolean
  + note, with no declaration order).
- **Contact-info field order follows the author dict's key order** — acmart's
  `\@mkauthorsaddresses` replays the declared `\email`/`\affiliation` order; Typst
  dicts preserve insertion order, so writing `email:` before `affiliation:` (or vice
  versa) reproduces the declaration order (guarded by the Tier 1.9 order gate). The
  **affiliation's own fields** (`institution`/`department`/`city`/`state`/`country`)
  likewise print in the user's declared key order, not a fixed tuple — acmart replays
  `\institution`/`\department`/… in command order, so an affiliation written
  `department:` before `institution:` reads "Theory Division, The Group, …" in the
  contact line (`contact-affil-strings`, `frontmatter.typ`; `title-test` declares one
  department-first).
- **Author line grouping IS faithful**: `group-authors` (`frontmatter.typ`) implements
  `\@mkauthors@i` (acmart.dtx:7337) — authors accumulate onto a line and an
  `\affiliation` closes it for everyone accumulated so far; values are never compared.
  For a shared-affiliation line, give the affiliation to the *second* author and omit it
  on the first (the acmart idiom; see Trovato/Tobin in `sample-acmsmall.typ`).
- **Lists match the LIVE class, not the dtx**: amsart's begin-document hook derives
  the margins from rendered label widths (`\labelsep` 5pt, `\leftmargini` =
  width("(13)") + labelsep + `\parindent` ≈ 30.26pt, nested levels from their own
  labels at counter 13) and overrides acmart's 4pt/24.5pt block — probed and measured.
  Labels are `\llap`'d in both engines: zero-width right-overhanging markers pin every
  body at its level's `\leftmargin` exactly; level-2+ `\topsep` is 0. `quote` maps to
  LaTeX's `quote` (both margins at `\leftmargini`); the 3pc `quotation` variant is not
  modelled.
- **`screen` link colours** are stored as CMYK (`ACMPurple`/`ACMDarkBlue`); Typst writes
  8-bit CMYK, so the on-screen RGB can differ by ~1/255 per channel — imperceptible, and
  not "fixed" to RGB (that would lose print-CMYK fidelity).

## Known limitations / not done

- **Vertical fill (`\flushbottom`/`\@textbottom`) is not replicable** — Typst has no
  vertical justification, so all formats are ragged-bottom. Two LaTeX mechanisms are
  missing: (1) *two-column* formats call `\flushbottom`, so columns don't fill and
  last-column balancing (`balance`) is absent; (2) *all* formats — including
  single-column acmsmall, which does **not** call `\flushbottom` — redefine
  `\@textbottom` to `\vskip \z@ \@plus 1pt` (acmart.dtx:3936), so a full page stretches
  the section-skip rubber glue to the bottom margin. Content and spacing are *exactly*
  correct (forcing `\raggedbottom` in LaTeX matches section positions to 0.2pt); only the
  bottom-fill stretch is missing, showing as gradual drift on *full* pages
  (`tests/twins/full-test` p1), not partial/last pages. No clean Typst workaround.
- **`sigchi-a`**: geometry, sans default, the `@mktitle@iv` title (5pc-leftskip ragged
  under a 2pt rule, one title-`\baselineskip` below its bottom, acmart.dtx:7039), the
  `@mkauthors@iv` grid (bold name + email + affiliation, 2/row, acmart.dtx:7518), the
  margin-column running head (`\fancyheadoffset`, x measured exact), unnumbered
  sections, bold-small captions, and the "Legacy document" watermark match LaTeX.
  `sidebar`/`marginfigure`/`margintable` set their body in the 170pt margin column
  (`\marginpar`; a sidebar's first baseline is measured exact) and `fulltextwidth()`
  spans text + margin. Approximations: footnotes are **not** moved into the margin
  (`\marginpar` footnotes, acmart.dtx:3533); a margin note's vertical anchor can sit
  ~1–2 lines off when invoked right before a display heading (Typst's `place()` anchors
  at the following block); consecutive notes at the SAME anchor overlap instead of
  stacking — anchor them at different paragraphs.
- **`acmcp`**: geometry, unnumbered sections, the suppressed ACM reference format, the
  rotated article-type label at the left edge, the light-tinted cover **frame**
  (`@ACM@Article@color!10!white`, acmart.dtx:5899) scoped to the **body only** and
  narrowed 6.5pc right (acmart.dtx:5902), and the right-margin **infobox** (the
  user-supplied `acmcp-logo` — ACM's trademark JDS logo isn't bundled, so
  `src/assets/acm-jdslogo.png` is twin-only — over the optional `code-data-link`/
  `keywords`/`contributions`/contact info) are reproduced; the title alone narrows 6pc
  (acmart.dtx:6988). The infobox and tinted body are a two-cell grid: the body cell
  stays top-aligned, while the infobox cell is bottom-aligned so its bottom lands on
  the frame bottom, matching acmart's two-pass `zref` adjustment (acmart.dtx:6733)
  without a magic vertical offset. The code/data URL wraps where LaTeX overflows
  (one word-bag token splits). Normal contact/copyright footnotes and keyword top
  matter are suppressed, as in LaTeX.
- **Conference Huge title** sits ~4–5pt off from LaTeX (glyph-bbox overshoot): we pin the
  cap-top to the top margin (the faithful `\topskip` model), whereas LaTeX places the
  baseline. Imperceptible; the sigplan twin marks its Tier-2 top check report-only.
- **Math fidelity untuned** (Libertinus Math ≈ newtxmath, best-effort).
- **Continuation-page first baseline** sits 1em (the base font size) below the top
  margin instead of LaTeX's fixed `\topskip` = 10pt: ~+1pt on the 9pt-base formats,
  −1/−2pt at the 11/12pt options. Typst has no per-page margin control, and shifting
  the page margin would displace the (correct) title pages and running heads.
- **Wrapped numbered section titles** return to the left margin instead of hanging
  after "N\quad" (`\@hangfrom`): a measured hanging indent broke the tagged-PDF
  reading order (Tier 1.9), so the rare two-line numbered title keeps the simple form.
- **`booktabs` rule separation** is modelled by the opt-in **`tabular`** wrapper
  (`parts/tables.typ`) plus **`toprule`/`midrule`/`bottomrule`** helpers. A bare
  Typst `table.hline` carries a stroke with no surrounding vertical space, so a plain
  `table` renders booktabs rules flush against the cell struts; `tabular` has the same
  signature as `table` and re-adds `\aboverulesep` (`.4ex`) above each rule and
  `\belowrulesep` (`.65ex`) below it, with heavy (`.08em`) `\toprule`/`\bottomrule`
  and light (`.05em`) `\midrule` weights. Design notes:
  - It is a **plain function, not a `show table` rule** — a show rule whose body emits
    a `table` re-matches its own output (`maximum show rule depth exceeded`), so the
    wrapper sidesteps recursion entirely and needs no re-entry guard. It builds
    `std.table` internally, so it survives any shadowing of `table`.
  - Each rule's row boundary is inferred from cell order (a child `hline`'s resolved
    `y` is not exposed — reading it errors "not known at this point"): exact for the
    common grid of auto-placed 1×1 cells (colspan honoured); an explicitly positioned
    `table.cell(y: ..)` or a rowspan can misplace the separation.
  - `\aboverulesep`/`\belowrulesep` are font-relative (`ex`); Typst has no `ex` unit
    and `tabular` must not wrap its output in `context` (a context block hides the
    table from `figure()`'s kind detection, losing the "Table N" supplement), so the
    x-height is expressed as em via Libertinus Serif's ratio 0.429 (4.29pt at 10pt).
    em tracks the table font size, so the seps and rule widths scale correctly across
    formats (9pt sigconf … 12pt options) without a `tp` conversion.
  - **Row strut.** Every LaTeX table row is `\@arstrut` — height `0.7\baselineskip`,
    depth `0.3\baselineskip` (verified from `array.sty`'s `\@array` and the kernel's
    `\strutbox`; acmart leaves `\arraystretch=1`/`\extrarowheight=0`). The document's
    global `top-edge: 1em` would reserve a full em (>`0.7\baselineskip`) above the
    baseline and can't be undone by inset, so `body.typ`'s `show table` rule models the
    strut in the cell TEXT metrics instead: `top-edge: 0.7·baselineskip`,
    `bottom-edge: −0.3·baselineskip`, `leading: 0` — making a single-line row exactly
    `\baselineskip` and an n-line cell exactly n·`\baselineskip`, matching LaTeX. The
    strut is font-size dependent via `\baselineskip`, so it uses the format's
    `cfg.baselineskip` (per-format normalsize); a table the user manually wraps in a
    different size would use the normalsize `\baselineskip` — consistent with the rest
    of the document's normalsize-based rigid-leading model, and the acmart default is
    normalsize tables. Verified against LaTeX: total table height matches to within the
    rule-thickness measurement convention (Typst draws `hline` as a centered line,
    LaTeX booktabs as a `\rule` with thickness).
- **Caption first baseline** sits ~1.3pt below LaTeX's — the caption line inherits
  the global `top-edge: 1em` (9pt ascent at 9pt) rather than the font's natural
  ascender; same family as the continuation-page first-baseline item above, and left
  as-is to keep the baseline-grid model uniform (changing it would skew multi-line
  caption pitch).
- **`description`/terms: no `show` rule, on purpose.** Typst's default term-list label
  is `strong` (= `\upshape\bfseries`), which *coincides* with acmart's
  `\descriptionlabel` font, and the colon-less label matches because Typst swallows the
  colon in `/ term: body` source — so overriding the term list would only risk drift.
  What is *not* modelled is acmart's hanging `\@ACM@labelwidth` geometry (the wide,
  right-aligned label column); that remains an accepted gap.
- **Full BibLaTeX sample drift**: `sample-sigconf-biblatex` (with the software artifact
  block) reflows to one extra Typst page (dense two-column bibliography); the bundled
  samples gate visual snapshots, not page parity, and `biblatex-test` is the exact text
  gate.
- **Engine-variant / tagged samples** (3 of 18): `sigconf-lualatex` is docstrip-identical
  to `sigconf`; `acmsmall-tagged`/`sigconf-tagged` need `\DocumentMetadata{tagging=on}` +
  `lualatex-dev`, which pdflatex rejects. All render identically to their base, adding
  zero coverage.
- **No trailing indent after a display equation or verbatim block.** Unlike lists /
  figures / quotes (which emit an env-block indent shim), a paragraph *after* a
  `$ … $` block equation or a fenced code block is left un-indented. A block equation /
  verbatim is very often a mid-paragraph *continuation* — the official ACM samples set
  text right after `\end{equation}` / `\end{verbatim}` with no blank line, which LaTeX
  does **not** indent (`\@doendpe` for verbatim; a continued paragraph for the
  equation) — and Typst cannot tell that apart from a blank-line-separated new
  paragraph, which LaTeX *would* indent, because a block equation/verbatim always ends
  the Typst paragraph either way. An unconditional shim would regress the (common)
  continuation case, so the port matches it and users add an explicit `#h(parindent)`
  (as `_sample-common.typ` does) where the blank-line indent is wanted.
- **Display-math vertical skips** are approximate. The below-equation gap is measured
  from the equation's *ink* bounding box, so it leaks the descender depth of the last
  row (~2.3bp low vs LaTeX's `\belowdisplayskip` from the math axis). amsart's
  *short* display skips (`\abovedisplayshortskip` 0pt / `\belowdisplayshortskip`
  ≈2.1pt, used when the line before the display is short) are **not** modelled — every
  display uses the long `\abovedisplayskip`/`\belowdisplayskip` (≈`\medskip`).
- **Float / caption micro-gaps ≤ 3.3bp.** The `bottom-edge: 0pt` line-box model gives
  a caption strut no depth, so the figure-body↔caption and caption↔surround gaps run
  up to ~3.3bp tight. And `\textfloatsep` (the space between a top/bottom float and the
  text, 15pt) is approximated by Typst's fixed float clearance of `1.5em` — exact at a
  10pt base, but ~1.5pt tight on the 9pt formats.
- **Widow / orphan / broken penalties.** amsart sets `\widowpenalty = \clubpenalty =
  \brokenpenalty = 10000` (never a widow/orphan line, never a page break after a
  hyphen). The port sets `text(costs: (widow: 10000%, orphan: 10000%))` — Typst's cost
  is a *soft* optimizer weight, not TeX's hard penalty, and there is **no**
  `brokenpenalty` analogue. Ablation: at both 1000% and 10000% the entire twin/sample
  suite is byte-identical to Typst's 100% default (the fixtures contain no avoidable
  widows/orphans), so the strong value is a zero-regression faithfulness choice that
  only affects longer real documents; the un-modelled `\brokenpenalty` may leave a page
  break after a hyphenated line where LaTeX would forbid it.

## Test harness

LaTeX references are built by `tools/test.py`'s `latex_build`, which **reruns pdflatex
until stable** (cross-refs/`TotPages`/lastpage resolved) and fails on surviving
"Temporary page!" placeholders or LaTeX errors — a single pass leaves `TotPages`
unresolved, adding a spurious page. It also **generates `acmart.cls` from
[`acmart/`](acmart/)** into `tests/out/latex/` and prepends that to `TEXINPUTS`, so
references build against the repo's acmart, never the system tree (keeping the target and
validator on one class version — see the section-title note above).

See [CONTRIBUTING.md](CONTRIBUTING.md#validation-model) for the harness commands and
gates. `tools/test.py probe` audits the numbers in `formats/*.typ`: it compiles
[`tools/probe.tex`](tools/probe.tex) against the bundled acmart and dumps geometry,
font-size steps, baselineskips, and skips (`PROBE …`/`SIZE …` lines) — every length in a
format dict should trace to a probe line or an `acmart.dtx` macro.

**Layout numbers vs content numbers.** The text gates strip *layout* numbers before
comparing — page folios (a number line right before a page break, `_PAGE_FOLIO_LINE`)
and the review-mode line-number ruler (≥20 standalone numbers) — via
`_drop_layout_numbers` in [`pdf_text_tokens.py`](tools/pdf_text_tokens.py), shared by
the sequence, word-bag, and char-bag gates. Section numbers are **kept**: they are
content and match in both engines. (LaTeX typesets the number in its own `\@hangfrom`
box, so Poppler reads it on its own line, while Typst reads it inline with the title —
a line-break difference the order-independent bags and whitespace-collapsing sequence
gate absorb.) An earlier version dropped *every* standalone-number line, which swept
section numbers up too and forced the heading to keep an over-wide gap so its number
would land on its own extracted line; distinguishing the two removed that constraint.
