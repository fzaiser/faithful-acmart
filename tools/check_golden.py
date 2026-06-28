#!/usr/bin/env python3
"""Tier 1 — Typst self-golden snapshots.

Typst output is deterministic for pinned source + bundled fonts + engine version,
so any change to a rendered page is caught by comparing a raster hash to a
committed golden. This is a stability net (catches one test's change silently
shifting another) and involves no LaTeX.

  check_golden.py            compare current renders against tests/golden/typst.sha256
  check_golden.py --accept   regenerate the golden file (after an intended change
                             or a Typst version bump)

On a mismatch the offending page is re-rendered into tests/out/diff for inspection.
"""

import argparse
import sys

import testlib as T

GOLDEN_FILE = T.GOLDEN / "typst.sha256"
DIFF = T.TESTS / "out" / "diff"


def current_hashes() -> dict:
    """{name: [page hashes]} for every test, rasterized at the golden DPI.

    Tests with `golden = false` are skipped — their output is non-deterministic
    (e.g. timestamp mode embeds the compile date), so a stable hash is impossible.
    """
    result = {}
    for name, cfg in T.tests(T.load_manifest()).items():
        if cfg.get("golden", True) is False:
            continue
        pdf = T.typst_pdf(name)
        if not pdf.exists():
            continue
        result[name] = T.page_hashes(pdf, T.GOLDEN_DPI)
    return result


def write_golden(hashes: dict, typst_version: str) -> None:
    T.GOLDEN.mkdir(parents=True, exist_ok=True)
    lines = [f"# Tier 1 golden raster hashes — Typst {typst_version} @ {T.GOLDEN_DPI}dpi",
             "# regenerate with: make accept"]
    for name in sorted(hashes):
        for i, h in enumerate(hashes[name], 1):
            lines.append(f"{name} {i} {h}")
    GOLDEN_FILE.write_text("\n".join(lines) + "\n")


def read_golden() -> dict:
    out = {}
    if not GOLDEN_FILE.exists():
        return out
    for line in GOLDEN_FILE.read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        name, page, h = line.split()
        out.setdefault(name, {})[int(page)] = h
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--accept", action="store_true", help="regenerate golden hashes")
    args = ap.parse_args()

    man = T.load_manifest()
    if args.accept:
        write_golden(current_hashes(), man.get("typst_version", "?"))
        print(f"wrote {GOLDEN_FILE.relative_to(T.ROOT)}")
        return 0

    golden = read_golden()
    if not golden:
        print("no golden file — run `make accept` first", file=sys.stderr)
        return 1

    cur = current_hashes()
    failures = []
    for name, cfg in T.tests(man).items():
        if cfg.get("golden", True) is False:
            print(f"skip {name} (golden disabled)")
            continue
        g = golden.get(name)
        c = cur.get(name)
        if g is None:
            failures.append(f"{name}: no golden (run `make accept`)")
            continue
        if c is None:
            failures.append(f"{name}: not built")
            continue
        if len(c) != len(g):
            failures.append(f"{name}: page count {len(c)} != golden {len(g)}")
        for i, h in enumerate(c, 1):
            if g.get(i) != h:
                failures.append(f"{name}: page {i} changed")
                _dump_page(name, i)
        if not any(f.startswith(name + ":") for f in failures):
            print(f"ok   {name} ({len(c)}p)")

    if failures:
        print("\nTier 1 (golden) FAILED:", file=sys.stderr)
        for f in failures:
            print("  - " + f, file=sys.stderr)
        print(f"\nInspect changed pages in {DIFF.relative_to(T.ROOT)}/ , then "
              "`make accept` if intended.", file=sys.stderr)
        return 1
    print("\nTier 1 (golden): all passed")
    return 0


def _dump_page(name: str, page: int) -> None:
    DIFF.mkdir(parents=True, exist_ok=True)
    T.rasterize(T.typst_pdf(name), T.GOLDEN_DPI, DIFF / f"changed-{name}")


if __name__ == "__main__":
    sys.exit(main())
