# typst-acmart — build and validation targets.
#
#   make probe              dump the bundled acmart's acmsmall dimensions (audit src/formats)
#   make reference          build the LaTeX acmart reference PDF (tests/out/latex/acmsmall.pdf)
#   make example            build the Typst example (tests/out/typst/main.pdf)
#   make test               build the reference + all Typst test PDFs (+ LaTeX test refs)
#   make check              run the regression gates (Tier 0 smoke / 1 golden / 2 metrics)
#   make accept             rebuild Typst PDFs and refresh the Tier 1 golden hashes
#   make diff               diff a Typst output against its LaTeX reference
#   make clean              remove all generated output (tests/out/)
#
# All output lives under tests/out/ (gitignored):
#   tests/out/latex/  LaTeX builds (acmart.cls, samples, reference PDFs)
#   tests/out/typst/  Typst output PDFs
#   tests/out/diff/   visual-diff images
#
# Builds use tools/tc, which points Typst at the bundled full Libertinus +
# Inconsolata fonts (see README "Fonts").

TC     := tools/tc
PY     := tools/venv/bin/python
SAMPLE := acmsmall
LATEX  := tests/out/latex
TYPST  := tests/out/typst
DIFF   := tests/out/diff

# Matched twins: NAME.tex (real LaTeX) + NAME.typ (ours) share a stem and are
# diffed/compared page-by-page.
MATCHED := body-test head-test body2-test fn-test full-test title-test bib-test notes-test options-test authorversion-test language-test language-de-test language-es-test fontsize-8-test fontsize-9-test fontsize-11-test fontsize-12-test manuscript-test acmlarge-test sigconf-test
# End-to-end ports: full Typst documents with NO hand-written twin — compared
# against the upstream sample reference built by `make reference` (see the
# stem->reference map in the diff target and reference= in tests/manifest.toml).
E2E := sample-acmsmall
# Smoke-only Typst docs: no LaTeX twin (synthetic assets), compiled + golden-hashed
# but not geometry-compared. Exercise feature paths the matched tests do not.
SMOKE := feature-test draft-test urlbreak-test

.PHONY: probe reference example test test-references check accept diff validate clean

# Dump a format's ground-truth dimensions from the BUNDLED acmart.cls (generated
# into tests/out/latex by latex-build.sh) so src/formats/<fmt>.typ can be audited
# against LaTeX. Prints PROBE/SIZE lines; no PDF is kept. Override the format:
#   make probe FORMAT=sigconf
FORMAT ?= acmsmall
probe:
	@mkdir -p $(LATEX)
	@sed 's/format=acmsmall/format=$(FORMAT)/' tools/probe.tex > $(LATEX)/probe-$(FORMAT).tex
	@tools/latex-build.sh $(LATEX)/probe-$(FORMAT).tex $(LATEX) >/dev/null 2>&1 || true
	@grep -hE '^(PROBE|SIZE) ' $(LATEX)/probe-$(FORMAT).log

# Validate copyright modes + document options (review/screen/anonymous) against
# matched LaTeX references, the same standard as the default path.
validate: reference
	$(PY) tools/validate-variants.py

reference:
	tools/build-reference.sh $(SAMPLE)

# Compile each matched LaTeX test document to a stable PDF in tests/out/latex/.
test-references:
	@for t in $(MATCHED); do tools/latex-build.sh tests/$$t.tex; done

example:
	@mkdir -p $(TYPST)
	$(TC) compile template/main.typ $(TYPST)/main.pdf

test: reference test-references
	@mkdir -p $(TYPST)
	@for t in $(MATCHED) $(E2E) $(SMOKE); do $(TC) compile tests/$$t.typ $(TYPST)/$$t.pdf; done
	$(TC) compile template/main.typ $(TYPST)/main.pdf
	@echo "All Typst tests built into $(TYPST)/."

# Regression gates (no manual inspection). Tier 0 compiles + checks warnings and
# page counts; Tier 1 compares Typst renders to committed golden hashes; Tier 2
# compares cross-engine layout geometry against tests/manifest.toml tolerances.
check: test
	$(PY) tools/check_smoke.py
	$(PY) tools/check_golden.py
	$(PY) tools/metrics.py

# Refresh the Tier 1 golden hashes after an intended output change (or a Typst
# version bump). Review `make check` / `make diff` first — this blesses whatever
# the current Typst output is.
accept:
	@mkdir -p $(TYPST)
	@for t in $(MATCHED) $(E2E) $(SMOKE); do $(TC) compile tests/$$t.typ $(TYPST)/$$t.pdf; done
	$(PY) tools/check_golden.py --accept

# Diff a Typst output against its LaTeX reference. Override STEM/PAGES:
#   make diff STEM=full-test PAGES=1-2
# E2E ports have no same-stem reference, so map them to their upstream PDF.
STEM  ?= full-test
PAGES ?= 1
REF   ?= $(patsubst sample-acmsmall,acmsmall,$(STEM))
diff:
	@mkdir -p $(DIFF)
	$(PY) tools/pdfdiff.py $(LATEX)/$(REF).pdf $(TYPST)/$(STEM).pdf $(DIFF) --dpi 150 --pages $(PAGES)

clean:
	rm -rf tests/out
