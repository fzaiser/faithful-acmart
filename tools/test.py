#!/usr/bin/env python3
"""typst-acmart test & build harness — the one command runner.

This is the Python-owned replacement for the old Makefile + shell scripts. The
test data lives in `tools/test_matrix.py`; this file turns it into commands.

Run through uv (it has Pillow/numpy/fonttools/PyMuPDF/pikepdf for the visual
and PDF-structure gates):

    uv run python tools/test.py <command> [args]

Commands
--------
  build            build the LaTeX references, every Typst test PDF, and the example
  smoke [names]    build and page-check selected matrix tests (default: all)
  check            run all regression gates (smoke / unit / golden / text / errors / metrics)
  unit             run the pure-Typst unit tests in tests/unit/*.typ (no LaTeX needed)
  sweep            compile a representative doc across every active format × base size (no LaTeX)
  accept           rebuild Typst PDFs and refresh the Tier 1 golden hashes
  overlay [stems]  per-twin vector <name>-overlay.pdf + <name>-side-by-side.pdf vs LaTeX (all twins, or given stems)
  report [stems]   self-contained HTML LaTeX-vs-Typst page comparison (tests/out/report/); default: twins that failed the last check
  validate [names] copyright/option variants vs LaTeX, page-1 mismatch %
  probe            dump a format's ground-truth dimensions from the bundled class (--format)
  example          build the Typst example (template/main.typ)
  list             print the test matrix
  clean            remove all generated output (tests/out/)
  metrics          print the Tier 2 layout-metric table for every page (no gating)
  structure        report tagged-PDF roles, language, and image alternatives
  source-data      compare transcribed tables with bundled acmart.dtx and ACM-Reference-Format.bst
  linepitch FILE   measure baseline pitch / first-line position in a PDF (--dpi, --page)
  text FILE        print a PDF's extracted text exactly as the text gates see it (--page)
  bib-oracle       compare the pure-Typst .bib reader with real bibtex on well-formed input (on-demand)

External tools required: Typst and TeX Live (pdflatex, bibtex, biber), plus
qpdf, pdfjam and Ghostscript (gs) for the `overlay` command and the report's
overlay column. PDF reading (text, rasters, geometry, metadata, structure) is
done in Python by the uv-pinned PyMuPDF and pikepdf, so every machine extracts
identically. All generated output lives under tests/out/ (gitignored).
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import test_matrix as M
from test_matrix import TESTS
from harness import (
    ROOT, TOOLS, TESTS_DIR, OUT, TYPST, LATEX, GOLDEN_FILE, TC, TEMPLATE,
    compile_typst, compile_all_typst, _compile_failures, default_jobs,
)
from pdf_extract import _EXTRACT_CACHE, pdf_text, raster_array
from latex_build import build_all_latex, latex_build, gate_latex_oracle
from source_data import gate_source_data, gate_package
from gates_core import (
    gate_matrix_integrity, gate_smoke, gate_golden, write_golden,
    gate_errors, gate_format_sweep, gate_unit,
)
from gates_text import gate_text
from gates_semantic import (
    gate_metadata, gate_links, gate_fonts, gate_structure, gate_order,
    gate_outline,
)
from gates_layout import gate_metrics, gate_word_positions, gate_horizontal_rules
from overlay import cmd_overlay
from validate import gate_validate, cmd_validate
from bib_oracle import cmd_bib_oracle
from report import cmd_report, record_check_status


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------
def _run_gate(title: str, failures: list[str]) -> bool:
    if failures:
        print(f"\n{title} FAILED:", file=sys.stderr)
        for f in failures:
            print("  - " + f.replace("\n", "\n    "), file=sys.stderr)
        return False
    print(f"\n{title}: all passed")
    return True
def cmd_build(args) -> int:
    print("Building LaTeX references…")
    build_all_latex(jobs=args.jobs, force=args.force)
    print("Compiling Typst test PDFs…")
    compiled = compile_all_typst()
    # Warnings fail the build, consistent with gate_smoke: a clean compile emits
    # nothing on stderr, so any Typst warning here is a regression.
    bad = _compile_failures(compiled)
    warned = [f"{name}: {stderr.strip()}" for name, (rc, stderr) in compiled.items()
              if rc == 0 and "warning" in stderr.lower()]
    print("Building the Typst example…")
    example_rc, example_stderr = compile_typst(TEMPLATE, TYPST / "main.pdf")
    if example_stderr.strip():
        print(example_stderr.strip(), file=sys.stderr)
    example_warn = example_rc == 0 and "warning" in example_stderr.lower()
    if bad:
        print("WARNING: Typst test sources failed to compile:", file=sys.stderr)
        for failure in bad:
            print(f"  - {failure}", file=sys.stderr)
    if warned:
        print("WARNING: Typst test sources emitted warnings:", file=sys.stderr)
        for failure in warned:
            print(f"  - {failure}", file=sys.stderr)
    if example_rc != 0:
        print(f"WARNING: Typst example failed to compile (rc={example_rc})", file=sys.stderr)
    elif example_warn:
        print("WARNING: Typst example emitted warnings", file=sys.stderr)
    if bad or warned or example_rc != 0 or example_warn:
        return 1
    print(f"\nBuilt {len(TESTS)} Typst PDFs + example into {TYPST.relative_to(ROOT)}/.")
    return 0
def cmd_smoke(args) -> int:
    names = args.names or list(TESTS)
    unknown = [name for name in names if name not in TESTS]
    if unknown:
        print("unknown test name(s): " + ", ".join(unknown), file=sys.stderr)
        return 2
    print("Building selected LaTeX references…")
    build_all_latex(jobs=args.jobs, force=args.force, names=names)
    print("Compiling selected Typst tests…")
    compiled = compile_all_typst(names)
    return 0 if _run_gate("Tier 0 (targeted smoke)", gate_smoke(compiled, names)) else 1
def cmd_unit(_args) -> int:
    failures = gate_unit(report=True)
    for f in failures:
        print(f, file=sys.stderr)
    return 1 if failures else 0
def cmd_sweep(_args) -> int:
    failures = gate_format_sweep(report=True)
    for failure in failures:
        print(failure, file=sys.stderr)
    return 1 if failures else 0
def cmd_structure(_args) -> int:
    failures = gate_structure(report=True)
    for failure in failures:
        print(failure, file=sys.stderr)
    return 1 if failures else 0
def cmd_source_data(_args) -> int:
    failures = gate_source_data(report=True)
    for failure in failures:
        print(failure, file=sys.stderr)
    return 1 if failures else 0
def cmd_package(_args) -> int:
    failures = gate_package(report=True)
    for failure in failures:
        print(failure, file=sys.stderr)
    return 1 if failures else 0
def cmd_min_version(_args) -> int:
    """Compile a representative subset under the manifest's minimum Typst."""
    proc = subprocess.run([str(TC), "--version"], capture_output=True, text=True)
    match = re.search(r"\b(\d+\.\d+\.\d+)\b", proc.stdout + proc.stderr)
    actual = match.group(1) if match else None
    if proc.returncode != 0 or actual != M.MIN_TYPST_VERSION:
        print(
            f"minimum-version job requires Typst {M.MIN_TYPST_VERSION}, found {actual!r}",
            file=sys.stderr,
        )
        return 1
    sources = (
        TESTS_DIR / "typst-only" / "defaults-test.typ",
        TESTS_DIR / "typst-only" / "proceedings-defaults-test.typ",
        TESTS_DIR / "twins" / "title-test.typ",
        TESTS_DIR / "twins" / "body2-test.typ",
        TESTS_DIR / "twins" / "biblatex-driver-test.typ",
    )
    failures: list[str] = []
    with tempfile.TemporaryDirectory() as td:
        for source in sources:
            rc, stderr = compile_typst(source, Path(td) / f"{source.stem}.pdf")
            if rc != 0:
                failures.append(f"{source.relative_to(ROOT)}:\n{stderr.strip()}")
            else:
                print(f"ok   {source.relative_to(ROOT)}")
    for failure in failures:
        print(failure, file=sys.stderr)
    return 1 if failures else 0
