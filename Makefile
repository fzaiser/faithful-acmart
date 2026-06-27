# typst-acmart — build and validation targets.
#
#   make reference          build the LaTeX acmart reference PDF (reference/acmsmall.pdf)
#   make example            build the Typst example (template/main.pdf)
#   make diff               diff the Typst frontmatter test against the reference
#   make test               build reference + all Typst tests
#
# Builds use tools/tc, which points Typst at the bundled full Libertinus +
# Inconsolata fonts (see README "Fonts").

TC      := tools/tc
PY      := tools/venv/bin/python
SAMPLE  := acmsmall

.PHONY: reference example diff test test-references clean

reference:
	tools/build-reference.sh $(SAMPLE)

# Build the LaTeX reference PDFs for the matched test documents, each compiled to
# stability via tools/latex-build.sh (no "Temporary page" / stale TotPages).
LATEX_TESTS := tests/body-test.tex tests/head-test.tex tests/body2-test.tex \
               tests/fn-test.tex tests/full-test.tex
test-references:
	@for t in $(LATEX_TESTS); do tools/latex-build.sh $$t; done

example:
	$(TC) compile template/main.typ template/main.pdf

# Diff a Typst test PDF against the reference. Override FILE/REF/PAGES as needed:
#   make diff FILE=tests/title-test.pdf REF=reference/acmsmall.pdf PAGES=1
FILE  ?= template/main.pdf
REF   ?= reference/$(SAMPLE).pdf
PAGES ?= 1
diff: example
	$(PY) tools/pdfdiff.py $(REF) $(FILE) tests/out --dpi 150 --pages $(PAGES)

test: reference test-references
	$(TC) compile tests/body-test.typ   tests/body-test-typ.pdf
	$(TC) compile tests/head-test.typ   tests/head-test-typ.pdf
	$(TC) compile tests/title-test.typ  tests/title-test.pdf
	$(TC) compile tests/body2-test.typ  tests/body2-test-typ.pdf
	$(TC) compile tests/fn-test.typ     tests/fn-test-typ.pdf
	$(TC) compile tests/bib-test.typ    tests/bib-test-typ.pdf
	$(TC) compile tests/full-test.typ   tests/full-test-typ.pdf
	$(TC) compile template/main.typ     template/main.pdf
	@echo "All Typst tests built."

clean:
	rm -rf tests/out tests/*-typ.pdf tests/*.pdf template/*.pdf
