#!/bin/sh
# Compile a LaTeX file to a STABLE PDF: rerun pdflatex until cross-references,
# TotPages, and the lastpage label settle, so no "Temporary page!" placeholder or
# stale page count survives. Verifies the PDF exists and is free of the temporary
# page. Usage: tools/latex-build.sh path/to/file.tex
set -eu

f="$1"
dir="$(cd "$(dirname "$f")" && pwd)"
base="$(basename "$f" .tex)"
cd "$dir"

run() { pdflatex -interaction=nonstopmode "$base.tex" >/dev/null 2>&1 || true; }

run
bibtex "$base" >/dev/null 2>&1 || true
run

# Rerun while LaTeX asks for it (labels changed / rerun / temporary page).
i=0
while [ "$i" -lt 6 ]; do
  if grep -qE 'Rerun to get|Label\(s\) may have changed|Temporary page' "$base.log" 2>/dev/null; then
    run
    i=$((i + 1))
  else
    break
  fi
done

if [ ! -f "$base.pdf" ]; then
  echo "ERROR: $dir/$base.pdf was not produced (see $base.log)." >&2
  exit 1
fi
# Guard against a surviving placeholder page.
if pdftotext "$base.pdf" - 2>/dev/null | grep -q 'Temporary page'; then
  echo "ERROR: $base.pdf still contains a 'Temporary page' after $i reruns." >&2
  exit 1
fi
echo "Built $dir/$base.pdf ($(pdfinfo "$base.pdf" 2>/dev/null | awk '/Pages/{print $2}') pages)"
