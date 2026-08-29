"""Core self-consistency and compile gates.

Matrix integrity, Tier 0 smoke (page counts / parity), the Typst self-golden
raster snapshots, expected compile errors, the unit tests, and the format×size
compile sweep. These lean on the golden file and the compiled PDFs rather than a
cross-engine text comparison."""

from __future__ import annotations

import os
import re
import subprocess
import tempfile
from pathlib import Path

import test_matrix as M
from test_matrix import TESTS
from harness import (
    ROOT, TESTS_DIR, OUT, ERROR, GOLDEN, GOLDEN_FILE, DIFF, TC,
    TEST_CLOCK_ENV, latex_pdf, typst_pdf, compile_typst, default_jobs, _pmap,
)
from pdf_extract import page_count, page_hashes, rasterize, poppler_version


def gate_matrix_integrity(report: bool = False) -> list[str]:
    """Ensure test files, matrix entries, residuals, goldens, and engine agree."""
    failures: list[str] = []
    matrix_twins = {name for name, t in TESTS.items() if t.kind == "twin"}
    matrix_smokes = {name for name, t in TESTS.items() if t.kind == "smoke"}
    typ_twins = {p.stem for p in (TESTS_DIR / "twins").glob("*.typ")
                 if not p.name.startswith("_")}
    tex_twins = {p.stem for p in (TESTS_DIR / "twins").glob("*.tex")
                 if not p.name.startswith("_")}
    typ_smokes = {p.stem for p in (TESTS_DIR / "typst-only").glob("*.typ")
                  if not p.name.startswith("_")}

    comparisons = (
        ("Typst twin files", typ_twins, matrix_twins),
        ("LaTeX twin files", tex_twins, matrix_twins),
        ("Typst-only smoke files", typ_smokes, matrix_smokes),
    )
    for label, actual, expected in comparisons:
        if missing := sorted(expected - actual):
            failures.append(f"matrix: {label} missing {', '.join(missing)}")
        if orphan := sorted(actual - expected):
            failures.append(f"matrix: unregistered {label}: {', '.join(orphan)}")

    for name, t in TESTS.items():
        residual = M.EXPECTED_RESIDUALS.get(name, M.ResidualSignatures())
        for kind, diffs in (("text", t.expected_text_diffs),
                            ("font", t.expected_font_diffs),
                            ("order", t.expected_order_diffs)):
            signature = getattr(residual, kind)
            if diffs and not signature:
                failures.append(f"{name}: expected_{kind}_diffs lacks a residual signature")
            if signature and not diffs:
                failures.append(f"{name}: {kind} residual signature has no expected diff evidence")
    for orphan in sorted(set(M.EXPECTED_RESIDUALS) - set(TESTS)):
        failures.append(f"matrix: residual signature for unknown test {orphan}")
    for label, table in (("expectation", M.METADATA_EXPECTATIONS),
                         ("cross-engine exemption", M.METADATA_CROSS_EXEMPTIONS)):
        for orphan in sorted(set(table) - set(TESTS)):
            failures.append(f"matrix: metadata {label} for unknown test {orphan}")
        for non_twin in sorted(name for name in table
                               if name in TESTS and TESTS[name].kind != "twin"):
            failures.append(f"matrix: metadata {label} belongs to non-twin {non_twin}")
    for label, mapping in (("link", M.EXPECTED_LINK_DIFFS),
                           ("dash", M.EXPECTED_DASH_DIFFS),
                           ("metric", M.EXPECTED_METRIC_DIFFS),
                           ("outline", M.EXPECTED_OUTLINE_DIFFS)):
        for orphan in sorted(set(mapping) - set(TESTS)):
            failures.append(f"matrix: expected {label} residual for unknown test {orphan}")
        for non_twin in sorted(name for name in mapping if name in TESTS and TESTS[name].kind != "twin"):
            failures.append(f"matrix: expected {label} residual belongs to non-twin {non_twin}")
    for name, t in TESTS.items():
        allowances = M.EXPECTED_METRIC_DIFFS.get(name, ())
        if t.expected_metrics_diff and not allowances:
            failures.append(f"{name}: expected_metrics_diff lacks bounded metric allowances")
        if allowances and not t.expected_metrics_diff:
            failures.append(f"{name}: metric allowances lack expected_metrics_diff rationale")
        keys = [(item.page, item.key) for item in allowances]
        if len(keys) != len(set(keys)):
            failures.append(f"{name}: duplicate metric allowance page/key")
        for item in allowances:
            if item.page < 1 or item.key not in (
                    "left", "top", "pitch", "line_pitch", "width", "height"):
                failures.append(f"{name}: invalid metric allowance {item!r}")
            if item.max_delta <= 0:
                failures.append(f"{name}: nonpositive metric allowance {item!r}")

    golden = read_golden()
    expected_golden = {name for name, t in TESTS.items() if not t.golden_exempt}
    if missing := sorted(expected_golden - set(golden)):
        failures.append("matrix: missing golden entries: " + ", ".join(missing))
    if extra := sorted(set(golden) - expected_golden):
        failures.append("matrix: orphan/exempt golden entries: " + ", ".join(extra))

    proc = subprocess.run([str(TC), "--version"], capture_output=True, text=True)
    match = re.search(r"\b(\d+\.\d+\.\d+)\b", proc.stdout + proc.stderr)
    actual_version = match.group(1) if match else None
    if proc.returncode != 0 or actual_version != M.TYPST_VERSION:
        failures.append(
            f"matrix: Typst version is {actual_version!r}, golden header pins {M.TYPST_VERSION!r}")
    if report and not failures:
        print(f"ok   {len(matrix_twins)} twins + {len(matrix_smokes)} smokes; Typst {actual_version}")
    return failures
