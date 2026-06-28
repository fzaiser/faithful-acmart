#!/usr/bin/env python3
"""Tier 2 — cross-engine layout metrics.

Instead of comparing pixels (LaTeX and Typst rasterize differently), extract
structured geometry from both PDFs via `pdftotext -bbox` and assert numeric
tolerances. This is renderer-agnostic and debuggable ("left margin off by 2.1pt"
beats "looks off").

Only invariants that survive cross-engine line-breaking are GATED:
  - left margin: the text block's left edge — a true horizontal invariant.
  - top margin: first-content vertical position — gated loosely (it absorbs the
    engines' differing glyph-bbox ascent conventions; baseline *pitch* matching
    proves the grid itself is aligned).
  - baseline pitch: only on tests flagged uniform_pitch (single body grid).
Right margin and line count are REPORTED but not gated: they depend on where each
engine breaks lines (justification, hyphenation, reflow) and are inherently noisy.

\flushbottom handling: acmsmall vertically justifies full pages, which Typst
can't replicate, so vertical positions drift downward on multi-page documents.
Tests marked page1_only are compared on page 1 only; single-page tests compare
all (overlapping) pages.

  metrics.py             gate all tests against manifest tolerances (exit non-zero on fail)
  metrics.py --report    print the full metric table for every page, no gating
"""

import argparse
import sys

import testlib as T


def metrics_for(pdf):
    pages = T.words(pdf)
    return {n: T.page_metrics(p) for n, p in pages.items()}


def compare(name, cfg, tol, report):
    lref = T.latex_pdf(name, cfg)
    tpdf = T.typst_pdf(name)
    if not lref.exists() or not tpdf.exists():
        return [f"{name}: missing PDF ({'LaTeX' if not lref.exists() else 'Typst'})"]

    lm = metrics_for(lref)
    tm = metrics_for(tpdf)
    pages = [1] if cfg.get("page1_only") else sorted(set(lm) & set(tm))

    # left/top gated everywhere; pitch only where the body is on a single grid.
    gated = [("left", tol["left"], "left margin"), ("top", tol["top"], "top margin")]
    if cfg.get("uniform_pitch"):
        gated.append(("pitch", tol["pitch"], "baseline pitch"))

    fails = []
    for p in pages:
        a, b = lm.get(p), tm.get(p)
        if a is None or b is None:
            continue
        if report:
            print(f"  {name} p{p}: "
                  f"L {a['left']:.1f}/{b['left']:.1f}  R {a['right']:.1f}/{b['right']:.1f}  "
                  f"T {a['top']:.1f}/{b['top']:.1f}  "
                  f"lines {a['lines']}/{b['lines']}  pitch {a['pitch']:.2f}/{b['pitch']:.2f}"
                  "   (L/T/pitch gated; R/lines report-only)")
            continue
        for key, lim, label in gated:
            d = abs(a[key] - b[key])
            if d > lim:
                fails.append(f"{name} p{p}: {label} Δ={d:.2f}pt (LaTeX {a[key]:.2f} vs "
                             f"Typst {b[key]:.2f}, tol {lim})")
    return fails


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--report", action="store_true", help="print metric table, no gating")
    args = ap.parse_args()

    man = T.load_manifest()
    tol = man["metrics_tolerance"]
    failures = []
    for name, cfg in T.tests(man).items():
        if cfg.get("metrics") is False:
            print(f"skip {name} (metrics disabled)")
            continue
        if args.report:
            print(name + ":")
        fs = compare(name, cfg, tol, args.report)
        if not args.report:
            if fs:
                failures.extend(fs)
            else:
                print(f"ok   {name}")

    if args.report:
        return 0
    if failures:
        print("\nTier 2 (metrics) FAILED:", file=sys.stderr)
        for f in failures:
            print("  - " + f, file=sys.stderr)
        return 1
    print("\nTier 2 (metrics): all passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
