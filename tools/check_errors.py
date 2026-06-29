#!/usr/bin/env python3
"""Tier 1.6 — expected compile-error gate."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import testlib as T

OUT = T.TESTS / "out" / "error"


CASES = {
    "bad-copyright": (
        'copyright: "definitely-not-a-mode",',
        "unsupported copyright mode",
    ),
    "bad-cc-type": (
        'copyright: "cc", cc-type: "by-mystery",',
        "unsupported Creative Commons type",
    ),
    "bad-cc-version": (
        'copyright: "cc", cc-version: "2.5",',
        "unsupported Creative Commons version",
    ),
    "bad-font-size": (
        'font-size: "13pt",',
        "font-size",
    ),
    "bad-language": (
        'language: "klingon",',
        "unsupported language",
    ),
    "draft-option": (
        "draft: true,",
        "option `draft` has no effect",
    ),
}


def source(extra_arg: str) -> str:
    return f"""#import "/src/lib.typ": acmart

#show: acmart.with(
  format: "acmsmall",
  title: "Expected Error",
  authors: ((name: "Ada Lovelace"),),
  abstract: [A tiny document.],
  {extra_arg}
)

= Body
Text.
"""


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    failures: list[str] = []

    for name, (extra, expected) in CASES.items():
        src = OUT / f"{name}.typ"
        pdf = OUT / f"{name}.pdf"
        src.write_text(source(extra))
        proc = subprocess.run(
            [str(T.TC), "compile", str(src), str(pdf), "--diagnostic-format", "short"],
            capture_output=True,
            text=True,
        )
        diagnostics = proc.stderr + proc.stdout
        if proc.returncode == 0:
            failures.append(f"{name}: expected compile failure, but compile succeeded")
        elif expected not in diagnostics:
            failures.append(
                f"{name}: expected diagnostic containing {expected!r}, got:\n{diagnostics.strip()}"
            )
        else:
            print(f"ok   {name}")

    if failures:
        print("\nTier 1.6 (expected errors) FAILED:", file=sys.stderr)
        for f in failures:
            print("  - " + f.replace("\n", "\n    "), file=sys.stderr)
        return 1
    print("\nTier 1.6 (expected errors): all passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
