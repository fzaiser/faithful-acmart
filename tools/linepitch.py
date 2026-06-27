#!/usr/bin/env python3
"""Measure text line pitch (baseline-to-baseline) and first-baseline position.

Renders page 1 of a PDF at high DPI, finds rows containing ink, groups them into
text lines, and reports the median line pitch in PostScript points plus the
y-position of the first line. Lets us tune leading / top margin against LaTeX.

Usage: linepitch.py FILE.pdf [--dpi 300]
"""
import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("pdf")
    ap.add_argument("--dpi", type=int, default=300)
    ap.add_argument("--page", type=int, default=1)
    args = ap.parse_args()

    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        subprocess.run(
            ["pdftoppm", "-r", str(args.dpi), "-f", str(args.page), "-l", str(args.page),
             "-png", args.pdf, str(tmp / "p")],
            check=True,
        )
        png = sorted(tmp.glob("p*.png"))[0]
        img = np.asarray(Image.open(png).convert("L"), dtype=np.float32)

    ink = (img < 128).sum(axis=1)  # ink pixels per row
    rows_with_ink = ink > (0.002 * img.shape[1])  # ignore near-empty rows

    # group consecutive ink rows into lines; record weighted centroid (~baseline-ish)
    lines = []
    y = 0
    n = len(rows_with_ink)
    while y < n:
        if rows_with_ink[y]:
            start = y
            while y < n and rows_with_ink[y]:
                y += 1
            band = np.arange(start, y)
            weights = ink[start:y]
            centroid = float((band * weights).sum() / weights.sum())
            lines.append(centroid)
        else:
            y += 1

    px_per_pt = args.dpi / 72.0  # PostScript points
    centroids_pt = [c / px_per_pt for c in lines]
    pitches = np.diff(centroids_pt)
    # filter to "normal" line pitches (exclude paragraph gaps / headings)
    if len(pitches):
        med = float(np.median(pitches))
        normal = pitches[(pitches > med * 0.6) & (pitches < med * 1.4)]
    else:
        normal = pitches

    print(f"file: {args.pdf}  dpi={args.dpi}  lines detected: {len(lines)}")
    if len(lines):
        print(f"first line centroid y: {centroids_pt[0]:.2f} pt from top")
    if len(normal):
        print(f"median line pitch: {np.median(normal):.3f} pt  "
              f"(mean {np.mean(normal):.3f}, n={len(normal)})")
        print(f"  TeX pt equiv: {np.median(normal) * 72.27 / 72.0:.3f}")
    print("  all pitches (pt):", ", ".join(f"{p:.2f}" for p in pitches))
    return 0


if __name__ == "__main__":
    sys.exit(main())
