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

# 1. Generate acmart.cls from the .ins/.dtx (idempotent).
if [ ! -f acmart.cls ] || [ "$SRC/acmart.dtx" -nt acmart.cls ]; then
  cp "$SRC/acmart.ins" "$SRC/acmart.dtx" .
  gen acmart.ins
fi

# 2. Extract the sample .tex sources and copy supporting files.
if [ ! -f "$SAMPLE.tex" ]; then
  cp "$SRC/samples/samples.ins" "$SRC/samples/samples.dtx" .
  cp "$SRC/samples/"*.bib "$SRC/ACM-Reference-Format.bst" "$SRC/samples/"*.png . 2>/dev/null || true
  gen samples.ins
fi

# 3. Compile the chosen sample to a stable PDF (no temp page, resolved TotPages).
"$ROOT/tools/latex-build.sh" "$OUT/$SAMPLE.tex" "$OUT"
