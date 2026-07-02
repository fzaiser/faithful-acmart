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

**Bibliography — three backends (`bib-backend`):**
- **`"typst"` — idiomatic, an approximation.** Native `bibliography()` with Typst's
  built-in ACM CSL style (`association-for-computing-machinery`). Native `@key`
  citations work and — unlike the engine backends — keep Typst's in-text citation
  hyperlinks. It is *not* faithful: it is bounded both by the built-in style's own
  choices (full month names, `https://doi.org/<id>` DOIs, `Doctoral dissertation`
  wording, no report genre label) and by hayagriva's BibTeX→CSL *data-mapping* limits
  (dropped `lastaccessed` dates, `@periodical` journal names, thesis `school`/advisor,
  conference `address`). For `.bst`-exact output use the default `"bibtex"` backend.
  (A vendored CSL fork used to narrow the style-choice gap but was retired — see `git`
  history — so the package ships pure-MIT and the `"typst"` backend is a plain,
  standard CSL.)
- **`"bibtex"` (default) — exact, no extra dependencies.** A pure-Typst port of
  `ACM-Reference-Format.bst`: [`parts/bibtex.typ`](src/parts/bibtex.typ) parses the
  `.bib` (via `read()`), [`parts/acmref.typ`](src/parts/acmref.typ) reimplements the
  `.bst`'s output state machine + `format.*` helpers + every entry-type handler +
  the sort/cite layer (native `state`/`query`), and [`parts/bib-data.typ`](src/parts/bib-data.typ)
  carries the `.bst`'s built-in journal MACRO table + `journal.canon.abbrev`
  (auto-extracted, so `journal = csur` → "Comput. Surveys" like bibtex). DOI / URL /
  arXiv-eprint / `\url`-in-note render as **real Typst hyperlinks** (acmart loads
  hyperref); in-text *citations* on this backend are anchored to the reference list too
  — each entry carries an `entry-label(key)` and the cite numbers / author-year groups
  `link` to it (ACMPurple in screen mode, matching acmart's `citecolor`; uncoloured in
  print). Reached via native `@key` (a `show ref:` rule routes it to the engine,
  gated to this backend — see "Implemented" below) and the shadowed `cite` /
  `bibliography` functions (`#cite(<a>, <b>)` grouped, `#bibliography("/refs.bib")`),
  plus `cite-text` (`\citet`) / `cite-year` / `cite-author`. It reproduces
  the `.bst`'s reference text *exactly*: the
  `bib-all` (20 entry-type handlers), `bib-edge` (field/path edge cases),
  `crossref` (crossref + org→key + distinctURL), `authoryear` (author-year mode),
  `mathfields` (inline math) and `keycite` (native `@key` routing)
  twins gate the full char bag against real bibtex with **no exemption**, plus a
  `link_check` gate on the `/URI` set and word-level assertions for what the
  whitespace-free char bag can't see. The von/Last/Jr name split tokenizes on **raw
  TeX** and follows BibTeX's `format.name$` exactly (`von_name_ends` +
  `von_token_found` from `bibtex.web`): a token's case is its first *brace-level-0*
  letter (or a `{\..}` foreign letter), so `{de la}` and `{Barnes & Co.}` are Last,
  not von; the von part may include leading uppercase tokens (`De la`); and a bare
  `\ss` doesn't split its token (`Stra\ss e` → Last). Verified field-by-field
  against the real bibtex binary (oracle cases pinned in `tests/unit/bibtex.typ`).
