#!/bin/sh
# Compile a LaTeX file to a STABLE PDF, writing all output (pdf + aux) to an
# output directory so the source tree stays clean. Reruns pdflatex until
# cross-references / TotPages / lastpage settle, and fails if a "Temporary page!"
# placeholder survives (a single pass leaves acmart's TotPages unresolved, which
# would add a spurious page and corrupt diffs).
#
# Usage: tools/latex-build.sh path/to/file.tex [output-dir]
#   output-dir defaults to tests/out/latex (relative to the repo root).
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
f="$1"
outdir="${2:-$ROOT/tests/out/latex}"
case "$outdir" in /*) ;; *) outdir="$ROOT/$outdir" ;; esac
mkdir -p "$outdir"

srcdir="$(cd "$(dirname "$f")" && pwd)"
base="$(basename "$f" .tex)"
# Find acmart.cls (in the output dir) and the source's own inputs.
export TEXINPUTS="$outdir:$srcdir:"
export BIBINPUTS="$outdir:$srcdir:"

run() { pdflatex -interaction=nonstopmode -output-directory="$outdir" "$srcdir/$base.tex" >/dev/null 2>&1 || true; }

run
# bibtex must run from the directory holding the .aux (and the copied .bib).
( cd "$outdir" && bibtex "$base" >/dev/null 2>&1 ) || true
run

i=0
while [ "$i" -lt 6 ]; do
  if grep -qE 'Rerun to get|Label\(s\) may have changed|Temporary page' "$outdir/$base.log" 2>/dev/null; then
    run
    i=$((i + 1))
  else
    break
  fi
done

if [ ! -f "$outdir/$base.pdf" ]; then
  echo "ERROR: $outdir/$base.pdf was not produced (see $outdir/$base.log)." >&2
  exit 1
fi
if pdftotext "$outdir/$base.pdf" - 2>/dev/null | grep -q 'Temporary page'; then
  echo "ERROR: $outdir/$base.pdf still contains a 'Temporary page' after $i reruns." >&2
  exit 1
fi
echo "Built $outdir/$base.pdf ($(pdfinfo "$outdir/$base.pdf" 2>/dev/null | awk '/Pages/{print $2}') pages)"
