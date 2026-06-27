#!/usr/bin/env python3
"""Visual diff between two PDFs (reference vs ours).

Renders each page of both PDFs to PNG at a fixed DPI (via pdftoppm) and writes,
per page, a side-by-side comparison plus a red/blue overlay diff. Also prints a
per-page mismatch percentage so progress is measurable.

Usage:
    pdfdiff.py REFERENCE.pdf OURS.pdf OUTDIR [--dpi 150] [--pages 1-3]
"""
import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image


def render(pdf: Path, dpi: int, outdir: Path, tag: str) -> list[Path]:
    prefix = outdir / f"{tag}"
    subprocess.run(
        ["pdftoppm", "-r", str(dpi), "-png", str(pdf), str(prefix)],
        check=True,
    )
    return sorted(outdir.glob(f"{tag}-*.png"))


def to_gray(img: Image.Image) -> np.ndarray:
    return np.asarray(img.convert("L"), dtype=np.float32)


def pad_to(arr: np.ndarray, h: int, w: int, fill: float = 255.0) -> np.ndarray:
    out = np.full((h, w), fill, dtype=arr.dtype)
    out[: arr.shape[0], : arr.shape[1]] = arr[:h, :w]
    return out


def parse_pages(spec: str | None, n: int) -> list[int]:
    if not spec:
        return list(range(n))
    out: set[int] = set()
    for part in spec.split(","):
        if "-" in part:
            a, b = part.split("-")
            out.update(range(int(a) - 1, int(b)))
        else:
            out.add(int(part) - 1)
    return sorted(i for i in out if 0 <= i < n)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("reference")
    ap.add_argument("ours")
    ap.add_argument("outdir")
    ap.add_argument("--dpi", type=int, default=150)
    ap.add_argument("--pages", default=None)
    args = ap.parse_args()

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        ref_pngs = render(Path(args.reference), args.dpi, tmp, "ref")
        our_pngs = render(Path(args.ours), args.dpi, tmp, "our")

        npages = max(len(ref_pngs), len(our_pngs))
        pages = parse_pages(args.pages, npages)
        print(f"reference: {len(ref_pngs)} pages, ours: {len(our_pngs)} pages, dpi={args.dpi}")

        for i in pages:
            ref = to_gray(Image.open(ref_pngs[i])) if i < len(ref_pngs) else None
            our = to_gray(Image.open(our_pngs[i])) if i < len(our_pngs) else None
            if ref is None or our is None:
                print(f"page {i+1}: MISSING in {'ours' if our is None else 'reference'}")
                continue

            h = max(ref.shape[0], our.shape[0])
            w = max(ref.shape[1], our.shape[1])
            r = pad_to(ref, h, w)
            o = pad_to(our, h, w)

            # mismatch metric: fraction of pixels differing beyond threshold
            diff = np.abs(r - o)
            mismatch = float((diff > 40).mean()) * 100.0
            print(f"page {i+1}: {mismatch:5.2f}% mismatch  (ref {ref.shape[1]}x{ref.shape[0]}, our {our.shape[1]}x{our.shape[0]})")

            # overlay: reference ink in red, ours in blue, shared in dark
            overlay = np.full((h, w, 3), 255, dtype=np.uint8)
            ref_ink = 255 - r  # 0..255, higher = darker
            our_ink = 255 - o
            overlay[..., 0] = (255 - our_ink).astype(np.uint8)  # remove our ink from R -> ref shows red
            overlay[..., 2] = (255 - ref_ink).astype(np.uint8)  # remove ref ink from B -> ours shows blue
            overlay[..., 1] = (255 - np.maximum(ref_ink, our_ink)).astype(np.uint8)
            Image.fromarray(overlay).save(outdir / f"overlay-p{i+1:02d}.png")

            # side by side
            gap = 16
            sbs = np.full((h, w * 2 + gap), 255, dtype=np.uint8)
            sbs[:, :w] = r.astype(np.uint8)
            sbs[:, w + gap :] = o.astype(np.uint8)
            Image.fromarray(sbs).save(outdir / f"side-p{i+1:02d}.png")

        print(f"\nwrote diffs to {outdir}/  (overlay-pNN.png = ref red / ours blue / shared dark; side-pNN.png = ref | ours)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
