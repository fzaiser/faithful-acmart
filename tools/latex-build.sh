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

# Always build against the acmart.cls BUNDLED in this repo (acmart/), never the
# version installed in the system TeX tree — the two can differ (e.g. section-title
# uppercasing). Generate it into $outdir from the bundled .ins/.dtx if missing or
# stale, plus the bundled bibliography style. TEXINPUTS below puts $outdir first,
# so this local copy wins over any system acmart.
if [ ! -f "$outdir/acmart.cls" ] || [ "$ROOT/acmart/acmart.dtx" -nt "$outdir/acmart.cls" ]; then
  cp "$ROOT/acmart/acmart.ins" "$ROOT/acmart/acmart.dtx" "$outdir/"
  ( cd "$outdir" && pdflatex -interaction=nonstopmode acmart.ins >/dev/null 2>&1 || true )
fi
[ -f "$outdir/ACM-Reference-Format.bst" ] || \
  cp "$ROOT/acmart/ACM-Reference-Format.bst" "$outdir/" 2>/dev/null || true
[ -f "$outdir/acm-jdslogo.png" ] || \
  cp "$ROOT/acmart/acm-jdslogo.png" "$outdir/" 2>/dev/null || true

# Find acmart.cls (in the output dir) and the source's own inputs.
export TEXINPUTS="$outdir:$srcdir:"
# Include the bundled sample bibliographies so test twins can \bibliography{sample-base}
# without copying the .bib into the source tree.
export BIBINPUTS="$outdir:$srcdir:$ROOT/acmart/samples:"

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
if grep -qE '^! |Emergency stop|Fatal error occurred|No output PDF file produced' "$outdir/$base.log"; then
  echo "ERROR: LaTeX reported an error while building $base (see $outdir/$base.log)." >&2
  exit 1
fi
if pdftotext "$outdir/$base.pdf" - 2>/dev/null | grep -q 'Temporary page'; then
  echo "ERROR: $outdir/$base.pdf still contains a 'Temporary page' after $i reruns." >&2
  exit 1
fi
echo "Built $outdir/$base.pdf ($(pdfinfo "$outdir/$base.pdf" 2>/dev/null | awk '/Pages/{print $2}') pages)"