def _check_gates(args, compiled) -> list[tuple[str, str, "callable"]]:
    """Ordered (slug, tier title, thunk) for every `check` gate.

    The slug is the stable name used by `--gates`; the thunk closes over the
    already-built LaTeX refs / compiled Typst so a gate is invoked identically
    whether the run is full or filtered.
    """
    return [
        ("matrix-integrity", "Tier 0.1 (matrix integrity)", gate_matrix_integrity),
        ("source-data",      "Tier 0.15 (source data)",     gate_source_data),
        ("latex-oracle",     "Tier 0.25 (LaTeX oracle)",    gate_latex_oracle),
        ("smoke",            "Tier 0 (smoke)",              lambda: gate_smoke(compiled)),
        ("unit",             "Tier 0.5 (unit)",             gate_unit),
        ("package",          "Tier 0.75 (package)",         gate_package),
        ("format-sweep",     "Tier 0.8 (format×size sweep)", gate_format_sweep),
        ("golden",           "Tier 1 (golden)",             gate_golden),
        ("text",             "Tier 1.5 (text)",             gate_text),
        ("metadata",         "Tier 1.55 (metadata)",        gate_metadata),
        ("errors",           "Tier 1.6 (expected errors)",  gate_errors),
        ("links",            "Tier 1.7 (hyperlinks)",       gate_links),
        ("validate",         "Tier 1.75 (validation variants)", lambda: gate_validate(args.jobs, args.force)),
        ("fonts",            "Tier 1.8 (fonts)",            gate_fonts),
        ("structure",        "Tier 1.85 (structure)",       gate_structure),
        ("order",            "Tier 1.9 (order)",            gate_order),
        ("outline",          "Tier 1.95 (outline)",         gate_outline),
        ("metrics",          "Tier 2 (metrics)",            gate_metrics),
        ("word-positions",   "Tier 2.5 (word positions)",   gate_word_positions),
        ("rules",            "Tier 2.6 (horizontal rules)", gate_horizontal_rules),
    ]
