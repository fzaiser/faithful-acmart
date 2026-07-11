"""Shared foundation for the typst-acmart harness.

Paths and generated-output locations, the pinned regression clock, Typst
compilation via ``tc``, and the small thread-parallel map. Every other harness
module imports from here; this module imports only the test matrix and stdlib,
so it sits at the bottom of the dependency graph."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

from test_matrix import TESTS, Test


ROOT = Path(__file__).resolve().parent.parent
TOOLS = ROOT / "tools"
TESTS_DIR = ROOT / "tests"
OUT = TESTS_DIR / "out"
LATEX = OUT / "latex"
TYPST = OUT / "typst"
DIFF = OUT / "diff"
ERROR = OUT / "error"
GOLDEN = TESTS_DIR / "golden"
GOLDEN_FILE = GOLDEN / "typst.sha256"
TC = TOOLS / "tc"
ACMART = ROOT / "acmart"
TEMPLATE = ROOT / "template" / "main.typ"

# Pin TeX's \year/\month and Typst's datetime.today() for regression builds.
# July keeps upstream proceedings samples that omit \acmMonth faithful to the
# current cached LaTeX oracle while making that default deterministic.
TEST_SOURCE_DATE_EPOCH = "1782907200"  # 2026-07-01 12:00:00 UTC
TEST_CLOCK_ENV = {
    "SOURCE_DATE_EPOCH": TEST_SOURCE_DATE_EPOCH,
    "FORCE_SOURCE_DATE": "1",
}


# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------
def latex_pdf(name: str, _t: Test) -> Path:
    return LATEX / f"{name}.pdf"


def typst_pdf(name: str) -> Path:
    return TYPST / f"{name}.pdf"
def _compile_failures(compiled: dict[str, tuple[int, str]]) -> list[str]:
    failures = []
    for name, (rc, stderr) in compiled.items():
        if rc != 0:
            detail = stderr.strip()
            failures.append(f"{name} (rc={rc})" + (f": {detail}" if detail else ""))
    return failures
# ---------------------------------------------------------------------------
# Typst compilation
# ---------------------------------------------------------------------------
def compile_typst(src: Path, out: Path) -> tuple[int, str]:
    """Compile a .typ via tc; return (returncode, stderr). Captures warnings."""
    out.parent.mkdir(parents=True, exist_ok=True)
    out.unlink(missing_ok=True)
    proc = subprocess.run(
        [str(TC), "compile", str(src), str(out), "--diagnostic-format", "short"],
        capture_output=True, text=True,
        env={**os.environ, **TEST_CLOCK_ENV},
    )
    if proc.returncode != 0:
        out.unlink(missing_ok=True)
    return proc.returncode, proc.stderr


def compile_all_typst(names: list[str] | None = None) -> dict[str, tuple[int, str]]:
    """Compile selected tests (all by default) once into tests/out/typst/.

    Returns {name: (returncode, stderr)} so the smoke gate can inspect warnings
    without recompiling.
    """
    TYPST.mkdir(parents=True, exist_ok=True)
    items = list(TESTS.items()) if names is None else [(name, TESTS[name]) for name in names]

    def compile_one(item: tuple[str, Test]) -> tuple[str, tuple[int, str]]:
        name, t = item
        return name, compile_typst(TESTS_DIR / t.subdir / f"{name}.typ", typst_pdf(name))

    return dict(_pmap(compile_one, items, default_jobs()))
def default_jobs() -> int:
    """Parallel LaTeX jobs to use by default: leave 2 cores free so a full build
    doesn't hog the machine (matches the repo's Workflow concurrency convention)."""
    return max(1, (os.cpu_count() or 2) - 2)


def _pmap(fn, items: list, jobs: int) -> list:
    """Map ``fn`` over ``items``, up to ``jobs`` at a time. Serial (and easier to
    debug) when ``jobs <= 1``. ``fn`` runs subprocesses, which release the GIL, so
    threads give real parallelism without the pickling cost of processes."""
    if jobs <= 1 or len(items) <= 1:
        return [fn(x) for x in items]
    from concurrent.futures import ThreadPoolExecutor
    with ThreadPoolExecutor(max_workers=jobs) as ex:
        return list(ex.map(fn, items))
