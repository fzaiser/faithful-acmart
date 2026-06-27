#!/bin/sh
# Build the LaTeX acmart reference artifacts into reference/ (gitignored).
#
# Generates acmart.cls from the upstream sources in acmart/, extracts the sample
# .tex files, and compiles a chosen sample (default: acmsmall) to a reference
# PDF that the Typst output is diffed against. Requires a TeX Live install
# (pdflatex, bibtex).
#
# Usage: tools/build-reference.sh [sample-name]   # e.g. acmsmall (default), sigconf, ...
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/acmart"
REF="$ROOT/reference"
SAMPLE="${1:-acmsmall}"

mkdir -p "$REF"
cd "$REF"

# pdflatex/bibtex return non-zero on mere warnings, so don't let `set -e` abort;
# we verify success by checking the output PDF at the end.
latex() { pdflatex -interaction=nonstopmode "$1" >/dev/null 2>&1 || true; }

# 1. Generate acmart.cls from the .ins/.dtx (idempotent).
if [ ! -f acmart.cls ] || [ "$SRC/acmart.dtx" -nt acmart.cls ]; then
  cp "$SRC/acmart.ins" "$SRC/acmart.dtx" .
  latex acmart.ins
fi

# 2. Extract the sample .tex sources and copy supporting files.
if [ ! -f "$SAMPLE.tex" ]; then
  cp "$SRC/samples/samples.ins" "$SRC/samples/samples.dtx" .
  cp "$SRC/samples/"*.bib "$SRC/ACM-Reference-Format.bst" "$SRC/samples/"*.png . 2>/dev/null || true
  latex samples.ins
fi

# 3. Compile the chosen sample (with bibtex passes).
latex "$SAMPLE.tex"
bibtex "$SAMPLE" >/dev/null 2>&1 || true
latex "$SAMPLE.tex"
latex "$SAMPLE.tex"

if [ ! -f "$SAMPLE.pdf" ]; then
  echo "ERROR: $REF/$SAMPLE.pdf was not produced. Check the LaTeX log in $REF." >&2
  exit 1
fi
echo "Reference built: $REF/$SAMPLE.pdf ($(pdfinfo "$SAMPLE.pdf" 2>/dev/null | awk '/Pages/{print $2}') pages)"
