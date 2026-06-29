# CLAUDE.md — guidance for AI assistants working in this repo

A Typst port of the LaTeX **acmart** class. Goal: idiomatic Typst that renders as
close as possible to LaTeX + acmart. **All 11 formats** are implemented
(single-column journals manuscript/acmsmall/acmlarge, two-column journal acmtog,
two-column proceedings sigconf/siggraph/sigplan/sigchi/acmengage, best-effort
sigchi-a/acmcp); each is a data dict in [`src/formats/`](src/formats/) built by
`make-format()` in `_base.typ`. The upstream spec being matched is in
[`acmart/`](acmart/) (`acmart.dtx`); read it when matching behaviour.

Full detail: [DESIGN.md](DESIGN.md) (architecture + Typst-vs-LaTeX modeling) and
the per-directory READMEs ([`src/`](src/README.md), [`tools/`](tools/README.md),
[`tests/`](tests/README.md), [`fonts/`](fonts/README.md)). This file is the
short version that must not be missed.

## Operating rules

- **Build with `tools/tc`, never plain `typst`.** `tc` points Typst at the
  bundled full Libertinus + Inconsolata OTFs (`--font-path fonts
  --ignore-system-fonts`). System Libertinus is often feature-stripped (no small
  caps/ligatures/kerning) and silently degrades output.
- **Validate against real LaTeX.** `make reference` (LaTeX), `make test` (all
  Typst + LaTeX refs), `make validate` (copyright modes + options), then
  `make diff STEM=<name> PAGES=<n>`. Output goes to `tests/out/{latex,typst,diff}`
  (gitignored). LaTeX must be built via `tools/latex-build.sh` (reruns to
  stability; a single pdflatex pass leaves acmart's `TotPages` unresolved and
  adds a spurious "Temporary page").
- **Tests are matched pairs:** `tests/NAME.tex` (LaTeX) vs `tests/NAME.typ`
  (ours), identical content, diffed page-by-page.
- **Keep it idiomatic.** When touching code, apply the simplification checklist in
  [`src/README.md`](src/README.md) ("Idioms / simplifications") — resolve defaults
  in the signature, don't guard/`str()` bare values rendered into content (`none`
  is empty content), assemble content rather than concatenating strings, and
  centralize optional-field access. The golden gate must stay byte-identical.

## Gotchas — easy to get wrong, verified against LaTeX (don't re-break)

- **TeX pt ≠ Typst pt.** LaTeX uses 1/72.27in, Typst 1/72in. `formats/acmsmall.typ`
  defines `tp = 72/72.27*1pt`; express probed lengths as `N * tp`.
- **Leading/baseline:** `set text(top-edge: 1em, bottom-edge: 0pt)` +
  `leading = baselineskip - font-size` reproduces TeX's rigid `\baselineskip`.
  Block gaps that should be "`\baselineskip + skip`" must be set to
  `skip + (baselineskip - font-size)`. This conversion is centralized as
  `comp()`/`tex-skip()` in `src/parts/spacing.typ` — route new leadings/gaps
  through them rather than re-deriving (Typst's line box is 1em, not baselineskip).
- **amsart skips are 2.1/4.2/8.4pt, NOT 3/6/12.** acmsmall loads `amsart`, which
  scales `\small/\med/\bigskip` to 0.7× the article defaults. Float spacing
  (`\intextsep`/`\abovecaptionskip` = 12pt) is a *separate* constant. `make probe`
  re-dumps these from the bundled class — don't hardcode the article values.
- **Section titles are MIXED CASE**, not uppercased (author *names* are uppercased
  — different thing). pdftotext is misleading here; check rendered pixels.
- **Flushbottom-like fill is unreplicable.** acmsmall does NOT call `\flushbottom`
  (only acmtog/sigconf… do); the fill comes from acmart setting `\@textbottom` to
  `\vskip 0pt \@plus 1pt` (`acmart.dtx:3936`), so *full* pages stretch the rubber
  section glue to the bottom margin. Typst has no equivalent, so our pages are
  ragged-bottom. Section spacing is otherwise exact (proven vs LaTeX
  `\raggedbottom`). Gradual drift on full multi-page documents is THIS, not a
  spacing bug — do not "fix" spacing to chase it.

## Not done yet

All 11 formats are implemented, but with accepted approximations: two-column
vertical fill (`\flushbottom`) and last-column balancing are unreplicable in
Typst (ragged-bottom columns); `sigchi-a` omits margin-note footnotes
(`\marginpar`); `acmcp` reproduces the tinted cover frame but not the JDS-logo
infobox (the logo is a bundled asset we don't ship). Also outstanding: math-font
fidelity. Top-matter commands `\titlenote`/`\subtitlenote`, `\received`, the
`acks` environment, teaser figures, author badges, and the conference metadata
(`conference`/`booktitle`/`isbn`) ARE modelled. See DESIGN.md "Deliberate
approximations" / "Known limitations" for the full list.
Author *line grouping* now follows acmart's exact structural rule (an
affiliation-less author andifies onto the next; affiliations are never compared —
`group-authors`); the remaining author-side approximation is contact-info *field
order* (we emit affiliation-then-email, not source-declaration order).

## Git workflow

**Work on `main` directly — do NOT create feature branches in this repo.** Commit
straight to `main` (this overrides the usual "branch off the default branch first"
default). **Commit proactively** after each significant, logically coherent chunk
of work, with a descriptive message — don't wait to be asked. Only `push` when
asked.