CHECK_GATE_SLUGS = [
    "matrix-integrity", "source-data", "latex-oracle", "smoke", "unit",
    "package", "format-sweep", "golden", "text", "metadata", "errors", "links",
    "validate", "fonts", "structure", "order", "outline", "metrics",
    "word-positions", "rules",
]
def cmd_check(args) -> int:
    selected = None
    if args.gates:
        selected = [s.strip() for s in args.gates.split(",") if s.strip()]
        unknown = [s for s in selected if s not in CHECK_GATE_SLUGS]
        if unknown:
            print("unknown gate(s): " + ", ".join(unknown), file=sys.stderr)
            print("available: " + ", ".join(CHECK_GATE_SLUGS), file=sys.stderr)
            return 2

    _EXTRACT_CACHE.clear()
    print("Building LaTeX references…")
    build_all_latex(jobs=args.jobs, force=args.force)
    print("Compiling Typst test PDFs once…")
    compiled = compile_all_typst()

    ok = True
    gate_failures: dict[str, list[str]] = {}
    for slug, title, thunk in _check_gates(args, compiled):
        if selected is not None and slug not in selected:
            continue
        print(f"\n== {title} ==")
        failures = thunk()
        gate_failures[slug] = failures
        ok &= _run_gate(title, failures)
    # Record which gates flagged which twin so `test.py report` (with no stems)
    # can default to the failing twins. Written into tests/out/ (gitignored).
    record_check_status(gate_failures)
    return 0 if ok else 1
