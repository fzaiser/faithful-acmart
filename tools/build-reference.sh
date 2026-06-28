#!/bin/sh
# Build the LaTeX acmart reference artifacts into tests/out/latex/ (gitignored).
#
# Generates acmart.cls from the upstream sources in acmart/, extracts the sample
# .tex files, and compiles a chosen sample to a reference PDF that the Typst
# output is diffed against. Requires a TeX Live install (pdflatex, bibtex).
#
# Usage: tools/build-reference.sh [sample-name]   # e.g. acmsmall (default), sigconf, ...
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/acmart"
OUT="$ROOT/tests/out/latex"
SAMPLE="${1:-acmsmall}"

mkdir -p "$OUT"
cd "$OUT"

# docstrip generation tolerates pdflatex's non-zero exit; the actual document is
# compiled to stability by tools/latex-build.sh (resolves TotPages / temp pages).
gen() { pdflatex -interaction=nonstopmode "$1" >/dev/null 2>&1 || true; }

# acmart.cls is generated from the bundled acmart/ sources by tools/latex-build.sh
# (step 3), which guarantees every LaTeX build uses the repo's version, not the
# system one.

# Extract the sample .tex sources and copy supporting files.
if [ ! -f "$SAMPLE.tex" ]; then
  cp "$SRC/samples/samples.ins" "$SRC/samples/samples.dtx" .
  cp "$SRC/samples/"*.bib "$SRC/ACM-Reference-Format.bst" "$SRC/samples/"*.png . 2>/dev/null || true
  gen samples.ins
fi

# Compile the chosen sample to a stable PDF (no temp page, resolved TotPages).
# latex-build.sh generates the bundled acmart.cls into $OUT before compiling.
"$ROOT/tools/latex-build.sh" "$OUT/$SAMPLE.tex" "$OUT"
