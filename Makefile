# typst-acmart — build and validation targets.
#
#   make probe              dump the bundled acmart's acmsmall dimensions (audit src/formats)
#   make reference          build the LaTeX acmart reference PDF (tests/out/latex/acmsmall.pdf)
#   make example            build the Typst example (tests/out/typst/main.pdf)
#   make test               build the reference + all Typst test PDFs (+ LaTeX test refs)
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

# Typst documents that have a matched LaTeX reference (.tex + .typ share a stem).
MATCHED := body-test head-test body2-test fn-test full-test

.PHONY: probe reference example test test-references diff validate clean

# Dump acmsmall's ground-truth dimensions from the BUNDLED acmart.cls (generated
# into tests/out/latex by latex-build.sh) so src/formats/acmsmall.typ can be
# audited against LaTeX. Prints PROBE/SIZE lines; no PDF is kept.
probe:
	@mkdir -p $(LATEX)
	@cp tools/probe.tex $(LATEX)/probe.tex
	@tools/latex-build.sh $(LATEX)/probe.tex $(LATEX) >/dev/null 2>&1 || true
	@grep -hE '^(PROBE|SIZE) ' $(LATEX)/probe.log

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
	@for t in $(MATCHED) title-test bib-test; do $(TC) compile tests/$$t.typ $(TYPST)/$$t.pdf; done
	$(TC) compile template/main.typ $(TYPST)/main.pdf
	@echo "All Typst tests built into $(TYPST)/."

# Diff a Typst output against its LaTeX reference. Override STEM/PAGES:
#   make diff STEM=full-test PAGES=1-2
STEM  ?= full-test
PAGES ?= 1
diff:
	@mkdir -p $(DIFF)
	$(PY) tools/pdfdiff.py $(LATEX)/$(STEM).pdf $(TYPST)/$(STEM).pdf $(DIFF) --dpi 150 --pages $(PAGES)

clean:
	rm -rf tests/out
