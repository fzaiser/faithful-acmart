# CLAUDE.md — guidance for AI assistants working in this repo

A Typst port of the LaTeX **acmart** class. Goal: idiomatic Typst that renders as
close as possible to LaTeX + acmart. The upstream spec being matched is in
[`acmart/`](acmart/) (`acmart.dtx`); read it when matching behaviour.

Full detail: [DESIGN.md](DESIGN.md) (architecture + Typst-vs-LaTeX modeling), the
[root README](README.md) (build/validation harness), and [`src/`](src/README.md)
/ [`fonts/`](fonts/README.md). This file is the short version that must not be
missed.

## Operating rules

- **Build with `tools/tc`, never plain `typst`.** `tc` points Typst at the
  bundled full Libertinus + Inconsolata OTFs (`--font-path fonts
  --ignore-system-fonts`). System Libertinus is often feature-stripped (no small
  caps/ligatures/kerning) and silently degrades output.
- **Validate against real LaTeX.** The harness is `tools/test.py` (run via
  `tools/venv/bin/python`; `--help` lists the commands, `check --help` the
  gates), driven by the matrix in `tools/test_matrix.py`. Output goes to
  `tests/out/` (gitignored). The harness builds LaTeX against the `acmart.cls`
  generated from the bundled `acmart/` (never the system install) and reruns
  pdflatex to stability — a single pass leaves acmart's `TotPages` unresolved
  and adds a spurious "Temporary page".
- **Tests are matched pairs:** `tests/twins/NAME.tex` (LaTeX) vs
  `tests/twins/NAME.typ` (ours), identical content, diffed page-by-page.
  Register new tests in `tools/test_matrix.py`.
- **Make twins match at the source, not in the comparison.** When a twin's LaTeX
  and Typst output differ, prefer making the two *actually* agree — fix the
  fixture (e.g. a titleless body-only `.tex` re-asserts `\thispagestyle{empty}`,
  which acmart otherwise overrides at `\begin{document}`) or fix the port — over
  adding normalization to the gate. Normalization compensation compounds (each
  strip hides info and spawns the next: the folio-strip created a section-number
  asymmetry that a digit-strip then masked) and silently hides real bugs. The text
  gates are layered — sequence (`text_equal=True`) → word bag (`"bag"`) → an exact
  char bag on *every* twin — and the char bag is deliberately minimal (NFKC + drop
  dashes + fold quote/star + drop whitespace; numbers/dashes delegated to the word
  bag, folios to the fixtures). Whatever difference survives a gate is real: fix
  it, or document it with a validated `expected_*` entry on `Test` (its
  docstring in `test_matrix.py` lists each field and the cause types) — don't
  expand the normalization. Avoid adding new bare skip booleans.
  When asked *why* a normalization step is needed,
  verify the mechanism (ablate it; read both `test.py text` dumps) before answering —
  in this codebase the plausible explanation was wrong more than once.
- **Keep it idiomatic.** When touching code, apply the simplification checklist in
  [`src/README.md`](src/README.md) ("Idioms / simplifications"). The golden gate
  must stay byte-identical.

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
  (`\intextsep`/`\abovecaptionskip` = 12pt) is a *separate* constant.
  `test.py probe` re-dumps these from the bundled class — don't hardcode the
  article values.
- **Section titles are MIXED CASE**, not uppercased (author *names* are uppercased
  — different thing). Extracted text is misleading here; check rendered pixels.
- **Flushbottom-like fill is unreplicable.** acmsmall does NOT call `\flushbottom`
  (only acmtog/sigconf… do); the fill comes from acmart setting `\@textbottom` to
  `\vskip 0pt \@plus 1pt` (`acmart.dtx:3936`), so *full* pages stretch the rubber
  section glue to the bottom margin. Typst has no equivalent, so our pages are
  ragged-bottom. Section spacing is otherwise exact (proven vs LaTeX
  `\raggedbottom`). Gradual drift on full multi-page documents is THIS, not a
  spacing bug — do not "fix" spacing to chase it.

## Not done yet

Accepted approximations and open gaps (ragged-bottom pages, `sigchi-a` margin
footnotes, math-font fidelity, `\@hangfrom`, `quotation`/`description` geometry,
…) are catalogued in DESIGN.md "Known limitations / not done" — read it before
"fixing" one of them, and record new ones there. The modelled-feature inventory
is the code plus the README, not this file. One don't-re-break: booktabs
`tabular` is a wrapper function, NOT a `show table` rule (that recurses).

## Git workflow

**Work on `main` directly — do NOT create feature branches in this repo.** Commit
straight to `main` (this overrides the usual "branch off the default branch first"
default). **Commit proactively** after each significant, logically coherent chunk
of work, with a descriptive message — don't wait to be asked. Only `push` when
asked.
