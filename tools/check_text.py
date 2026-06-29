#!/usr/bin/env python3
"""Tier 1.5 — extracted-text semantic gate.

This gate compares LaTeX and Typst PDFs at the text layer. Some tests can be
held to exact normalized equality; others have unavoidable PDF extraction noise
(two-column order, author grids, tables, bibliography engines) and instead use
targeted contains/absent assertions from tests/manifest.toml.
"""

from __future__ import annotations

import argparse
import difflib
import re
import subprocess
import sys
import unicodedata
from pathlib import Path

import testlib as T


def pdf_text(pdf: Path, page: int | None = None) -> str:
    cmd = ["pdftotext"]
    if page is not None:
        cmd += ["-f", str(page), "-l", str(page)]
    cmd += [str(pdf), "-"]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or f"pdftotext failed for {pdf}")
    return proc.stdout


def normalize(text: str) -> str:
    text = unicodedata.normalize("NFKC", text)
    replacements = {
        "\u00ad": "",    # soft hyphen
        "\u2010": "-",
        "\u2011": "-",
        "\u2012": "-",
        "\u2013": "-",
        "\u2014": "-",
        "\u2212": "-",
        "\u2018": "'",
        "\u2019": "'",
        "\u201c": '"',
        "\u201d": '"',
        "\u2217": "*",
        "\u204e": "*",
        "\u2219": "•",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    # pdftotext often emits page folios as standalone lines; these are visual
    # page-style artifacts, not document text, and can differ harmlessly.
    text = re.sub(r"(?m)^\s*\d+\s*$", " ", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def first_diff(a: str, b: str) -> str:
    aw, bw = a.split(), b.split()
    matcher = difflib.SequenceMatcher(a=aw, b=bw)
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == "equal":
            continue
        left = " ".join(aw[max(0, i1 - 8):min(len(aw), i2 + 12)])
        right = " ".join(bw[max(0, j1 - 8):min(len(bw), j2 + 12)])
        return f"{tag} at LaTeX token {i1}, Typst token {j1}\n    LaTeX: {left}\n    Typst: {right}"
    return "strings differ, but no token diff was found"


def assertion_targets(name: str, cfg: dict, assertion: dict) -> list[tuple[str, Path]]:
    engine = assertion.get("engine", "typst")
    if engine == "typst":
        return [("Typst", T.typst_pdf(name))]
    if engine == "latex":
        return [("LaTeX", T.latex_pdf(name, cfg))]
    if engine == "both":
        return [("LaTeX", T.latex_pdf(name, cfg)), ("Typst", T.typst_pdf(name))]
    raise ValueError(f"unknown text assertion engine {engine!r}")


def check_test(name: str, cfg: dict, report: bool) -> list[str]:
    failures: list[str] = []
    if cfg.get("kind") != "twin":
        return failures

    lref = T.latex_pdf(name, cfg)
    tpdf = T.typst_pdf(name)
    if not lref.exists() or not tpdf.exists():
        return [f"{name}: missing PDF ({'LaTeX' if not lref.exists() else 'Typst'})"]

    ltext = normalize(pdf_text(lref))
    ttext = normalize(pdf_text(tpdf))

    text_equal = cfg.get("text_equal")
    if text_equal is True:
        if ltext != ttext:
            failures.append(f"{name}: normalized text differs\n    {first_diff(ltext, ttext)}")
        elif report:
            print(f"equal {name}")
    elif text_equal is False:
        if not cfg.get("text_reason"):
            failures.append(f"{name}: text_equal=false requires text_reason")
        elif report:
            print(f"skip  {name}: {cfg.get('text_reason')}")
    elif report:
        print(f"skip  {name}: text equality not configured")

    for i, assertion in enumerate(cfg.get("text_assertions", ()), 1):
        kind = assertion.get("kind", "contains")
        needle = normalize(assertion.get("text", ""))
        page = assertion.get("page")
        if not needle:
            failures.append(f"{name}: text assertion {i} has empty text")
            continue
        for label, pdf in assertion_targets(name, cfg, assertion):
            haystack = normalize(pdf_text(pdf, page=page))
            scope = f" page {page}" if page is not None else ""
            if kind == "contains" and needle not in haystack:
                failures.append(f"{name}: {label}{scope} missing text assertion {i}: {needle!r}")
            elif kind == "absent" and needle in haystack:
                failures.append(f"{name}: {label}{scope} contains forbidden text assertion {i}: {needle!r}")
            elif kind not in ("contains", "absent"):
                failures.append(f"{name}: unknown text assertion kind {kind!r}")
    return failures


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--report", action="store_true", help="print equality status and skip reasons")
    args = ap.parse_args()

    failures: list[str] = []
    man = T.load_manifest()
    for name, cfg in T.tests(man).items():
        fs = check_test(name, cfg, args.report)
        if fs:
            failures.extend(fs)
        elif not args.report and (cfg.get("text_equal") is not None or cfg.get("text_assertions")):
            print(f"ok   {name}")

    if failures:
        print("\nTier 1.5 (text) FAILED:", file=sys.stderr)
        for f in failures:
            print("  - " + f.replace("\n", "\n    "), file=sys.stderr)
        return 1
    print("\nTier 1.5 (text): all passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