def gate_smoke(
        compiled: dict[str, tuple[int, str]], names: list[str] | None = None) -> list[str]:
    """Tier 0 — compile cleanliness, page counts, twin page-count parity.

    Uses the already-captured compile results (no recompilation).
    """
    failures: list[str] = []
    items = TESTS.items() if names is None else ((name, TESTS[name]) for name in names)
    for name, t in items:
        rc, stderr = compiled[name]
        local: list[str] = []
        if rc != 0:
            local.append(f"{name}: typst compile failed (rc={rc})\n{stderr.strip()}")
            failures.extend(local)
            continue
        if "warning" in stderr.lower():
            local.append(f"{name}: typst emitted warnings:\n{stderr.strip()}")

        got = page_count(typst_pdf(name))
        if got != t.pages:
            local.append(f"{name}: Typst page count {got} != expected {t.pages}")

        if t.kind == "twin":
            lref = latex_pdf(name, t)
            if lref.exists():
                lp = page_count(lref)
                if lp != got:
                    if not t.expected_page_count_diff:
                        local.append(
                            f"{name}: page-count parity broken (LaTeX {lp} vs Typst {got})")
                elif t.expected_page_count_diff:
                    local.append(
                        f"{name}: expected_page_count_diff is set, but page counts match")
            else:
                local.append(f"{name}: LaTeX reference {lref.name} missing (run `test.py build`)")

        if not local:
            print(f"ok   {name} ({got}p)")
        failures.extend(local)
    return failures
def _golden_hashes() -> dict[str, list[str]]:
    out: dict[str, list[str]] = {}
    for name, t in TESTS.items():
        if t.golden_exempt:
            continue
        pdf = typst_pdf(name)
        if pdf.exists():
            out[name] = page_hashes(pdf, M.GOLDEN_DPI)
    return out


_POPPLER_HEADER = "# poppler:"


def write_golden() -> None:
    GOLDEN.mkdir(parents=True, exist_ok=True)
    hashes = _golden_hashes()
    lines = [
        f"# Tier 1 golden raster hashes — Typst {M.TYPST_VERSION} @ {M.GOLDEN_DPI}dpi",
        "# regenerate with: uv run python tools/test.py accept",
        # Poppler renders the rasters and extracts the text residuals; record it so
        # a divergent local version can be flagged as a possible cause of failure.
        f"{_POPPLER_HEADER} {poppler_version() or 'unknown'}",
    ]
    for name in sorted(hashes):
        for i, h in enumerate(hashes[name], 1):
            lines.append(f"{name} {i} {h}")
    GOLDEN_FILE.write_text("\n".join(lines) + "\n")


