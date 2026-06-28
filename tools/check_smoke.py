#!/usr/bin/env python3
"""Tier 0 — smoke gate.

For each test in the manifest: compile the Typst source and FAIL on any compiler
warning (overflow, unresolved ref, dropped font feature) or error; assert the
output page count matches the manifest; and for twins, assert LaTeX/Typst
page-count parity (unless page_parity = false).

Exit non-zero on any failure. Run after `make test` has built the LaTeX refs.
"""

import sys

import testlib as T


def main() -> int:
    man = T.load_manifest()
    failures = []

    for name, cfg in T.tests(man).items():
        out = T.typst_pdf(name)
        out.parent.mkdir(parents=True, exist_ok=True)

        rc, stderr = T.compile_typst(name, out)
        if rc != 0:
            failures.append(f"{name}: typst compile failed (rc={rc})\n{stderr.strip()}")
            continue
        if "warning" in stderr.lower():
            failures.append(f"{name}: typst emitted warnings:\n{stderr.strip()}")

        got = T.page_count(out)
        want = cfg.get("pages")
        if want is not None and got != want:
            failures.append(f"{name}: Typst page count {got} != expected {want}")

        parity = cfg.get("page_parity", cfg.get("kind") == "twin")
        if parity:
            lref = T.latex_pdf(name, cfg)
            if lref.exists():
                lp = T.page_count(lref)
                if lp != got:
                    failures.append(
                        f"{name}: page-count parity broken (LaTeX {lp} vs Typst {got})"
                    )
            else:
                failures.append(f"{name}: LaTeX reference {lref.name} missing (run `make test`)")

        if not [f for f in failures if f.startswith(name + ":")]:
            print(f"ok   {name} ({got}p)")

    if failures:
        print("\nTier 0 (smoke) FAILED:", file=sys.stderr)
        for f in failures:
            print("  - " + f.replace("\n", "\n    "), file=sys.stderr)
        return 1
    print("\nTier 0 (smoke): all passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