- **`"biblatex"` — ACM BibLaTeX, no extra dependencies.** A sibling renderer in
  [`parts/acmref.typ`](src/parts/acmref.typ) ports the visible reference formatting
  of ACM's `acmnumeric.bbx`, the `acmauthoryear.bbx` deltas, and the
  `biblatex-software` files they load (`software.bbx`, `software.dbx`,
  `english-software.lbx`) while reusing the same `.bib` reader, sort/cite state,
  native `@key` / `#bibliography` routing, and `cite-style: "numeric" |
  "author-year"` switch as the `bibtex` backend. This covers BibLaTeX's
  sentence-cased numeric titles, preserved/quoted author-year titles, full journal
  names, `doi: <id>` punctuation, `lastaccessed` retrieval dates, BibLaTeX
  `In:`/booktitle italics, journal italics, software-family data inheritance,
  SWHID source-map normalization, ACM's software labels (`[SW]`, `[SW Rel.]`,
  `[SW Mod.]`, `[SW exc.]`), and HAL/URL/VCS/SWHID identifier blocks. The
  `biblatex-test` twin gates the acmnumeric isolator against biber with no
  char/font/order exemption; the full BibLaTeX samples exercise the software
  artifact cite block against the upstream references.

  **Implemented (each validated against real bibtex):**
  - **Author-year citation mode** — `cite-style: "author-year"` (acmart's
    `\citestyle{acmauthoryear}`). Short `format.lab.names` labels (von+Last only,
    `" and "` for two, `"et al."` for >2), the `\natexlab` `a`/`b`/`c`
    year-disambiguation suffix assigned over `(label, year)`-equal entries in sort
    order (the `forward.pass`/`reverse.pass` algorithm), a reference list with **no
    leading numbers**, and the natbib `\citep`/`\citet` renderers with same-author
    year compression (`[Smith and Doe 2020a,b]`). Grouped `cite` (= `\citep`),
    `cite-text` (= `\citet`), plus `cite-year`/`cite-author`.
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
  - **Native `@key` / `#cite` / `#bibliography` routing.** The flow is idiomatic
    Typst for every backend — `@Cohen07`, grouped `#cite(<a>, <b>)`,
    `#bibliography("/refs.bib")` — via two complementary mechanisms in `lib.typ`:
    - `@key` is Typst *syntax* (a `ref` element, unshadowable), so a document-level
      `show ref:` rule (gated `bib-backend != "typst"`) routes it to the engine — the
      same show-rule hook `alexandria` / `pergamon` use. A `ref` whose target resolves
      to no document label (`it.element == none`) is a citation; real elements
      (figures/headings/equations) pass through. Numbering reuses the `state` pass the
      cite layer already runs.
    - `cite` and `bibliography` are *function* names, so they are **shadowed**
      (`#let cite` / `#let bibliography`). `cite` groups multiple keys into one bracket
      (the per-element show rule can't merge adjacent citations); `bibliography` renders
      the list through the engine. This is required for `bibliography` in particular:
      Typst validates a native `#bibliography` source through hayagriva *at element
      construction* — before any show rule could fire — so a `.bst`-only feature such
      as a journal-abbreviation string macro (`journal = csur`) would error out; the
      shadow never constructs a native element, bypassing hayagriva entirely. These
      engines `read()` the `.bib` deep inside the package and *lazily* (during cite
      resolution, from `state`). Typst resolves a `read()` path against wherever the
      path value was *written*, and that origin survives only on an `arguments` value
      that is never indexed into. So the shadow **threads a single positional path as
      an un-indexed `arguments` value** all the way to the engine's `read(..args)` —
      and a **relative path keeps the caller's location** on every backend. (`title` is
      an explicit named parameter of the shadow, so it is peeled off `..args`
      automatically and a relative path still works alongside it.) The moment the
      shadow must index — *several* files or an array — the origin is lost, so those
      require a **project-absolute** path (`"/refs.bib"`) and the shadow asserts it with
      a clear message. (`read-merged` branches on `type(paths) == arguments` for the
      threaded case vs the extracted string/array case.)

    For the `"typst"` backend the `show ref:` rule is the identity and both shadows
    delegate to the native `std.cite` / `std.bibliography` (the built-in ACM CSL
    `set bibliography(style: …)` in `body.typ` then styles the list), so native syntax
    keeps Typst's built-in behaviour. `bibliography` forwards the caller's `arguments`
    value verbatim (`std.bibliography(..args)`), so relative paths work there too (and
    for multiple files, since Typst's own reader takes the whole args). The textual
    helpers `cite-text`/`cite-year`/
    `cite-author` likewise map to `std.cite(form: "prose"/"year"/"author")` there.
  - **TeX-string handling follows BibTeX literally** (`src/parts/tex.typ`). BibTeX
    never normalizes to Unicode — it carries the **raw** TeX string through its whole
    pipeline and only applies two string→string built-ins: `purify$` (sort keys) and
    `change.case$` (display case), both math-blind and brace/special-character aware.
    We port both *exactly* — quoting `bibtex.web` (`x_purify`, `x_change_case`, the
    13-entry `control_seq_ilk` foreign-letter table) and oracle-testing against the
    real bibtex binary in `tests/unit/tex.typ`. Field values therefore stay raw TeX
    until the **render seam**, which is one **mode-independent tokenizer** feeding
    mode-aware **evaluators** (`tex.typ`): the raw string is lexed *once* into a token
    tree (text runs, control words/symbols, `{groups}`, `$math$`, the catcode-special
    `~ ^ _`), then evaluated to content (`tex-to-content`), to a plain string for
    sort/cite labels (`tex-to-string`, never overridable — it would corrupt ordering),
    or, for a `$…$` body, to a Typst-math source string that is `eval`'d. This replaced
    the old multi-pass `decode` + regex chain (which was order-dependent and brittle).
    Name-part tokens are tie-joined the way BibTeX's `format.name$` does (a `~` before
    the last token / after a single letter), so e.g. `Stra\ss e` renders `Straß e` like
    LaTeX (the tie blocks the control-word space-swallowing).
  - **Inline math (`$…$`) is real Typst math.** The math evaluator translates LaTeX
    math to Typst math — symbols (`\alpha`→`alpha`, `\leq`→`<=`, `\oplus`→`plus.o`),
    one-/two-arg functions (`\frac{a}{b}`→`frac(a,b)`, `\mathbb{R}`→`bb(R)`, `\sqrt`),
    and LaTeX `^{..}`/`_{..}` grouping → Typst `^(..)`/`_(..)` — then `eval`s it inside
    `$…$`. Real Typst math extracts to the same char-bag text as LaTeX's math-italic
    output (`𝜆`, super/subscripts as plain digits, `ℝ`→`R` under NFKC), so the
    `mathfields` twin — which exercises greek, super/subscripts, `\frac`, `\oplus` and
    grouping — gates with **no exemption**.
  - **Formatting commands** map to their Typst equivalents: `\emph`/`\textit`→`emph`,
    `\textbf`→`strong`, `\textsc`→`smallcaps`, `\texttt`→`raw`, `\underline`,
    `\textsuperscript`/`\textsubscript`; `\url`/`\href`→links; accents and the foreign
    letters (`\ss` etc.)→Unicode; `\LaTeX`/`\TeX`→logos.
  - **Unknown commands raise an error**, never pass through silently — the message
    names the command and tells the user to handle it in a `tex-render` callback. The
    **`tex-render` option** is that single override: a callback `(raw-tex: str) =>
    content` (default `auto` = `tex-to-content`), composed with the default — exported
    as `default-tex-render` — e.g. `tex-render: s => default-tex-render(s.replace(
    "\\myunit", "kg"))`, covering the `\newcommand` case without a TeX engine. (This
    replaced the old string→string `tex-macros` dict, which couldn't take arguments or
    produce real content.) A small allowlist of genuine no-ops (`\noopsort`, `\relax`,
    `\protect`, …) is recognized so benign BibTeX idioms don't error.

  **Not ported** (genuinely out of reach, or faithful to omit — the exhaustive list):
  - **ISBN / ISBN-13 / ISSN / CODEN / LCCN.** Emitted by the `.bst` but suppressed by
    acmart (`\showISBNx` etc. left **undefined in every format** → the `.bbl`'s
    `\unskip` fallback eats them), so omitting them is *faithful to stock acmart*. A
    user who redefines `\showISBNx` to surface them can't via this backend; the
    `show-isbn-10-and-13` branch is unimplemented because no acmart format reaches it.
  - **Arbitrary / full-equation TeX** beyond the supported command tables and the
    `tex-render` override — *unbounded by nature*. A field can contain any TeX
    (multi-line display math, macros that expand to layout, `\newcommand`s pulled from
    the preamble); interpreting all of it would mean embedding a TeX engine. We support
    the finite set references use and **raise an error on anything unknown** (rather
    than emitting garbage), pointing the user at a `tex-render` callback to patch it.

  **`tex-render` accepted approximations** (correct for the common case; edges noted
  so they're not mistaken for bugs):
  - **The math-symbol table is curated and only spot-verified.** `mathfields`
    oracle-tests greek + `\leq \frac \oplus \mathbb \log`; the remaining ~110 symbol/
    function entries are valid Typst identifiers (they compile) but are *not* each
    diffed against LaTeX, so a wrong-but-valid mapping would render the wrong glyph
    silently. Greek and the tested set are trusted; the long tail is best-effort.
  - **`/` inside `$…$` becomes a Typst fraction**, not a literal slash — Typst math
    reads `/` as division layout (LaTeX `$a/b$` is just a slash). Rare in references;
    unhandled.
  - **`\left`/`\right` are dropped, so delimiters don't auto-size** around tall content
    (Typst needs `lr(...)`); the bare delimiter still prints.
  - **Accents render as decomposed combining sequences** (`o`+◌̈), not precomposed
    (ö). They shape and NFKC-fold identically (golden + char bag agree), so this is
    invisible — we just don't NFC-normalize.
  - **`edition` is lowercased with `lower()`**, not the brace-aware `change.case$ "l"`
    (fine for `"Second"`, would differ for a braced edition).
  - **`tie-join`'s tie placement for multi-token *first* names with initials** (`J.`)
    may not match BibTeX exactly — but inter-token spacing is whitespace, which the
    char-bag gate drops, so it's untestable against the oracle and visually negligible.
  - **`url`/`doi`/`eprint` fields bypass the render seam** — `acmref.typ` links them
    with the raw string, so TeX inside a URL is not decoded (URLs rarely contain TeX).
  - **`tex-to-string` (sort/cite labels) errors on inline math** — labels are names/
    orgs/keys, which never carry `$…$`; sort keys themselves go through `purify`.
  - **Recursion vs Typst's ~72 call-depth limit.** The evaluator walks a field's
    token list in a *loop*, so field *length* is unbounded; only structural descent
    (group/argument/math nesting) recurses. So a field could only overflow with ~70+
    levels of *nested* braces/math — absurd for a reference (the deep stress cases in
    `tests/unit/tex.typ` confirm long flat fields are fine).
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
- **`sigchi-a`**: geometry, sans default, the `@mktitle@iv` title (5pc-leftskip
  ragged title under a 2pt rule, acmart.dtx:7039), the `@mkauthors@iv` author grid
  (bold mixed-case name + email + affiliation, 2 per row, left-aligned —
  acmart.dtx:7518), the one-sided running head (shorttitle + dated conference), the
  unnumbered sections and the "Legacy document" watermark (breaking before "ACM
  venue") are all reproduced — the page-1 top matter and the running head match
  LaTeX's extracted text exactly (char *and* word bags). The remaining approximation:
  footnotes are **not** moved into the margin (`\marginpar`, acmart.dtx:3533).
- **`acmcp`**: geometry, unnumbered sections, the suppressed ACM reference format,
  the rotated article-type label at the page's left edge, the light-tinted cover
  **frame** (`@ACM@Article@color!10!white`, default ACMBlue — acmart.dtx:5899)
  scoped to the **body only** (the title/authors/abstract stay on white) and
  narrowed 6.5pc on the right (acmart.dtx:5902), and the right-margin cover
  **infobox** — the bundled JDS logo (`src/assets/acm-jdslogo.png`, from acmart's
  `acm-jdslogo.png`) over the optional `code-data-link` / `keywords` /
  `contributions` / author contact information — are reproduced; the title alone is
  narrowed by 6pc to clear the box (acmart.dtx:6988). The one approximation is the
  infobox's vertical position: acmart uses a two-pass `zref` measurement
  (acmart.dtx:6733) to butt its bottom against the frame bottom on short documents;
  we can't run that cross-run feedback in a single Typst pass, so we nudge it down a
  fixed ~3 baselineskips from the body top (near LaTeX for a short cover, but it
  doesn't track the body length — see TODO.md). The code/data link shows the full URL (`\url`,
  char-exact); being wider than the 5pc box it wraps where LaTeX overflows, so only
  that one word-bag token splits. Normal contact/copyright footnotes and normal
  keyword top matter are suppressed for `acmcp`, as in LaTeX.
- **Conference Huge title vertical position** differs from LaTeX by ~4–5pt of
  glyph-bbox overshoot: we pin the title cap-top to the top margin (the faithful
  `\topskip` model, as for acmsmall), whereas LaTeX places the baseline and lets
  the cap-top fall where the font's cap height puts it. Imperceptible; the sigplan
  twin marks its Tier-2 top check report-only for this reason.
- Math fidelity untuned (Libertinus Math ≈ newtxmath, best-effort).
- **Full BibLaTeX sample layout drift**: `sample-sigconf-biblatex` uses the
  `"biblatex"` backend and includes the software artifact block, but the dense
  two-column bibliography reflows to one extra Typst page. The full bundled
  samples already gate visual snapshots rather than page parity; the isolated
  `biblatex-test` remains the exact text gate for regular BibLaTeX formatting.
- **Engine-variant and accessibility-tagged samples** (three of the 18 bundled
  acmart samples) are not ported as upstream-ref tests: `sigconf-lualatex` is
  docstrip-identical to `sigconf` (same flags, just a different engine note in the
  comment header); `acmsmall-tagged` and `sigconf-tagged` require
  `\DocumentMetadata{tagging=on}` + `lualatex-dev`, which pdflatex (our reference
  builder) rejects with an unknown-key error. All three render identically to their
  base format, so they add zero Typst coverage.

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

See the [README](README.md#development). The harness is one Python
program, `tools/test.py`, driven by the matrix in `tools/test_matrix.py`. The
main loop is `tools/test.py check`: it builds the LaTeX references, compiles every
Typst test once, then runs the gates (warning/page-count smoke checks, Typst
raster goldens, extracted-text equality/semantic assertions, expected compile
errors, and cross-engine layout metrics). `tools/test.py validate` separately
builds copyright and option variants and reports page-1 mismatch percentages.
Fonts come from the bundled OTFs via `tools/tc` (see the README "Fonts" section).

Building the example (`tools/test.py example`) or running `typst init
@preview/faithful-acmart:0.1.0` locally needs the package linked into the Typst data
dir — the matched twins import `/src/lib.typ` directly, so `check` does not:

```sh
ln -sfn "$PWD" "$HOME/Library/Application Support/typst/packages/preview/faithful-acmart/0.1.0"
```

To audit the *numbers* in `src/formats/acmsmall.typ` against the class itself, run
**`tools/test.py probe`**: it compiles [`tools/probe.tex`](tools/probe.tex)
against the bundled acmart and dumps the geometry, font-size steps, baselineskips,
and skips (`PROBE …`/`SIZE …` lines). Every length in the format dict should trace
back to a probe line or a macro in `acmart/acmart.dtx` — prefer that over
eyeballing pixels.