def read_golden_poppler() -> str | None:
    """The Poppler version recorded when the goldens were last accepted, if any."""
    if not GOLDEN_FILE.exists():
        return None
    for line in GOLDEN_FILE.read_text().splitlines():
        if line.startswith(_POPPLER_HEADER):
            return line[len(_POPPLER_HEADER):].strip()
    return None


def _poppler_mismatch_note() -> str | None:
    """Diagnostic when the local Poppler differs from the golden's recorded one.

    Per policy a version difference must not fail anything on its own: the golden
    gate downgrades raster mismatches to notes under a divergent Poppler, and the
    other gates append this to failures they already have, to name a likely cause.
    """
    recorded, local = read_golden_poppler(), poppler_version()
    if recorded and local and recorded != local:
        return (f"note: goldens were accepted under Poppler {recorded}, you have "
                f"{local} — a rasterizer/extractor difference may explain this failure")
    return None


def read_golden() -> dict[str, dict[int, str]]:
    out: dict[str, dict[int, str]] = {}
    if not GOLDEN_FILE.exists():
        return out
    for line in GOLDEN_FILE.read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        name, page, h = line.split()
        out.setdefault(name, {})[int(page)] = h
    return out


def gate_golden() -> list[str]:
    """Tier 1 — Typst self-golden raster snapshots."""
    golden = read_golden()
    if not golden:
        return ["no golden file — run `test.py accept` first"]
    cur = _golden_hashes()
    failures: list[str] = []
    # Raster hashes are only reproducible under the Poppler that accepted them; a
    # different Poppler (e.g. a CI distribution's) may re-antialias a hairline. Such
    # page mismatches are reported but do not fail the gate, per the version policy
    # in _poppler_mismatch_note. Missing goldens, unbuilt tests and page-count
    # differences are never a rasterizer artefact and still fail.
    changed: list[str] = []
    for name, t in TESTS.items():
        if t.golden_exempt:
            if golden.get(name):
                failures.append(f"{name}: golden_exempt is set, but golden hashes exist")
            else:
                print(f"skip {name} (golden exempt: {t.golden_exempt})")
            continue
        g, c = golden.get(name), cur.get(name)
        local: list[str] = []
        if g is None:
            local.append(f"{name}: no golden (run `test.py accept`)")
        elif c is None:
            local.append(f"{name}: not built")
        else:
            if len(c) != len(g):
                local.append(f"{name}: page count {len(c)} != golden {len(g)}")
            for i, h in enumerate(c, 1):
                if g.get(i) != h:
                    changed.append(f"{name}: page {i} changed")
                    DIFF.mkdir(parents=True, exist_ok=True)
                    rasterize(typst_pdf(name), M.GOLDEN_DPI, DIFF / f"changed-{name}")
        if not local and not any(line.startswith(f"{name}: ") for line in changed):
            print(f"ok   {name} ({len(c)}p)")
        failures.extend(local)
    note = _poppler_mismatch_note()
    if changed and note:
        for line in changed:
            print(f"note {line}")
        print(f"{note}; raster mismatches are reported, not failed")
    else:
        failures.extend(changed)
    if failures:
        failures.append(f"inspect changed pages in {DIFF.relative_to(ROOT)}/ , "
                        "then `test.py accept` if intended.")
    return failures
def _error_source(extra_arg: str, body: str = "= Body\nText.") -> str:
    # Cases that exercise a bad/other format supply their own `format:` in the
    # extra argument; omit the default acmsmall line then so it is not a duplicate.
    format_line = "" if "format:" in extra_arg else '  format: "acmsmall",\n'
    return f"""#import "/src/lib.typ": *

#show: acmart.with(
{format_line}  title: "Expected Error",
  abstract: [A tiny document.],
  {extra_arg}
)

{body}
"""