def cmd_accept(_args) -> int:
    print("Compiling Typst test PDFs…")
    compiled = compile_all_typst()
    failures = _compile_failures(compiled)
    if failures:
        print("Refusing to write golden hashes because Typst compilation failed:",
              file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        return 1
    write_golden()
    print(f"wrote {GOLDEN_FILE.relative_to(ROOT)}")
    return 0
def cmd_example(_args) -> int:
    TYPST.mkdir(parents=True, exist_ok=True)
    rc, stderr = compile_typst(TEMPLATE, TYPST / "main.pdf")
    if stderr.strip():
        print(stderr.strip(), file=sys.stderr)
    print(f"Built {TYPST / 'main.pdf'}")
    return rc
def cmd_probe(args) -> int:
    """Dump a format's ground-truth dimensions from the BUNDLED acmart class."""
    LATEX.mkdir(parents=True, exist_ok=True)
    fmt = args.format
    src = (TOOLS / "probe.tex").read_text().replace("format=acmsmall", f"format={fmt}")
    probe = LATEX / f"probe-{fmt}.tex"
    probe.write_text(src)
    try:
        latex_build(probe)
    except SystemExit:
        pass  # the probe \typeout lines are what we want; a non-clean build is fine
    log = (LATEX / f"probe-{fmt}.log").read_text(errors="replace")
    for line in log.splitlines():
        if line.startswith(("PROBE ", "SIZE ")):
            print(line)
    return 0
def cmd_list(_args) -> int:
    print(f"{'stem':24} {'kind':13} pages  flags")
    print("-" * 78)
    for name, t in TESTS.items():
        flags = []
        if t.expected_page_count_diff:
            flags.append("pagediff")
        if t.metrics_page1_only:
            flags.append("page1metrics")
        if t.metrics_uniform_pitch:
            flags.append("pitchmetrics")
        if t.text_equal is True:
            flags.append("text_equal")
        elif t.text_equal == "bag":
            flags.append("text_bag")
        if t.text_assertions:
            flags.append(f"assert×{len(t.text_assertions)}")
        if t.expected_text_diffs:
            flags.append(f"textdiff×{len(t.expected_text_diffs)}")
        if t.expected_font_diffs:
            flags.append(f"fontdiff×{len(t.expected_font_diffs)}")
        if t.expected_order_diffs:
            flags.append(f"orderdiff×{len(t.expected_order_diffs)}")
        if name in M.EXPECTED_LINK_DIFFS:
            flags.append("linkdiff")
        if name in M.EXPECTED_DASH_DIFFS:
            flags.append("dashdiff")
        if t.min_internal_links:
            flags.append(f"ilinks≥{t.min_internal_links}")
        if t.min_internal_destinations:
            flags.append(f"idests≥{t.min_internal_destinations}")
        if t.expected_metrics_diff:
            flags.append("metricdiff")
        if t.golden_exempt:
            flags.append("no-golden")
        print(f"{name:24} {t.kind:13} {t.pages:>5}  {' '.join(flags)}")
    print(f"\n{len(TESTS)} tests "
          f"({sum(t.kind == 'twin' for t in TESTS.values())} twin, "
          f"{sum(t.kind == 'smoke' for t in TESTS.values())} smoke).")
    return 0
def cmd_clean(_args) -> int:
    if OUT.exists():
        shutil.rmtree(OUT)
        print(f"removed {OUT.relative_to(ROOT)}/")
    else:
        print("nothing to clean")
    return 0
def cmd_metrics(_args) -> int:
    gate_metrics(report=True)
    return 0
def cmd_order(_args) -> int:
    failures = gate_order(report=True)
    for f in failures:
        print(f)
    return 1 if failures else 0
def cmd_text(args) -> int:
    sys.stdout.write(pdf_text(Path(args.pdf), page=args.page))
    return 0
def cmd_linepitch(args) -> int:
    import numpy as np

    img = raster_array(Path(args.pdf), args.page, args.dpi, gray=True).astype(np.float32)

    ink = (img < 128).sum(axis=1)
    rows = ink > (0.002 * img.shape[1])
    lines, y, n = [], 0, len(rows)
    while y < n:
        if rows[y]:
            start = y
            while y < n and rows[y]:
                y += 1
            band, weights = np.arange(start, y), ink[start:y]
            lines.append(float((band * weights).sum() / weights.sum()))
        else:
            y += 1

    px_per_pt = args.dpi / 72.0
    centroids = [c / px_per_pt for c in lines]
    pitches = np.diff(centroids)
    if len(pitches):
        med = float(np.median(pitches))
        normal = pitches[(pitches > med * 0.6) & (pitches < med * 1.4)]
    else:
        normal = pitches
    print(f"file: {args.pdf}  dpi={args.dpi}  lines detected: {len(lines)}")
    if len(lines):
        print(f"first line centroid y: {centroids[0]:.2f} pt from top")
    if len(normal):
        print(f"median line pitch: {np.median(normal):.3f} pt  "
              f"(mean {np.mean(normal):.3f}, n={len(normal)})")
        print(f"  TeX pt equiv: {np.median(normal) * 72.27 / 72.0:.3f}")
    print("  all pitches (pt):", ", ".join(f"{p:.2f}" for p in pitches))
    return 0
def main() -> int:
    ap = argparse.ArgumentParser(prog="test.py", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    # Shared by the LaTeX-building commands (build / check / validate).
    par = argparse.ArgumentParser(add_help=False)
    par.add_argument("-j", "--jobs", type=int, default=default_jobs(),
                     help=f"parallel LaTeX build jobs (default {default_jobs()} = cpu-2)")
    par.add_argument("--force", action="store_true",
                     help="rebuild LaTeX references even if their cached PDFs look up to date")

    sub.add_parser("build", parents=[par],
                   help="build LaTeX refs + all Typst PDFs + example").set_defaults(fn=cmd_build)
    smoke = sub.add_parser("smoke", parents=[par],
                           help="build and page-check selected matrix tests")
    smoke.add_argument("names", nargs="*", help="test names (default: all)")
    smoke.set_defaults(fn=cmd_smoke)
    check = sub.add_parser("check", parents=[par], help="run all regression gates")
    check.add_argument(
        "--gates", metavar="LIST",
        help="run only these comma-separated gates (default: all). "
             "Choices: " + ", ".join(CHECK_GATE_SLUGS))
    check.set_defaults(fn=cmd_check)
    sub.add_parser("accept", help="rebuild Typst PDFs and refresh golden hashes").set_defaults(fn=cmd_accept)
    sub.add_parser("unit", help="run pure-Typst unit tests (tests/unit/*.typ); no LaTeX").set_defaults(fn=cmd_unit)
    sub.add_parser("package", help="validate and compile the manifest-filtered package").set_defaults(fn=cmd_package)
    sub.add_parser("min-version", help=f"compile compatibility fixtures under the manifest minimum, Typst {M.MIN_TYPST_VERSION}").set_defaults(fn=cmd_min_version)

    o = sub.add_parser("overlay",
                       help="per-twin vector overlay + side-by-side PDFs vs LaTeX")
    o.add_argument("stems", nargs="*",
                   help="test stems to include (default: every twin)")
    o.set_defaults(fn=cmd_overlay)

    v = sub.add_parser("validate", parents=[par],
                       help="copyright/option variants vs LaTeX (page-1 mismatch pct)")
    v.add_argument("names", nargs="*", help="variant names (default: all)")
    v.set_defaults(fn=cmd_validate)

    r = sub.add_parser("report",
                       help="write a self-contained HTML LaTeX-vs-Typst comparison report")
    r.add_argument("stems", nargs="*",
                   help="twin stems (default: twins that failed the last check)")
    r.set_defaults(fn=cmd_report)

    p = sub.add_parser("probe", help="dump a format's dimensions from the bundled class")
    p.add_argument("--format", default="acmsmall")
    p.set_defaults(fn=cmd_probe)

    sub.add_parser("example", help="build the Typst example (template/main.typ)").set_defaults(fn=cmd_example)
    sub.add_parser("list", help="print the test matrix").set_defaults(fn=cmd_list)
    sub.add_parser("clean", help="remove tests/out/").set_defaults(fn=cmd_clean)
    sub.add_parser("metrics", help="print the Tier 2 metric table (no gating)").set_defaults(fn=cmd_metrics)
    sub.add_parser(
        "source-data",
        help="compare transcribed tables with acmart.dtx and ACM-Reference-Format.bst",
    ).set_defaults(fn=cmd_source_data)
    sub.add_parser("sweep", help="compile the representative doc across every format×size").set_defaults(fn=cmd_sweep)
    sub.add_parser("bib-oracle", help="compare the Typst .bib reader with real bibtex (on-demand)").set_defaults(fn=cmd_bib_oracle)
    sub.add_parser("structure", help="report tagged-PDF semantic checks").set_defaults(fn=cmd_structure)
    sub.add_parser("order", help="report the Tier 1.9 per-chunk reading-order check").set_defaults(fn=cmd_order)

    lp = sub.add_parser("linepitch", help="measure baseline pitch / first-line position")
    lp.add_argument("pdf")
    lp.add_argument("--dpi", type=int, default=300)
    lp.add_argument("--page", type=int, default=1)
    lp.set_defaults(fn=cmd_linepitch)

    tx = sub.add_parser("text", help="print a PDF's extracted text exactly as the text gates see it")
    tx.add_argument("pdf")
    tx.add_argument("--page", type=int, help="1-based page (default: the whole document)")
    tx.set_defaults(fn=cmd_text)

    args = ap.parse_args()
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
