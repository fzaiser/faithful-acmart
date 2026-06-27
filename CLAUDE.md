# CLAUDE.md — guidance for AI assistants working in this repo

A Typst port of the LaTeX **acmart** class. Goal: idiomatic Typst that renders as
close as possible to LaTeX + acmart. Only the **`acmsmall`** format is
implemented so far. The upstream spec being matched is in [`acmart/`](acmart/)
(`acmart.dtx`); read it when matching behaviour.

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

## Gotchas — easy to get wrong, verified against LaTeX (don't re-break)

- **TeX pt ≠ Typst pt.** LaTeX uses 1/72.27in, Typst 1/72in. `formats/acmsmall.typ`
  defines `tp = 72/72.27*1pt`; express probed lengths as `N * tp`.
- **Leading/baseline:** `set text(top-edge: 1em, bottom-edge: 0pt)` +
  `leading = baselineskip - font-size` reproduces TeX's rigid `\baselineskip`.
  Block gaps that should be "`\baselineskip + skip`" must be set to
  `skip + (baselineskip - font-size)` (Typst's line box is 1em, not baselineskip).
- **Section titles are MIXED CASE**, not uppercased (author *names* are uppercased
  — different thing). pdftotext is misleading here; check rendered pixels.
- **`\flushbottom` is unreplicable.** acmsmall vertically justifies *full* pages;
  Typst has no equivalent, so our pages are ragged-bottom. Section spacing is
  otherwise exact (proven vs LaTeX `\raggedbottom`). Gradual drift on full
  multi-page documents is THIS, not a spacing bug — do not "fix" spacing to chase
  it.

## Not done yet

Other formats (sigconf/sigplan/… — need two-column), math-font fidelity, the
separate single-column `manuscript` format.

## Conventions

Branch off the default branch before committing; commit/push only when asked.