def gate_errors() -> list[str]:
    """Tier 1.6 — expected compile-error gate."""
    ERROR.mkdir(parents=True, exist_ok=True)
    failures: list[str] = []
    for name, case in M.ERROR_CASES.items():
        extra, expected = case[0], case[1]
        body = case[2] if len(case) > 2 else "= Body\nText."
        src = ERROR / f"{name}.typ"
        src.write_text(_error_source(extra, body))
        proc = subprocess.run(
            [str(TC), "compile", str(src), str(ERROR / f"{name}.pdf"),
             "--diagnostic-format", "short"],
            capture_output=True, text=True, env={**os.environ, **TEST_CLOCK_ENV},
        )
        diagnostics = proc.stderr + proc.stdout
        if proc.returncode == 0:
            failures.append(f"{name}: expected compile failure, but compile succeeded")
        elif expected not in diagnostics:
            failures.append(
                f"{name}: expected diagnostic containing {expected!r}, got:\n{diagnostics.strip()}")
        else:
            print(f"ok   {name}")
    return failures
# A single representative document (title + author + abstract + section + list +
# table + inline/display math + footnote) rendered across every format×size in
# the sweep. `{extra}` injects per-format required options (acmcp's logo).
_SWEEP_DOC = '''#import "/src/lib.typ": acmart
#show: acmart.with(
  format: "{fmt}",
  font-size: {size}pt,
{extra}  title: "Format Sweep",
  authors: (
    (name: "Ben Trovato", email: "trovato@corporation.com",
     affiliation: (institution: "Institute for Clarity", city: "Dublin", country: "USA")),
  ),
  abstract: [A short abstract used to exercise the frontmatter across formats.],
  keywords: ("datasets", "typesetting"),
)

= Introduction
Body text with an inline formula $a + b = c$ and a footnote.#footnote[A note.]
A display equation follows:
$ sum_(i = 0)^n x_i = y $

- first item
- second item

#table(columns: 2, [Head A], [Head B], [1], [2])
'''

_SWEEP_EXTRA = {
    "acmcp": '  acmcp-logo: image("/src/assets/acm-jdslogo.png"),\n',
}


def gate_format_sweep(report: bool = False) -> list[str]:
    """Tier 0.8 — compile one representative document across every active
    format × allowed base size (45 combos), failing on any error or warning.
    No goldens: this is a cheap breadth net for the size-ladder / per-format
    geometry paths the single-size twins don't each visit."""
    combos = [(fmt, size) for fmt in M.ACTIVE_FORMATS for size in M.SWEEP_FONT_SIZES]
    # tc pins --root at the repo, so the source must live under it (not /tmp).
    sweep_dir = OUT / "sweep"
    sweep_dir.mkdir(parents=True, exist_ok=True)

    def compile_combo(combo: tuple[str, int]) -> tuple[tuple[str, int], tuple[int, str]]:
        fmt, size = combo
        source = _SWEEP_DOC.format(fmt=fmt, size=size, extra=_SWEEP_EXTRA.get(fmt, ""))
        src = sweep_dir / f"{fmt}-{size}.typ"
        src.write_text(source)
        return combo, compile_typst(src, sweep_dir / f"{fmt}-{size}.pdf")

    failures: list[str] = []
    for (fmt, size), (rc, stderr) in _pmap(compile_combo, combos, default_jobs()):
        if rc != 0:
            failures.append(f"{fmt} @ {size}pt: compile failed (rc={rc})\n{stderr.strip()}")
        elif "warning" in stderr.lower():
            failures.append(f"{fmt} @ {size}pt: Typst emitted warnings:\n{stderr.strip()}")
        elif report:
            print(f"ok   {fmt} @ {size}pt")
    return failures
def gate_unit(report: bool = False) -> list[str]:
    """Tier 0.5 — pure-Typst unit tests (tests/unit/*.typ). These import a module
    and assert on its output via #assert.eq, so a failure aborts the compile with
    a diagnostic. No LaTeX/pdftotext involved — they test parsing/logic directly.
    """
    failures: list[str] = []
    unit_dir = TESTS_DIR / "unit"
    srcs = sorted(unit_dir.glob("*.typ")) if unit_dir.is_dir() else []
    for src in srcs:
        with tempfile.TemporaryDirectory() as td:
            rc, stderr = compile_typst(src, Path(td) / "out.pdf")
        if rc != 0:
            failures.append(f"{src.name}: assertion/compile failure\n{stderr.strip()}")
        elif report:
            print(f"ok   {src.name}")
    if report and not srcs:
        print("(no tests/unit/*.typ found)")
    return failures
