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
  accept           rebuild Typst PDFs and refresh the Tier 1 golden hashes
  overlay [stems]  per-twin vector <name>-overlay.pdf + <name>-side-by-side.pdf vs LaTeX (all twins, or given stems)
  validate [names] copyright/option variants vs LaTeX, page-1 mismatch %
  probe            dump a format's ground-truth dimensions from the bundled class (--format)
  example          build the Typst example (template/main.typ)
  list             print the test matrix
  clean            remove all generated output (tests/out/)
  metrics          print the Tier 2 layout-metric table for every page (no gating)
  structure        report tagged-PDF roles, language, and image alternatives
  source-data      compare transcribed tables with bundled acmart.dtx and ACM-Reference-Format.bst
  linepitch FILE   measure baseline pitch / first-line position in a PDF (--dpi, --page)

External tools required: Typst, TeX Live (pdflatex, bibtex, pdfjam), Poppler
(pdftoppm, pdftotext, pdfinfo), qpdf, and — for the `overlay` command —
Ghostscript (gs). All generated output lives under tests/out/ (gitignored).
"""

from __future__ import annotations

import argparse
import difflib
import functools
import hashlib
import json
import os
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
import threading
import tomllib
import unicodedata
from collections import Counter
from pathlib import Path

import test_matrix as M
from pdf_text_tokens import CHAR_FOLD, bag_coverage, char_bag, dash_bag, normalize
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


# ---------------------------------------------------------------------------
# PDF / raster helpers (Poppler)
# ---------------------------------------------------------------------------
# Per-run extraction memo: threaded through the `check` gates so each PDF is
# parsed once (pdftotext / pikepdf / PyMuPDF are the run's dominant cost) instead
# of once per gate. Keyed on path + mtime so a rebuilt PDF is never served stale.
_EXTRACT_CACHE: dict[tuple, object] = {}


def _pdf_memo(fn):
    """Cache an extractor's result per (function, pdf path, mtime, extra args)."""
    @functools.wraps(fn)
    def wrapped(pdf, *args, **kwargs):
        try:
            stamp = Path(pdf).stat().st_mtime_ns
        except OSError:
            stamp = None
        key = (fn.__name__, str(pdf), stamp, args, tuple(sorted(kwargs.items())))
        if key not in _EXTRACT_CACHE:
            _EXTRACT_CACHE[key] = fn(pdf, *args, **kwargs)
        return _EXTRACT_CACHE[key]
    return wrapped


def poppler_version() -> str | None:
    """Local Poppler version behind pdftotext/pdftoppm (one package, one version).

    Both the raster goldens (pdftoppm) and the text residual digests (pdftotext)
    ride on it, so recording a single number in the golden header covers both.
    """
    proc = subprocess.run(["pdftotext", "-v"], capture_output=True, text=True)
    m = re.search(r"version\s+([\d.]+)", proc.stdout + proc.stderr)
    return m.group(1) if m else None


def page_count(pdf: Path) -> int:
    out = subprocess.run(["pdfinfo", str(pdf)], capture_output=True, text=True).stdout
    m = re.search(r"^Pages:\s+(\d+)", out, re.M)
    return int(m.group(1)) if m else -1


@_pdf_memo
def pdf_info(pdf: Path) -> dict[str, str]:
    """Poppler document-information fields as a simple name/value mapping."""
    proc = subprocess.run(["pdfinfo", str(pdf)], capture_output=True, text=True)
    if proc.returncode != 0:
        return {}
    return {
        key.strip(): value.strip()
        for line in proc.stdout.splitlines()
        if ":" in line
        for key, value in (line.split(":", 1),)
    }


def rasterize(pdf: Path, dpi: int, prefix: Path) -> list[Path]:
    subprocess.run(
        ["pdftoppm", "-r", str(dpi), "-png", str(pdf), str(prefix)],
        check=True, capture_output=True,
    )
    return sorted(prefix.parent.glob(prefix.name + "-*.png"))


def page_hashes(pdf: Path, dpi: int) -> list[str]:
    # Own temp dir per call: pdftoppm pads page numbers by total page count, so a
    # shared dir would let a previous PDF's PNGs leak into this one's glob.
    with tempfile.TemporaryDirectory() as td:
        pngs = rasterize(pdf, dpi, Path(td) / "ras")
        return [hashlib.sha256(p.read_bytes()).hexdigest() for p in pngs]


_PAGE_RE = re.compile(r'<page width="([\d.]+)" height="([\d.]+)"')
_WORD_RE = re.compile(
    r'<word xMin="([\d.]+)" yMin="([\d.]+)" xMax="([\d.]+)" yMax="([\d.]+)">(.*?)</word>'
)


@_pdf_memo
def words(pdf: Path) -> dict:
    """1-based page index -> {w, h, words:[(x0,y0,x1,y1,text), ...]} via pdftotext -bbox."""
    out = subprocess.run(
        ["pdftotext", "-bbox", str(pdf), "-"], capture_output=True, text=True
    ).stdout
    pages: dict = {}
    n = 0
    for line in out.splitlines():
        pm = _PAGE_RE.search(line)
        if pm:
            n += 1
            pages[n] = {"w": float(pm.group(1)), "h": float(pm.group(2)), "words": []}
            continue
        wm = _WORD_RE.search(line)
        if wm and n:
            x0, y0, x1, y1 = (float(v) for v in wm.groups()[:4])
            pages[n]["words"].append((x0, y0, x1, y1, wm.group(5)))
    return pages


def page_metrics(page: dict) -> dict | None:
    """Layout geometry for one page: text-block margins, line count, baseline pitch."""
    ws = page["words"]
    if not ws:
        return None
    left = min(w[0] for w in ws)
    right = page["w"] - max(w[2] for w in ws)
    top = min(w[1] for w in ws)
    # Cluster word tops into lines: a new line starts when the gap exceeds 2pt.
    ys = sorted(w[1] for w in ws)
    line_tops = [ys[0]]
    for y in ys[1:]:
        if y - line_tops[-1] > 2.0:
            line_tops.append(y)
    gaps = [b - a for a, b in zip(line_tops, line_tops[1:])]
    pitch = statistics.median(gaps) if gaps else 0.0
    # Per-line text pitches: drop page-spanning gaps (the last body line -> page
    # footer is a ~400pt jump, not a baseline pitch). Heading skips (~1.5-2x the
    # body pitch) are kept, so two single-column pages whose lines break the same
    # way can be compared pitch-for-pitch, catching a single mis-spaced line that
    # the median hides.
    grid = [g for g in gaps if g <= 3 * pitch] if pitch else []
    return {"left": left, "right": right, "top": top, "lines": len(line_tops),
            "pitch": pitch, "pitches": grid}


@_pdf_memo
def pdf_text(pdf: Path, page: int | None = None) -> str:
    cmd = ["pdftotext"]
    if page is not None:
        cmd += ["-f", str(page), "-l", str(page)]
    cmd += [str(pdf), "-"]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or f"pdftotext failed for {pdf}")
    return proc.stdout


@_pdf_memo
def extract_uris(pdf: Path) -> Counter[str]:
    """External hyperlink annotation targets, preserving multiplicity."""
    try:
        import pikepdf
    except ImportError as exc:
        raise RuntimeError("pikepdf is required for the hyperlink gate") from exc
    found: Counter[str] = Counter()
    with pikepdf.open(pdf) as doc:
        for page in doc.pages:
            for annotation in page.get("/Annots", []) or []:
                action = annotation.get("/A")
                if action is not None and action.get("/S") == "/URI" and "/URI" in action:
                    found[str(action["/URI"])] += 1
    return found


@_pdf_memo
def extract_internal_links(pdf: Path) -> dict:
    """Internal PDF link summary, normalized across named and direct destinations.

    LaTeX/hyperref usually writes named /GoTo actions; Typst writes direct /Dest
    arrays. Destination names are engine-specific, so the gate compares counts and
    normalized target coverage instead of raw names.
    """
    try:
        import pikepdf
    except ImportError as exc:
        raise RuntimeError("pikepdf is required for the internal-link gate") from exc

    def walk_dest_names(node, out: dict[str, object]) -> None:
        if "/Names" in node:
            names = list(node["/Names"])
            for i in range(0, len(names), 2):
                out[str(names[i])] = names[i + 1]
        for kid in node.get("/Kids", []) or []:
            walk_dest_names(kid, out)

    def dest_name(value) -> str:
        name = str(value)
        return name[1:] if name.startswith("/") else name

    def resolve_dest(value, dests: dict[str, object]):
        if value is None:
            return None
        if isinstance(value, (pikepdf.String, pikepdf.Name)):
            value = dests.get(dest_name(value))
            if value is None:
                return None
        return value.get("/D", value) if hasattr(value, "get") else value

    def normalize_dest(value, dests: dict[str, object], page_by_objgen: dict) -> tuple | None:
        dest = resolve_dest(value, dests)
        if dest is None:
            return None
        try:
            page = page_by_objgen.get(dest[0].objgen)
        except (AttributeError, IndexError, TypeError):
            return None
        if page is None:
            return None
        coords = []
        for part in list(dest)[1:5]:
            try:
                coords.append(round(float(part), 1))
            except (TypeError, ValueError):
                coords.append(str(part))
        return (page, *coords)

    with pikepdf.open(pdf) as doc:
        page_by_objgen = {page.objgen: i for i, page in enumerate(doc.pages, 1)}
        dests: dict[str, object] = {}
        names = doc.Root.get("/Names")
        if names and "/Dests" in names:
            walk_dest_names(names["/Dests"], dests)
        root_dests = doc.Root.get("/Dests")
        if root_dests:
            for key, value in root_dests.items():
                dests[dest_name(key)] = value

        links: list[tuple[int, tuple]] = []
        for src_page, page in enumerate(doc.pages, 1):
            for annot in page.get("/Annots", []) or []:
                if annot.get("/Subtype") != "/Link":
                    continue
                dest = None
                action = annot.get("/A")
                if action and str(action.get("/S")) == "/GoTo":
                    dest = action.get("/D")
                elif "/Dest" in annot:
                    dest = annot.get("/Dest")
                normalized = normalize_dest(dest, dests, page_by_objgen)
                if normalized is not None:
                    links.append((src_page, normalized))

    return {
        "count": len(links),
        "unique_targets": len({target for _, target in links}),
        "pages": len(doc.pages),
        # Multiset of resolved target page numbers (previously computed then
        # discarded). Cross-engine equality against LaTeX is deliberately NOT
        # gated: measured across the twin set the two engines' internal-link
        # target-page multisets diverge broadly and legitimately — hyperref emits
        # more internal links than Typst (section \autoref backrefs, author-year
        # multi-\cite), and on multi-page docs pagination drifts (the documented
        # \flushbottom/ragged-bottom difference). So a cross-engine comparison
        # would need a per-twin exemption the size of the divergence; the outline
        # gate owns cross-engine SECTION target pages (page-1 anchored), and this
        # multiset instead feeds a Typst-side validity check (targets in range).
        "target_pages": Counter(target[0] for _, target in links),
    }


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


# ---------------------------------------------------------------------------
# LaTeX build (ported from latex-build.sh / build-reference.sh)
# ---------------------------------------------------------------------------
# Every non-system LaTeX input bundled for this audit is staged beside acmart.cls
# so TeX cannot silently select a different TeX Live version. Keys are the names
# TeX resolves; values are the authoritative repository copies.
PINNED_LATEX_INPUTS: dict[str, Path] = {
    "ACM-Reference-Format.bst": ACMART / "ACM-Reference-Format.bst",
    "acm-jdslogo.png": ACMART / "acm-jdslogo.png",
    "acmnumeric.bbx": ACMART / "acmnumeric.bbx",
    "acmnumeric.cbx": ACMART / "acmnumeric.cbx",
    "acmauthoryear.bbx": ACMART / "acmauthoryear.bbx",
    "acmauthoryear.cbx": ACMART / "acmauthoryear.cbx",
    "acmdatamodel.dbx": ACMART / "acmdatamodel.dbx",
    "amsart.cls": ACMART / "deps" / "amsart.cls",
    "software.bbx": ACMART / "deps" / "biblatex-software" / "software.bbx",
    "software.dbx": ACMART / "deps" / "biblatex-software" / "software.dbx",
    "english-software.lbx": ACMART / "deps" / "biblatex-software" / "english-software.lbx",
}

# The macOS Biber executable self-extracts into a shared PAR cache. Concurrent
# first-use processes race while renaming the same `biber.lipo` temporary file,
# so serialize this one tool while leaving pdflatex/BibTeX work parallel.
_BIBER_LOCK = threading.Lock()


def _sync_file(src: Path, dst: Path) -> None:
    """Copy src only when bytes differ, preserving useful output mtimes."""
    data = src.read_bytes()
    if not dst.exists() or dst.read_bytes() != data:
        dst.write_bytes(data)


# pdflatex/bibtex may write non-UTF-8 font names to stdout. Capture them
# decode-tolerantly, but never discard the return code.
def _quiet(cmd: list[str], **kw) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, capture_output=True, text=True, errors="replace", **kw)


def _run_latex_tool(cmd: list[str], *, label: str, **kw) -> None:
    proc = _quiet(cmd, **kw)
    if proc.returncode != 0:
        detail = (proc.stderr + "\n" + proc.stdout).strip()
        if len(detail) > 4000:
            detail = detail[-4000:]
        raise RuntimeError(f"{label} failed with exit status {proc.returncode}\n{detail}")


def _pdflatex(tex_basename: str, srcdir: Path, outdir: Path, env: dict) -> None:
    _run_latex_tool(
        ["pdflatex", "-interaction=nonstopmode", f"-output-directory={outdir}",
         str(srcdir / tex_basename)],
        label=f"pdflatex {tex_basename}", env=env, cwd=outdir,
    )


def ensure_class(outdir: Path) -> None:
    """Generate acmart.cls (and bundled assets) into outdir from acmart/ sources.

    Always builds against the BUNDLED acmart class, never the system one — the two
    can differ (e.g. section-title uppercasing). Regenerated if missing or stale.
    """
    outdir.mkdir(parents=True, exist_ok=True)
    cls = outdir / "acmart.cls"
    dtx = ACMART / "acmart.dtx"
    ins = ACMART / "acmart.ins"
    if not cls.exists() or max(dtx.stat().st_mtime, ins.stat().st_mtime) > cls.stat().st_mtime:
        for f in ("acmart.ins", "acmart.dtx"):
            (outdir / f).write_bytes((ACMART / f).read_bytes())
        _run_latex_tool(["pdflatex", "-interaction=nonstopmode", "acmart.ins"],
                        label="docstrip acmart.cls", cwd=outdir)
    for name, src in PINNED_LATEX_INPUTS.items():
        _sync_file(src, outdir / name)


_RERUN_RE = re.compile(
    r"Rerun to get|Label\(s\) may have changed|Temporary (?:extra )?page|"
    r"There were undefined references|Please \(re\)run Biber|Please rerun LaTeX",
    re.I,
)


def _latex_rerun_needed(logtext: str) -> bool:
    return _RERUN_RE.search(logtext) is not None


def _latex_final_problems(logtext: str) -> list[str]:
    patterns = (
        (r"(?m)^! |Emergency stop|Fatal error occurred|No output PDF file produced",
         "LaTeX reported an error"),
        (r"Citation [`'].+?[`'] .*undefined|There were undefined citations",
         "undefined citation remains"),
        (r"Reference [`'].+?[`'] .*undefined|There were undefined references",
         "undefined reference remains"),
        (r"Please \(re\)run Biber|Please rerun LaTeX", "bibliography rerun remains"),
    )
    return [message for pattern, message in patterns if re.search(pattern, logtext, re.I)]


def latex_build(tex: Path, outdir: Path = LATEX) -> int:
    """Compile a .tex to a STABLE PDF in outdir; return its page count.

    Reruns pdflatex until cross-references / TotPages settle, runs bibtex or
    biber (auto-detected from the source), and fails if a 'Temporary page'
    placeholder survives or LaTeX reports an error.
    """
    outdir.mkdir(parents=True, exist_ok=True)
    ensure_class(outdir)
    srcdir = tex.resolve().parent
    base = tex.stem
    source = tex.read_text(errors="replace")
    use_biber = re.search(
        r"\\(?:RequirePackage|usepackage)(?:\[[^]]*\])?\{biblatex\}", source, re.S,
    ) is not None

    env = {
        **os.environ,
        **TEST_CLOCK_ENV,
        # acmart.cls in outdir must win over any system install; srcdir carries
        # the twin's own bib/image assets (sample-base.bib, sample-franklin.png…).
        "TEXINPUTS": f"{outdir}:{srcdir}:",
        "BIBINPUTS": f"{outdir}:{srcdir}:",
    }

    _pdflatex(f"{base}.tex", srcdir, outdir, env)
    if use_biber:
        with _BIBER_LOCK:
            _run_latex_tool(["biber", base], label=f"biber {base}", cwd=outdir, env=env)
        blg = outdir / f"{base}.blg"
        if blg.exists() and re.search(r"(?m)^.*ERROR -", blg.read_text(errors="replace")):
            raise RuntimeError(f"biber {base} reported an error (see {blg})")
    else:
        aux = outdir / f"{base}.aux"
        # Most layout twins have no bibliography. Running BibTeX unconditionally
        # used to create a failing .blg that the harness then ignored.
        if aux.exists() and "\\bibdata" in aux.read_text(errors="replace"):
            _run_latex_tool(["bibtex", base], label=f"bibtex {base}", cwd=outdir, env=env)
    _pdflatex(f"{base}.tex", srcdir, outdir, env)

    log = outdir / f"{base}.log"
    for _ in range(6):
        text = log.read_text(errors="replace") if log.exists() else ""
        if _latex_rerun_needed(text):
            _pdflatex(f"{base}.tex", srcdir, outdir, env)
        else:
            break

    pdf = outdir / f"{base}.pdf"
    if not pdf.exists():
        raise SystemExit(f"ERROR: {pdf} was not produced (see {log}).")
    logtext = log.read_text(errors="replace") if log.exists() else ""
    problems = _latex_final_problems(logtext)
    if _latex_rerun_needed(logtext):
        problems.append("reference/page state did not converge within six reruns")
    if problems:
        raise SystemExit(f"ERROR: {base}: {'; '.join(dict.fromkeys(problems))} (see {log}).")
    if "Temporary page" in pdf_text(pdf):
        raise SystemExit(f"ERROR: {pdf} still contains a 'Temporary page'.")
    return page_count(pdf)



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


# The LaTeX references are a pure function of their sources. A reference PDF is
# fresh if it is newer than its own .tex AND newer than every shared input that
# could change its output: the class source, bundled assets/bst, and twin
# bib/image/PDF assets. This deliberately over-invalidates because correctness
# beats precision here. `--force` bypasses it entirely.
_shared_inputs_mtime_cache: float | None = None


def _shared_inputs_mtime() -> float:
    global _shared_inputs_mtime_cache
    if _shared_inputs_mtime_cache is None:
        paths = [
            ACMART / "acmart.dtx",
            ACMART / "acmart.ins",
            *PINNED_LATEX_INPUTS.values(),
        ]
        for pattern in ("*.bib", "*.png", "*.jpg", "*.jpeg", "*.pdf"):
            paths += list((TESTS_DIR / "twins").glob(pattern))
        _shared_inputs_mtime_cache = max(
            (p.stat().st_mtime for p in paths if p.exists()), default=0.0)
    return _shared_inputs_mtime_cache


def ref_is_fresh(tex: Path, pdf: Path) -> bool:
    """True if ``pdf`` is up to date with ``tex`` and all shared LaTeX inputs."""
    if not pdf.exists() or not tex.exists():
        return False
    return pdf.stat().st_mtime >= max(tex.stat().st_mtime, _shared_inputs_mtime())


def gate_latex_oracle(report: bool = False) -> list[str]:
    """Verify the reference directory contains the exact vendored dependencies.

    The actual LaTeX builds exercise command-status and convergence checking; the
    canned strings below keep the diagnostic recognizers themselves covered.
    """
    failures: list[str] = []
    ensure_class(LATEX)
    for name, source in PINNED_LATEX_INPUTS.items():
        staged = LATEX / name
        if not staged.exists():
            failures.append(f"LaTeX oracle: missing staged {name}")
        elif staged.read_bytes() != source.read_bytes():
            failures.append(f"LaTeX oracle: staged {name} differs from {source.relative_to(ROOT)}")
        elif report:
            print(f"ok   {name}: {source.relative_to(ROOT)}")

    rerun_examples = (
        "LaTeX Warning: Label(s) may have changed. Rerun to get cross-references right.",
        "LaTeX Warning: There were undefined references.",
        "Package biblatex Warning: Please (re)run Biber on the file.",
        "LaTeX Warning: Temporary extra page added at the end.",
    )
    for example in rerun_examples:
        if not _latex_rerun_needed(example):
            failures.append(f"LaTeX oracle: rerun recognizer missed {example!r}")
    if _latex_rerun_needed("Output written on stable.pdf (1 page)."):
        failures.append("LaTeX oracle: stable log incorrectly requests a rerun")
    if "undefined reference remains" not in _latex_final_problems(
            "LaTeX Warning: There were undefined references."):
        failures.append("LaTeX oracle: final undefined-reference diagnostic was not recognized")
    return failures


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


def _compact_tex_text(value: str) -> str:
    """Normalize whitespace-only TeX source formatting in literal data fields."""
    return re.sub(r"\s+", " ", value.replace("~", " ").replace(r"\&", "&")).strip()


def _latex_journal_records() -> dict[str, dict]:
    """Extract the journal choice arms directly from the bundled acmart.dtx."""
    source = (ACMART / "acmart.dtx").read_text()
    start = source.index(r"\ifcase\@journalCode@nr", source.index("{acmJournal}"))
    end = source.index(r"\else % FACMP", start)
    choice = source[start:end]
    records: dict[str, dict] = {}
    arms = re.finditer(
        r"(?:\\relax|\\or)\s*%\s*([A-Z0-9]+)\s*(.*?)"
        r"(?=(?:\\or)\s*%|\Z)",
        choice,
        re.S,
    )
    for match in arms:
        code, body = match.groups()

        def field(macro: str) -> str | None:
            found = re.search(rf"\\def\\{re.escape(macro)}\{{(.*?)\}}%", body, re.S)
            return _compact_tex_text(found.group(1)) if found else None

        records[code] = {
            "name": field("@journalName"),
            "short": field("@journalNameShort"),
            "issn": field("@permissionCodeTwo") or field("@permissionCodeOne"),
            "screen": r"\@ACM@screentrue" in body,
        }
    return records


def _typst_journal_records() -> dict[str, dict]:
    """Extract the intentionally regular one-record-per-line Typst table."""
    records: dict[str, dict] = {}
    pattern = re.compile(
        r'^\s*([A-Z0-9]+): \(name: "([^"]*)", short: "([^"]*)", '
        r'issn: "([^"]*)"(, screen: true)?\),$',
        re.M,
    )
    for code, name, short, issn, screen in pattern.findall(
            (ROOT / "src" / "parts" / "journals.typ").read_text()):
        records[code] = {
            "name": name, "short": short, "issn": issn, "screen": bool(screen),
        }
    return records


def _typst_table_body(source: str, variable: str) -> str:
    found = re.search(
        rf"(?s)^#let {re.escape(variable)} = \((.*?)\)", source, re.M)
    if not found:
        raise ValueError(f"could not find Typst table {variable}")
    return found.group(1)


def _typst_mapping_keys(source: str, variable: str) -> set[str]:
    body = _typst_table_body(source, variable)
    pairs = re.findall(
        r'(?:^|,)\s*(?:"([^"]+)"|([A-Za-z][A-Za-z0-9-]*))\s*:', body)
    return {quoted or bare for quoted, bare in pairs}


def _typst_tuple_strings(source: str, variable: str) -> set[str]:
    return set(re.findall(r'"([^"]*)"', _typst_table_body(source, variable)))


_QUOTED_STRING = r'"((?:\\.|[^"\\])*)"'


def _unique_mapping(pairs: list[tuple[str, str]], label: str) -> dict[str, str]:
    """Turn parsed key/value pairs into a map while rejecting hidden duplicates."""
    result: dict[str, str] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate {label} key {key!r}")
        result[key] = value
    return result


def _latex_bib_data() -> dict[str, dict[str, str]]:
    """Extract the journal macro and canonical-abbreviation tables from the BST."""
    source = (ACMART / "ACM-Reference-Format.bst").read_text()

    macro_start = source.index("%%% ACM journal names")
    macro_end = source.index("\nREAD", macro_start)
    macro_source = source[macro_start:macro_end]
    macro_pairs = [
        (key.strip(), value)
        for key, value in re.findall(
            rf"MACRO\s*\{{\s*([^}}]+?)\s*\}}\s*\{{\s*{_QUOTED_STRING}\s*\}}",
            macro_source,
            re.S,
        )
    ]
    macro_declarations = len(re.findall(r"\bMACRO\s*\{", macro_source))
    if len(macro_pairs) != macro_declarations:
        raise ValueError(
            "parsed only " + str(len(macro_pairs)) + " of "
            + str(macro_declarations) + " journal MACRO declarations")

    canon_start = source.index("FUNCTION { journal.canon.abbrev }")
    canon_end = source.index("FUNCTION { format.journal.volume.number.day.month.year }", canon_start)
    canon_source = source[canon_start:canon_end]
    canon_pairs = re.findall(
        rf"^\s*journal\s+{_QUOTED_STRING}\s*=\s*\{{\s*{_QUOTED_STRING}\s*\}}\s*\{{",
        canon_source,
        re.M,
    )
    canon_declarations = len(re.findall(r'^\s*journal\s+"', canon_source, re.M))
    if len(canon_pairs) != canon_declarations:
        raise ValueError(
            "parsed only " + str(len(canon_pairs)) + " of "
            + str(canon_declarations) + " journal.canon.abbrev arms")

    return {
        "journal-macros": _unique_mapping(macro_pairs, "BST journal macro"),
        "journal-canon": _unique_mapping(canon_pairs, "BST canonical abbreviation"),
    }


def _typst_string_mapping(source: str, variable: str) -> dict[str, str]:
    """Parse a regular quoted-string Typst mapping without evaluating Typst."""
    marker = f"#let {variable} = ("
    start = source.index(marker) + len(marker)
    end_match = re.search(r"^\)\s*$", source[start:], re.M)
    if end_match is None:
        raise ValueError(f"could not find end of Typst table {variable}")
    body = source[start:start + end_match.start()]
    pairs = re.findall(
        rf"^\s*{_QUOTED_STRING}\s*:\s*{_QUOTED_STRING}\s*,\s*$",
        body,
        re.M,
    )
    declarations = len(re.findall(r'^\s*"', body, re.M))
    if len(pairs) != declarations:
        raise ValueError(
            f"parsed only {len(pairs)} of {declarations} entries in Typst table {variable}")
    return _unique_mapping(pairs, f"Typst {variable}")


def _typst_bib_data() -> dict[str, dict[str, str]]:
    source = (ROOT / "src" / "parts" / "bib-data.typ").read_text()
    return {
        "journal-macros": _typst_string_mapping(source, "journal-macros"),
        "journal-canon": _typst_string_mapping(source, "journal-canon"),
    }


# --- Copyright / permission source-data oracle -----------------------------
#
# The first-page copyright block's permission paragraph and owner string for all
# 16 \setcopyright modes, plus the Creative Commons name/version/URL tables, are
# transcribed into src/parts/copyright.typ. These helpers reparse them out of the
# bundled acmart.dtx and out of the Typst source so the gate can diff both — the
# same parse-the-dtx-and-diff mechanism used for the journal choice table.

def _fold_quotes(text: str) -> str:
    return (text.replace("’", "'").replace("‘", "'")
                .replace("“", '"').replace("”", '"'))


def _normalize_dtx_copyright(text: str) -> str:
    """Reduce a dtx \\ifcase arm to comparable plain text (TeX stripped)."""
    text = re.sub(r"%.*", "", text)                 # drop label + line-cont comments
    text = text.replace(r"\hspace*{.5pt}", "")      # thin-space slash kern
    text = text.replace(r"\@", "")                  # sentence-spacing hint
    text = text.replace("~", " ").replace(r"\&", "&")
    return re.sub(r"\s+", " ", _fold_quotes(text)).strip()


def _normalize_typst_copyright(value: str) -> str | None:
    """Reduce a Typst `_mode(...)` argument (`none` or `[content]`) to plain text."""
    if value == "none":
        return None
    inner = value.strip()[1:-1]                     # strip the [ ] content brackets
    inner = inner.replace(r"\/", "/").replace(r"\@", "@").replace(r"\&", "&")
    return re.sub(r"\s+", " ", _fold_quotes(inner)).strip()


def _dtx_copyright_modes() -> list[str]:
    """The authoritative ordered mode names from the \\define@choicekey list."""
    source = (ACMART / "acmart.dtx").read_text()
    match = re.search(r"\]\{none,%\s*(.*?)\}\{%", source, re.S)
    body = re.sub(r"%", "", "none," + match.group(1))
    return [token.strip() for token in body.split(",") if token.strip()]


def _dtx_ifcase_arms(macro: str) -> list[str]:
    """Split a `\\def\\<macro>{\\ifcase\\acm@copyrightmode ...}` into its arms."""
    source = (ACMART / "acmart.dtx").read_text()
    start = source.index(r"\ifcase\acm@copyrightmode\relax", source.index("\\def\\" + macro + "{"))
    block = source[start:source.index(r"\fi}", start)]
    block = block[len(r"\ifcase\acm@copyrightmode\relax"):]
    return block.split(r"\or")


def _latex_copyright_data() -> dict[str, object]:
    modes = _dtx_copyright_modes()
    owner_arms = _dtx_ifcase_arms("@copyrightowner")
    perm_arms = _dtx_ifcase_arms("@copyrightpermission")
    if not (len(modes) == len(owner_arms) == len(perm_arms)):
        raise ValueError(
            f"copyright parse desync: {len(modes)} modes, {len(owner_arms)} owner arms, "
            f"{len(perm_arms)} permission arms")
    owner = {m: _normalize_dtx_copyright(a) or None for m, a in zip(modes, owner_arms)}
    permission = {m: _normalize_dtx_copyright(a) or None for m, a in zip(modes, perm_arms)}
    # The `cc` permission arm is the badge/link machinery, compared via the CC tables.
    permission["cc"] = None

    source = (ACMART / "acmart.dtx").read_text()
    cc_start = source.index(r"\or % CC")
    cc_arm = source[cc_start:source.index(r"\fi}", cc_start)]
    cc_names = dict(re.findall(r"\\IfEq\{\\ACM@cc@type\}\{([a-z0-9-]+)\}\{([^{}]*)\}", cc_arm))
    version = re.search(r"\\IfEq\{\\ACM@cc@version\}\{4\.0\}\{([^{}]*)\}\{([^{}]*)\}", cc_arm)
    zero_url = re.search(r"\\def\\ACM@CC@Url\{(https://[^}]*)\}", cc_arm).group(1)
    lic_url = re.search(r"\\edef\\ACM@CC@Url\{(https://[^}]*)\}", cc_arm).group(1)
    lic_url = lic_url.replace(r"\ACM@cc@type", "{type}").replace(r"\ACM@cc@version", "{version}")
    return {
        "modes": modes, "owner": owner, "permission": permission,
        "cc-names": cc_names,
        "cc-4.0": version.group(1), "cc-3.0": version.group(2),
        "cc-zero-url": zero_url, "cc-lic-url": lic_url,
    }


def _typst_copyright_data() -> dict[str, object]:
    source = (ROOT / "src" / "parts" / "copyright.typ").read_text()
    start = source.index("#let _copyright-modes = (")
    body = source[start:source.index("\n)", start)]
    owner: dict[str, str | None] = {}
    permission: dict[str, str | None] = {}
    modes: list[str] = []
    entry = re.compile(
        r'^\s*(?:"([^"]+)"|([A-Za-z][\w-]*)): _mode\((none|\[.*\]), (none|\[.*\])\),\s*$', re.M)
    declarations = len(re.findall(r"^\s*(?:\"[^\"]+\"|[A-Za-z][\w-]*): _mode\(", body, re.M))
    for quoted, bare, perm, own in entry.findall(body):
        key = quoted or bare
        modes.append(key)
        permission[key] = _normalize_typst_copyright(perm)
        owner[key] = _normalize_typst_copyright(own)
    if len(modes) != declarations:
        raise ValueError(
            f"parsed only {len(modes)} of {declarations} entries in _copyright-modes")

    names_start = source.index("#let _cc-names = (")
    names_body = source[names_start:source.index("\n)", names_start)]
    cc_names = {
        (quoted or bare): value
        for quoted, bare, value in re.findall(
            r'^\s*(?:"([^"]+)"|([\w-]+)):\s*"([^"]*)",\s*$', names_body, re.M)
    }
    statement = source[source.index("#let cc-statement"):]
    version = re.search(
        r'if cc-version == "4\.0" \{ "([^"]*)" \} else \{ "([^"]*)" \}', statement)
    zero_url = re.search(
        r'"(https://creativecommons\.org/publicdomain/zero/[^"]*)"', statement).group(1)
    lic = re.search(
        r'"(https://creativecommons\.org/licenses/)" \+ cc-type \+ "(/)" \+ cc-version',
        statement)
    return {
        "modes": modes, "owner": owner, "permission": permission,
        "cc-names": cc_names,
        "cc-4.0": version.group(1), "cc-3.0": version.group(2),
        "cc-zero-url": zero_url, "cc-lic-url": lic.group(1) + "{type}" + lic.group(2) + "{version}",
    }


def _compare_copyright_data(failures: list[str]) -> None:
    expected = _latex_copyright_data()
    actual = _typst_copyright_data()
    if expected["modes"] != actual["modes"]:
        failures.append(
            "copyright modes: order/set differs from acmart.dtx\n"
            f"    expected: {expected['modes']}\n"
            f"    actual:   {actual['modes']}")
    for field in ("permission", "owner"):
        _compare_transcribed_mapping(
            failures, f"copyright {field}", "acmart.dtx",
            expected[field], actual[field])
    _compare_transcribed_mapping(
        failures, "copyright cc-names", "acmart.dtx",
        expected["cc-names"], actual["cc-names"])
    for key in ("cc-4.0", "cc-3.0", "cc-zero-url", "cc-lic-url"):
        if expected[key] != actual[key]:
            failures.append(
                f"copyright {key}: differs from acmart.dtx\n"
                f"    expected: {expected[key]!r}\n"
                f"    actual:   {actual[key]!r}")


def _compare_transcribed_mapping(
        failures: list[str], label: str, upstream: str,
        expected: dict[str, str], actual: dict[str, str]) -> None:
    if missing := sorted(set(expected) - set(actual)):
        failures.append(f"{label}: missing Typst entries: " + ", ".join(missing))
    if extra := sorted(set(actual) - set(expected)):
        failures.append(f"{label}: entries absent from {upstream}: " + ", ".join(extra))
    for key in sorted(set(expected) & set(actual)):
        if expected[key] != actual[key]:
            failures.append(
                f"{label}: {key!r} differs from {upstream}\n"
                f"    expected: {expected[key]!r}\n"
                f"    actual:   {actual[key]!r}")


def gate_source_data(report: bool = False) -> list[str]:
    """Ensure transcribed data still matches the bundled LaTeX/BibTeX sources.

    PACMNET's long name is the one deliberate correction: upstream says
    "Networkng", while this port intentionally publishes "Networking".
    """
    failures: list[str] = []
    try:
        expected = _latex_journal_records()
        actual = _typst_journal_records()
    except (OSError, ValueError) as error:
        return [f"source-data parser failed: {error}"]
    if "PACMNET" in expected:
        expected["PACMNET"]["name"] = "Proceedings of the ACM on Networking"
    if missing := sorted(set(expected) - set(actual)):
        failures.append("journal data: missing Typst records " + ", ".join(missing))
    if extra := sorted(set(actual) - set(expected)):
        failures.append("journal data: records absent from LaTeX " + ", ".join(extra))
    for code in sorted(set(expected) & set(actual)):
        if expected[code] != actual[code]:
            failures.append(
                f"journal data: {code} differs from acmart.dtx\n"
                f"    expected: {expected[code]}\n"
                f"    actual:   {actual[code]}")

    bib_expected: dict[str, dict[str, str]] = {}
    bib_actual: dict[str, dict[str, str]] = {}
    try:
        bib_expected = _latex_bib_data()
        bib_actual = _typst_bib_data()
        for table in ("journal-macros", "journal-canon"):
            _compare_transcribed_mapping(
                failures, f"bibliography data {table}", "ACM-Reference-Format.bst",
                bib_expected[table], bib_actual[table])
    except (OSError, ValueError) as error:
        failures.append(f"bibliography source-data parser failed: {error}")

    try:
        _compare_copyright_data(failures)
    except (OSError, ValueError, AttributeError) as error:
        failures.append(f"copyright source-data parser failed: {error}")

    math_tables = (
        ("_math-sym", "math-symbols", True),
        ("_math-op-cw", "math-operators", True),
        ("_math-fn1", "math-functions-one", True),
        ("_math-fn2", "math-functions-two", True),
        ("_math-noop", "math-noops", False),
        ("_math-cs-space", "math-spacing-symbols", True),
    )
    try:
        tex_source = (ROOT / "src" / "parts" / "tex.typ").read_text()
        tex_tests = (TESTS_DIR / "unit" / "tex.typ").read_text()
        for source_name, test_name, is_mapping in math_tables:
            source_members = (_typst_mapping_keys(tex_source, source_name) if is_mapping
                              else _typst_tuple_strings(tex_source, source_name))
            tested_members = _typst_tuple_strings(tex_tests, test_name)
            if source_members != tested_members:
                failures.append(
                    f"math coverage: {test_name} does not exactly cover {source_name}\n"
                    f"    untested: {sorted(source_members - tested_members)}\n"
                    f"    stale:    {sorted(tested_members - source_members)}")
    except (OSError, ValueError) as error:
        failures.append(f"math-coverage parser failed: {error}")
    if report and not failures:
        print(
            f"ok   {len(actual)} journal records match acmart.dtx (PACMNET typo corrected); "
            f"{len(bib_actual['journal-macros'])} BST journal macros and "
            f"{len(bib_actual['journal-canon'])} canonical abbreviations match; "
            f"16 copyright modes + CC tables match; "
            f"{len(math_tables)} math tables exhaustively tested")
    return failures


def _package_manifest() -> dict:
    return tomllib.loads((ROOT / "typst.toml").read_text())


def _package_files() -> list[Path]:
    """Files selected by typst.toml's root-relative exclude list."""
    manifest = _package_manifest()
    excluded = tuple(item.lstrip("/").rstrip("/") for item in manifest["package"]["exclude"])

    def is_excluded(rel: str) -> bool:
        return rel == ".git" or rel.startswith(".git/") or any(
            rel == item or rel.startswith(item + "/") for item in excluded)

    return sorted(
        p for p in ROOT.rglob("*")
        if p.is_file() and not is_excluded(p.relative_to(ROOT).as_posix())
    )


def _release_readme(text: str, version: str) -> str:
    """Pin repository links in the release copy without changing GitHub's README."""
    repository = "https://github.com/fzaiser/faithful-acmart"
    for view in ("blob", "tree"):
        text = text.replace(
            f"{repository}/{view}/main/",
            f"{repository}/{view}/v{version}/",
        )
    return text


def _stage_package(package_dir: Path) -> list[str]:
    selected = _package_files()
    version = _package_manifest()["package"]["version"]
    rels: list[str] = []
    for source in selected:
        rel = source.relative_to(ROOT)
        destination = package_dir / rel
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        if rel.as_posix() == "README.md":
            destination.write_text(_release_readme(destination.read_text(), version))
        rels.append(rel.as_posix())
    return rels


def gate_package(report: bool = False) -> list[str]:
    """Manifest allowlist, fresh-package compile, and official offline lint."""
    failures: list[str] = []
    manifest = _package_manifest()
    package = manifest["package"]

    if package.get("compiler") != M.MIN_TYPST_VERSION:
        failures.append(
            f"package compiler floor {package.get('compiler')!r} != tested {M.MIN_TYPST_VERSION!r}")

    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        package_root = root / "packages"
        package_dir = package_root / "preview" / package["name"] / package["version"]
        rels = _stage_package(package_dir)

        allowed_root = {"LICENSE", "README.md", "thumbnail.png", "typst.toml"}
        unexpected = [rel for rel in rels if not (
            rel in allowed_root or rel.startswith("src/") or rel.startswith("template/")
        )]
        required = {
            "LICENSE", "README.md", "thumbnail.png", "typst.toml",
            "src/lib.typ", "template/main.typ", "template/refs.bib", "template/LICENSE",
        }
        missing = sorted(required - set(rels))
        if unexpected:
            failures.append("package contains non-allowlisted files: " + ", ".join(unexpected))
        if missing:
            failures.append("package is missing required files: " + ", ".join(missing))

        source_readme = (ROOT / "README.md").read_text()
        staged_readme = (package_dir / "README.md").read_text()
        release_tag = f"v{package['version']}"
        repository = "https://github.com/fzaiser/faithful-acmart"
        main_prefixes = tuple(f"{repository}/{view}/main/" for view in ("blob", "tree"))
        tag_prefixes = tuple(
            f"{repository}/{view}/{release_tag}/" for view in ("blob", "tree"))
        if not any(prefix in source_readme for prefix in main_prefixes):
            failures.append("repository README must link to the live main branch")
        if (any(prefix in staged_readme for prefix in main_prefixes)
                or not any(prefix in staged_readme for prefix in tag_prefixes)):
            failures.append(
                f"staged README did not rewrite main-branch links to {release_tag}")

        project = root / "project"
        shutil.copytree(package_dir / "template", project)
        output = project / "out.pdf"
        compile_proc = subprocess.run(
            ["typst", "compile", str(project / "main.typ"), str(output),
             "--package-path", str(package_root), "--root", str(project),
             "--font-path", str(ROOT / "fonts"), "--ignore-system-fonts"],
            capture_output=True, text=True, env={**os.environ, **TEST_CLOCK_ENV},
        )
        if compile_proc.returncode != 0 or not output.exists():
            failures.append(
                "fresh staged package failed to compile:\n" +
                (compile_proc.stderr + compile_proc.stdout).strip())

        checker = shutil.which("typst-package-check")
        if checker is None:
            failures.append("typst-package-check is not installed")
        else:
            check_proc = subprocess.run(
                [checker, "check", "--offline", "--json", str(package_dir)],
                capture_output=True, text=True,
            )
            diagnostics = []
            for line in check_proc.stdout.splitlines():
                try:
                    diagnostics.append(json.loads(line))
                except json.JSONDecodeError:
                    diagnostics.append({"kind": "error", "message": line})
            unexpected = [d for d in diagnostics if not (
                d.get("code") == "compile/warning"
                and "current font is not designed for math" in d.get("message", "")
            )]
            # The offline checker does not load the repository's excluded dev
            # fonts, so its bundled compiler reports the documented Libertinus
            # Math absence. Package rules prohibit shipping that font; accept
            # only this exact warning and reject every other lint/compile issue.
            if unexpected or (check_proc.returncode != 0 and not diagnostics):
                failures.append(
                    "typst-package-check failed:\n" +
                    (check_proc.stderr + "\n" + "\n".join(
                        f"{d.get('code', d.get('kind'))}: {d.get('message')}" for d in unexpected
                    )).strip())
    if report and not failures:
        print(f"ok   {len(rels)} shipped files; fresh template compile; offline package lint")
    return failures


def build_all_latex(
        jobs: int = 1, force: bool = False, names: list[str] | None = None) -> None:
    """Build selected LaTeX twins (all by default) in parallel.

    Up-to-date references are skipped unless ``force`` (see ``ref_is_fresh``).
    """
    ensure_class(LATEX)  # serial, before fan-out: avoids a class/asset write race
    selected = set(TESTS) if names is None else set(names)
    twins = [(name, TESTS_DIR / t.subdir / f"{name}.tex")
             for name, t in TESTS.items() if name in selected and t.kind == "twin"]

    def build_one(item: tuple[str, Path]) -> None:
        name, tex = item
        if not force and ref_is_fresh(tex, LATEX / f"{name}.pdf"):
            print(f"  latex {name} (cached)")
            return
        print(f"  latex {name}")
        latex_build(tex)

    _pmap(build_one, twins, jobs)


# ---------------------------------------------------------------------------
# Gates
# ---------------------------------------------------------------------------
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

    Per policy a version difference must not fail anything on its own; this is
    only appended to gates that already failed, to name a likely cause.
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
                    local.append(f"{name}: page {i} changed")
                    DIFF.mkdir(parents=True, exist_ok=True)
                    rasterize(typst_pdf(name), M.GOLDEN_DPI, DIFF / f"changed-{name}")
        if not local:
            print(f"ok   {name} ({len(c)}p)")
        failures.extend(local)
    if failures:
        failures.append(f"inspect changed pages in {DIFF.relative_to(ROOT)}/ , "
                        "then `test.py accept` if intended.")
        if note := _poppler_mismatch_note():
            failures.append(note)
    return failures


def _first_diff(a: str, b: str) -> str:
    aw, bw = a.split(), b.split()
    matcher = difflib.SequenceMatcher(a=aw, b=bw)
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == "equal":
            continue
        left = " ".join(aw[max(0, i1 - 8):min(len(aw), i2 + 12)])
        right = " ".join(bw[max(0, j1 - 8):min(len(bw), j2 + 12)])
        return f"{tag} at LaTeX token {i1}, Typst token {j1}\n    LaTeX: {left}\n    Typst: {right}"
    return "strings differ, but no token diff was found"


def _residual_digest(missing: Counter, extra: Counter) -> str:
    """Stable SHA-256 of a signed gate residual.

    Counter keys may be strings or font/order tuples, so serialize their reprs in
    sorted order rather than relying on insertion order or JSON type coercion.
    """
    payload = repr((
        sorted(((repr(key), count) for key, count in missing.items())),
        sorted(((repr(key), count) for key, count in extra.items())),
    )).encode()
    return hashlib.sha256(payload).hexdigest()


def _expected_residual(name: str, kind: str) -> str:
    residual = M.EXPECTED_RESIDUALS.get(name)
    return getattr(residual, kind) if residual is not None else ""


def _assertion_targets(name: str, t: Test, a: M.Assertion) -> list[tuple[str, Path]]:
    if a.engine == "typst":
        return [("Typst", typst_pdf(name))]
    if a.engine == "latex":
        return [("LaTeX", latex_pdf(name, t))]
    if a.engine == "both":
        return [("LaTeX", latex_pdf(name, t)), ("Typst", typst_pdf(name))]
    raise ValueError(f"unknown text assertion engine {a.engine!r}")


def _check_expected_pdf_diffs(
    name: str,
    t: Test,
    diffs: tuple,
    kind: str,
    lraw: str,
    traw: str,
    *,
    require_text_difference: bool,
) -> list[str]:
    failures: list[str] = []
    for i, d in enumerate(diffs, 1):
        cause = getattr(d, "cause", None)
        explanation = getattr(cause, "reason", "").strip() or f"expected {kind} diff {i}"
        norm_kw = {"review_line_numbers": t.review_line_numbers}
        lneedle, tneedle = normalize(d.latex, **norm_kw), normalize(d.typst, **norm_kw)
        scope = f" page {d.page}" if d.page is not None else ""
        if not isinstance(cause, M.DIFF_CAUSE_TYPES):
            failures.append(
                f"{name}: {explanation} has invalid {kind} diff cause {cause!r}")
        if not lneedle:
            failures.append(f"{name}: {explanation} has an empty LaTeX {kind} fragment")
        if not tneedle:
            failures.append(f"{name}: {explanation} has an empty Typst {kind} fragment")
        if require_text_difference and lneedle and tneedle and lneedle == tneedle:
            failures.append(f"{name}: {explanation} {kind} fragments normalize identically")
        if not lneedle or not tneedle:
            continue

        lhaystack = (
            normalize(pdf_text(latex_pdf(name, t), page=d.page), **norm_kw)
            if d.page is not None else normalize(lraw, **norm_kw)
        )
        thaystack = (
            normalize(pdf_text(typst_pdf(name), page=d.page), **norm_kw)
            if d.page is not None else normalize(traw, **norm_kw)
        )
        if lneedle not in lhaystack:
            failures.append(
                f"{name}: LaTeX{scope} missing expected {kind} diff {i} ({explanation}): {lneedle!r}")
        if tneedle not in thaystack:
            failures.append(
                f"{name}: Typst{scope} missing expected {kind} diff {i} ({explanation}): {tneedle!r}")
    return failures


def _check_expected_text_diffs(name: str, t: Test, lraw: str, traw: str) -> list[str]:
    return _check_expected_pdf_diffs(
        name, t, t.expected_text_diffs, "text", lraw, traw,
        require_text_difference=True,
    )


def _check_expected_font_diffs(name: str, t: Test, lraw: str, traw: str) -> list[str]:
    return _check_expected_pdf_diffs(
        name, t, t.expected_font_diffs, "font", lraw, traw,
        require_text_difference=False,
    )


def _check_expected_order_diffs(name: str, t: Test, lraw: str, traw: str) -> list[str]:
    return _check_expected_pdf_diffs(
        name, t, t.expected_order_diffs, "order", lraw, traw,
        require_text_difference=True,
    )


def gate_text(report: bool = False) -> list[str]:
    """Tier 1.5 — extracted-text semantic gate."""
    failures: list[str] = []
    for name, t in TESTS.items():
        if t.kind != "twin":
            continue
        lref, tpdf = latex_pdf(name, t), typst_pdf(name)
        if not lref.exists() or not tpdf.exists():
            failures.append(f"{name}: missing PDF ({'LaTeX' if not lref.exists() else 'Typst'})")
            continue

        local: list[str] = []
        lraw, traw = pdf_text(lref), pdf_text(tpdf)
        if t.text_equal is True:
            ltext = normalize(lraw, review_line_numbers=t.review_line_numbers)
            ttext = normalize(traw, review_line_numbers=t.review_line_numbers)
            if ltext != ttext:
                local.append(f"{name}: normalized text differs\n    {_first_diff(ltext, ttext)}")
            elif report:
                print(f"equal {name}")
        elif t.text_equal == "bag":
            cov, miss, extra = bag_coverage(
                lraw, traw, review_line_numbers=t.review_line_numbers)
            if miss or extra:
                local.append(
                    f"{name}: word bags differ ({cov * 100:.2f}% common)\n"
                    f"    only in LaTeX: {', '.join(list(miss)[:12])}\n"
                    f"    only in Typst: {', '.join(list(extra)[:12])}")
            elif report:
                print(f"bag   {name}: word-bag exact (order-independent)")
        elif t.text_equal is False:
            if not t.expected_text_diffs:
                local.append(f"{name}: text_equal=false requires expected_text_diffs")
            elif report:
                print(f"skip  {name}: text equality exempt by expected_text_diffs")
        elif report:
            print(f"skip  {name}: text equality not configured")

        # Universal char-bag tripwire on top of the above: every twin's content
        # must match as an exact character multiset (order-, line-break-, number-
        # and scheme-independent), unless it carries expected_text_diffs evidence
        # for a known content difference or a pdftotext extraction artifact.
        ca = char_bag(lraw, review_line_numbers=t.review_line_numbers)
        cb = char_bag(traw, review_line_numbers=t.review_line_numbers)
        cm, ce = ca - cb, cb - ca
        if t.expected_text_diffs:
            actual = _residual_digest(cm, ce)
            expected = _expected_residual(name, "text")
            if not expected:
                local.append(f"{name}: expected_text_diffs requires an exact text residual signature")
            elif actual != expected:
                local.append(
                    f"{name}: text residual changed (expected {expected}, got {actual})\n"
                    f"    only in LaTeX: {dict(cm)}\n    only in Typst: {dict(ce)}")
            elif report:
                print(f"diff  {name}: exact expected char residual {actual[:12]}")
        elif cm or ce:
            local.append(
                f"{name}: char bags differ (read both pdftotext dumps to locate)\n"
                f"    only in LaTeX: {dict(cm)}\n    only in Typst: {dict(ce)}")
        else:
            if report:
                print(f"char  {name}: exact")

        da = dash_bag(lraw, review_line_numbers=t.review_line_numbers)
        db = dash_bag(traw, review_line_numbers=t.review_line_numbers)
        dm, de = da - db, db - da
        expected_dash = M.EXPECTED_DASH_DIFFS.get(name)
        if expected_dash is not None:
            expected_missing = Counter({"-": expected_dash.latex_only}) + Counter()
            expected_extra = Counter({"-": expected_dash.typst_only}) + Counter()
            if dm != expected_missing or de != expected_extra:
                local.append(
                    f"{name}: dash residual changed ({expected_dash.reason}); "
                    f"expected {dict(expected_missing)}/{dict(expected_extra)}, "
                    f"got {dict(dm)}/{dict(de)}")
            elif report:
                print(f"dash  {name}: exact expected residual {dict(dm)}/{dict(de)}")
        elif dm or de:
            local.append(
                f"{name}: normalized dash counts differ\n"
                f"    only in LaTeX: {dict(dm)}\n    only in Typst: {dict(de)}")

        local.extend(_check_expected_text_diffs(name, t, lraw, traw))
        if report and t.expected_text_diffs:
            print(f"diff  {name}: {len(t.expected_text_diffs)} expected text/char diff(s) documented")

        for i, a in enumerate(t.text_assertions, 1):
            needle = normalize(a.text, review_line_numbers=t.review_line_numbers)
            if not needle:
                local.append(f"{name}: text assertion {i} has empty text")
                continue
            for label, pdf in _assertion_targets(name, t, a):
                haystack = normalize(
                    pdf_text(pdf, page=a.page), review_line_numbers=t.review_line_numbers)
                scope = f" page {a.page}" if a.page is not None else ""
                if a.kind == "contains" and needle not in haystack:
                    local.append(f"{name}: {label}{scope} missing text assertion {i}: {needle!r}")
                elif a.kind == "absent" and needle in haystack:
                    local.append(f"{name}: {label}{scope} contains forbidden assertion {i}: {needle!r}")
                elif a.kind not in ("contains", "absent"):
                    local.append(f"{name}: unknown text assertion kind {a.kind!r}")

        if not local and not report:
            print(f"ok   {name}")
        failures.extend(local)
    if failures and (note := _poppler_mismatch_note()):
        failures.append(note)
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


# Semantic document-info fields worth cross-checking against LaTeX. Producer /
# Creator / CreationDate carry engine identity, so they are deliberately excluded.
# acmart's hyperref setup emits only /Title (and a CCS /Subject we don't mirror),
# never /Author or /Keywords — so LaTeX is an oracle for a field only when it
# populates it; where it doesn't, the METADATA_EXPECTATIONS anchors pin Typst.
_CROSS_METADATA_FIELDS = ("Title", "Author", "Keywords")


def _meta_norm(value: str | None) -> str:
    return (value or "").strip()


def gate_metadata(report: bool = False) -> list[str]:
    """Tier 1.55 — PDF metadata populated by the acmart show rule.

    Anchored twins keep exact expected Title/Author/Keywords; every twin also has
    its semantic fields cross-checked against its LaTeX twin wherever LaTeX
    provides a value.
    """
    failures: list[str] = []
    for name, expected in M.METADATA_EXPECTATIONS.items():
        pdf = typst_pdf(name)
        if not pdf.exists():
            failures.append(f"{name}: missing Typst PDF for metadata gate")
            continue
        actual = pdf_info(pdf)
        for field, value in expected.items():
            if actual.get(field) != value:
                failures.append(
                    f"{name}: PDF {field} metadata is {actual.get(field)!r}, expected {value!r}")
        if report and not any(f.startswith(name + ":") for f in failures):
            print(f"ok   {name}: title/author/keywords metadata")

    for name, t in TESTS.items():
        if t.kind != "twin":
            continue
        lref, tpdf = latex_pdf(name, t), typst_pdf(name)
        if not lref.exists() or not tpdf.exists():
            failures.append(f"{name}: missing PDF ({'LaTeX' if not lref.exists() else 'Typst'})")
            continue
        li, ti = pdf_info(lref), pdf_info(tpdf)
        exempt = M.METADATA_CROSS_EXEMPTIONS.get(name, {})
        for field, reason in exempt.items():
            lv, tv = _meta_norm(li.get(field)), _meta_norm(ti.get(field))
            if not lv or lv == tv:
                failures.append(
                    f"{name}: metadata {field} exemption set but LaTeX/Typst do not "
                    f"differ ({reason})")
        for field in _CROSS_METADATA_FIELDS:
            if field in exempt:
                continue
            lv = _meta_norm(li.get(field))
            if not lv:  # acmart gave no oracle for this field
                continue
            tv = _meta_norm(ti.get(field))
            if lv != tv:
                failures.append(
                    f"{name}: PDF {field} differs from LaTeX\n"
                    f"    LaTeX: {lv!r}\n    Typst: {tv!r}")
        if report:
            print(f"cross {name}: semantic metadata vs LaTeX")
    return failures


def _metrics_for(pdf: Path) -> dict:
    return {n: page_metrics(p) for n, p in words(pdf).items()}


def _line_pitch_drift(a: list[float], b: list[float]) -> tuple[float, int]:
    """(worst per-line pitch difference, #lines compared) for two pitch sequences.

    Returns (0.0, 0) when the sequences can't be paired one-to-one — i.e. the two
    engines broke the page into a different number of text lines, so position i in
    one isn't the same line as position i in the other. The caller then leans on
    the median-pitch gate instead.
    """
    if not a or len(a) != len(b):
        return 0.0, 0
    return max(abs(x - y) for x, y in zip(a, b)), len(a)


def gate_metrics(report: bool = False) -> list[str]:
    """Tier 2 — cross-engine layout metrics."""
    tol = M.METRICS_TOLERANCE
    failures: list[str] = []
    for name, t in TESTS.items():
        if t.kind != "twin":
            continue
        lref, tpdf = latex_pdf(name, t), typst_pdf(name)
        if not lref.exists() or not tpdf.exists():
            failures.append(f"{name}: missing PDF ({'LaTeX' if not lref.exists() else 'Typst'})")
            continue
        lm, tm = _metrics_for(lref), _metrics_for(tpdf)
        lw, tw = words(lref), words(tpdf)  # cached; carries per-page MediaBox size
        pages = [1] if t.metrics_page1_only else sorted(set(lm) & set(tm))
        gated = [("left", tol["left"], "left margin"), ("top", tol["top"], "top margin")]
        if t.metrics_uniform_pitch:
            gated.append(("pitch", tol["pitch"], "baseline pitch"))

        # Per-line pitch is gated only on single-page uniform-pitch twins. A
        # multi-page doc's page 1 is full, so acmsmall's \@textbottom rubber glue
        # stretches its paragraph gaps to the bottom margin (the documented fill we
        # can't replicate) — gating per-line spacing there would chase that drift.
        line_pitch = bool(t.metrics_uniform_pitch) and t.pages == 1
        gated_summary = "L/T"
        if t.metrics_uniform_pitch:
            gated_summary += "/pitch"
        if line_pitch:
            gated_summary += "/line-pitch"
        if report:
            print(name + ":")
        hard_failures: list[str] = []
        observed: dict[tuple[int, str], float] = {}
        compared = 0
        if not pages:
            hard_failures.append(f"{name}: no shared pages for metric comparison")
        for p in pages:
            a, b = lm.get(p), tm.get(p)
            if a is None or b is None:
                continue
            compared += 1
            lpd = _line_pitch_drift(a["pitches"], b["pitches"]) if line_pitch else None
            if report:
                lpd_s = (f"  line-pitch {lpd[0]:.2f}pt×{lpd[1]}" if lpd and lpd[1]
                         else "  line-pitch n/a (lines differ)" if line_pitch else "")
                print(f"  {name} p{p}: "
                      f"L {a['left']:.1f}/{b['left']:.1f}  R {a['right']:.1f}/{b['right']:.1f}  "
                      f"T {a['top']:.1f}/{b['top']:.1f}  "
                      f"lines {a['lines']}/{b['lines']}  pitch {a['pitch']:.2f}/{b['pitch']:.2f}"
                      f"{lpd_s}   ({gated_summary} gated; R/lines report-only)")
                continue
            for key, lim, label in gated:
                d = abs(a[key] - b[key])
                if d > lim:
                    observed[(p, key)] = d
            # Cross-engine page geometry: MediaBox width/height must agree tightly.
            lpg, tpg = lw.get(p), tw.get(p)
            if lpg and tpg:
                for dim, key in (("w", "width"), ("h", "height")):
                    d = abs(lpg[dim] - tpg[dim])
                    if d > tol[key]:
                        observed[(p, key)] = d
            # Per-line pitch: only when the line-break structure matches (aligned
            # pitch sequences); otherwise the median pitch above is the gate.
            if lpd and lpd[1] and lpd[0] > tol["line_pitch"]:
                observed[(p, "line_pitch")] = lpd[0]
        if report:
            continue
        if compared == 0:
            hard_failures.append(f"{name}: zero pages yielded comparable metric data")
        if hard_failures:
            failures.extend(hard_failures)
            continue

        allowances = M.EXPECTED_METRIC_DIFFS.get(name, ())
        allowed = {(item.page, item.key): item.max_delta for item in allowances}
        if t.expected_metrics_diff:
            missing = sorted(set(allowed) - set(observed))
            unexpected = sorted(set(observed) - set(allowed))
            excessive = sorted(
                (key, observed[key], allowed[key])
                for key in set(observed) & set(allowed)
                if observed[key] > allowed[key]
            )
            if missing or unexpected or excessive:
                failures.append(
                    f"{name}: metric residual changed ({t.expected_metrics_diff})\n"
                    f"    expected-but-passing: {missing}\n"
                    f"    unexpected failures: {[(k, round(observed[k], 2)) for k in unexpected]}\n"
                    f"    over budget: {[(k, round(got, 2), limit) for k, got, limit in excessive]}")
            else:
                print(f"diff {name} (exact expected metric keys; bounded deltas)")
        elif allowances:
            failures.append(f"{name}: metric allowances exist without expected_metrics_diff rationale")
        elif observed:
            details = []
            for (page, key), delta in sorted(observed.items()):
                limit = tol["line_pitch" if key == "line_pitch" else key]
                details.append(f"{name} p{page}: {key} Δ={delta:.2f}pt (tol {limit})")
            failures.extend(details)
        else:
            print(f"ok   {name}")
    return failures


def _align_words(lwords: list, twords: list) -> list[tuple[float, float, str]]:
    """Pair the two engines' word streams and return (dx, dy, text) per match.

    Alignment is difflib's longest-matching-block over the word TEXT (autojunk
    off, so common short words are not dropped). Only positionally-aligned
    matches are returned; words that one engine split differently (ligature or
    hyphenation segmentation) simply don't match and are ignored by construction
    — so this gate measures placement, never text coverage (the char/word bags
    own that). dy is signed; the caller removes the page's median dy to cancel the
    engines' constant first-baseline-convention offset.
    """
    lt = [w[4] for w in lwords]
    tt = [w[4] for w in twords]
    matcher = difflib.SequenceMatcher(a=lt, b=tt, autojunk=False)
    matched: list[tuple[float, float, str]] = []
    for i1, j1, size in matcher.get_matching_blocks():
        for k in range(size):
            lw, tw = lwords[i1 + k], twords[j1 + k]
            matched.append((lw[0] - tw[0], lw[1] - tw[1], lw[4]))
    return matched


def gate_word_positions(report: bool = False) -> list[str]:
    """Tier 2.5 — per-word placement on opt-in (``word_positions``) twins.

    For each opted-in twin whose two engines break into the same lines, align the
    word streams per page and gate max |Δx0| and max |Δy0−median(Δy0)| against
    ``WORD_POSITION_TOLERANCE``. Subtracting the per-page median Δy cancels the
    engines' constant top-baseline offset (Tier 2 'top' owns that gross value), so
    what survives is a lost indent/centering or a single mis-spaced line."""
    tol = M.WORD_POSITION_TOLERANCE
    failures: list[str] = []
    for name, t in TESTS.items():
        if t.kind != "twin" or not t.word_positions:
            continue
        lref, tpdf = latex_pdf(name, t), typst_pdf(name)
        if not lref.exists() or not tpdf.exists():
            failures.append(f"{name}: missing PDF ({'LaTeX' if not lref.exists() else 'Typst'})")
            continue
        lw, tw = words(lref), words(tpdf)
        pages = sorted(set(lw) & set(tw))
        worst = {"dx": (0.0, ""), "dy": (0.0, "")}
        matched_total = 0
        for p in pages:
            m = _align_words(lw[p]["words"], tw[p]["words"])
            if not m:
                continue
            matched_total += len(m)
            median_dy = statistics.median(dy for _, dy, _ in m)
            for dx, dy, text in m:
                adx, ady = abs(dx), abs(dy - median_dy)
                if adx > worst["dx"][0]:
                    worst["dx"] = (adx, f"p{p} {text!r}")
                if ady > worst["dy"][0]:
                    worst["dy"] = (ady, f"p{p} {text!r}")
        if matched_total == 0:
            failures.append(f"{name}: no words aligned for the position gate")
            continue
        over = [f"{axis} Δ={delta:.2f}pt at {where} (tol {tol})"
                for axis, (delta, where) in worst.items() if delta > tol]
        if over:
            failures.append(f"{name}: word positions drifted vs LaTeX\n    " + "\n    ".join(over))
        elif report:
            print(f"ok   {name}: {matched_total} words within "
                  f"Δx {worst['dx'][0]:.2f}pt / Δy {worst['dy'][0]:.2f}pt")
    return failures


@_pdf_memo
def horizontal_rules(pdf: Path) -> dict[int, list[tuple]]:
    """1-based page -> list of (thickness, colour, x_mid, x_width) horizontal rules.

    A rule is a stroked line or a thin filled rectangle whose long axis is
    horizontal. LaTeX draws booktabs/footnote rules as thin filled boxes and
    strokes; Typst strokes them — both reduce to the same tuple, so the gate is
    engine-neutral. Colour is quantised to a 1/16 grid to absorb CMYK rounding."""
    import fitz
    out: dict[int, list[tuple]] = {}
    doc = fitz.open(pdf)
    try:
        for pno in range(doc.page_count):
            rules: list[tuple] = []
            for drawing in doc[pno].get_drawings():
                if drawing["type"] not in ("s", "sf", "fs"):
                    continue
                width = drawing.get("width") or 0.0
                colour = drawing.get("color") or (0.0, 0.0, 0.0)
                colour_q = tuple(round(c * 16) / 16 for c in colour)
                for item in drawing["items"]:
                    if item[0] == "l":
                        p1, p2 = item[1], item[2]
                        if abs(p1.y - p2.y) < 0.4 and abs(p1.x - p2.x) > 2:
                            rules.append((width, colour_q, (p1.x + p2.x) / 2, abs(p2.x - p1.x)))
                    elif item[0] == "re":
                        r = item[1]
                        if r.height < 3 and r.width > 2:
                            rules.append((r.height, colour_q, (r.x0 + r.x1) / 2, r.width))
            if rules:
                out[pno + 1] = rules
    finally:
        doc.close()
    return out


def _match_rules(lrules: list[tuple], trules: list[tuple]) -> tuple[list, list]:
    """Bijectively pair rules by colour (exact), thickness/x-mid/x-width (toleranced).
    Returns (LaTeX-only, Typst-only) rules that found no partner."""
    used = [False] * len(trules)
    unmatched_l = []
    for a in lrules:
        partner = -1
        for j, b in enumerate(trules):
            if used[j] or a[1] != b[1]:
                continue
            if (abs(a[0] - b[0]) <= M.RULE_THICKNESS_TOL
                    and abs(a[2] - b[2]) <= M.RULE_XMID_TOL
                    and abs(a[3] - b[3]) <= M.RULE_XWIDTH_TOL):
                partner = j
                break
        if partner < 0:
            unmatched_l.append(a)
        else:
            used[partner] = True
    unmatched_t = [trules[j] for j in range(len(trules)) if not used[j]]
    return unmatched_l, unmatched_t


def _fmt_rule(r: tuple) -> str:
    return f"(w={r[0]:.2f} rgb={r[1]} xmid={r[2]:.1f} xw={r[3]:.1f})"


def gate_horizontal_rules(report: bool = False) -> list[str]:
    """Tier 2.6 — horizontal-rule weight/colour/extent on opt-in (``rule_gate``)
    twins. Each LaTeX rule must find a distinct Typst rule of matching colour,
    thickness (±0.05pt), x-midpoint (±1.5pt) and x-width (±8pt), and vice versa.
    Needs PyMuPDF."""
    try:
        import fitz  # noqa: F401
    except ImportError:
        return ["Tier 2.6 (rules) requires PyMuPDF (run `uv sync`)"]
    failures: list[str] = []
    for name, t in TESTS.items():
        if t.kind != "twin" or not t.rule_gate:
            continue
        lref, tpdf = latex_pdf(name, t), typst_pdf(name)
        if not lref.exists() or not tpdf.exists():
            failures.append(f"{name}: missing PDF ({'LaTeX' if not lref.exists() else 'Typst'})")
            continue
        lrules, trules = horizontal_rules(lref), horizontal_rules(tpdf)
        total = sum(len(v) for v in lrules.values())
        if total == 0:
            failures.append(f"{name}: rule_gate is set but LaTeX draws no horizontal rules")
            continue
        local: list[str] = []
        for p in sorted(set(lrules) | set(trules)):
            miss, extra = _match_rules(lrules.get(p, []), trules.get(p, []))
            if miss or extra:
                local.append(
                    f"    p{p}: LaTeX-only {[_fmt_rule(r) for r in miss]}; "
                    f"Typst-only {[_fmt_rule(r) for r in extra]}")
        if local:
            failures.append(f"{name}: horizontal rules differ vs LaTeX\n" + "\n".join(local))
        elif report:
            print(f"ok   {name}: {total} horizontal rule(s) match")
    return failures


_SECTION_NUMBER = re.compile(r"^\d+(?:\.\d+)*\s")


@_pdf_memo
def outline(pdf: Path) -> list[tuple[int, str, int]]:
    """PDF bookmarks as (level, normalized-title, target-page) via PyMuPDF."""
    import fitz
    doc = fitz.open(pdf)
    try:
        return [(lvl, re.sub(r"\s+", " ", title).strip(), page)
                for lvl, title, page in doc.get_toc(simple=True)]
    finally:
        doc.close()


def _numbered_sections(entries: list[tuple[int, str, int]]) -> list[tuple[str, int]]:
    """(quote-folded title, page) for numbered-section bookmarks only.

    Restricting to numbered sections drops the frontmatter/backmatter entries
    acmart bookmarks via \\addcontentsline (Abstract, Synopsis, Acknowledgments,
    References) that Typst — which bookmarks headings, not those blocks — has no
    counterpart for. Quotes are folded because hyperref writes the raw TeX
    ``...'' where Typst writes real quotation marks."""
    def norm(title: str) -> str:
        # hyperref writes raw TeX quote ligatures into bookmarks (``…'' / `…');
        # fold them to plain quotes to meet Typst's real quotation marks.
        title = title.replace("``", '"').replace("''", '"').replace("`", "'")
        return _fold_quotes(title)
    return [(norm(t), p) for _lvl, t, p in entries if _SECTION_NUMBER.match(t)]


def gate_outline(report: bool = False) -> list[str]:
    """Tier 1.95 — PDF bookmark (outline) parity vs LaTeX for every twin.

    Compares the numbered-section bookmark sequence (title incl. its number, so
    nesting depth is implied), capping Typst to LaTeX's own bookmark depth (Typst
    bookmarks subsubsections/paragraphs that acmart's depth omits). Target PAGE is
    checked only for page-1-anchored entries — later-page bookmark targets drift
    with the documented multi-page page-fill difference. If LaTeX bookmarks any
    numbered section, Typst must emit a non-empty outline (catches lost tagging)."""
    try:
        import fitz  # noqa: F401
    except ImportError:
        return ["Tier 1.95 (outline) requires PyMuPDF (run `uv sync`)"]
    failures: list[str] = []
    for name, t in TESTS.items():
        if t.kind != "twin":
            continue
        lref, tpdf = latex_pdf(name, t), typst_pdf(name)
        if not lref.exists() or not tpdf.exists():
            failures.append(f"{name}: missing PDF ({'LaTeX' if not lref.exists() else 'Typst'})")
            continue
        lsec = _numbered_sections(outline(lref))
        tout = outline(tpdf)
        if not lsec:
            continue
        if not tout:
            failures.append(f"{name}: LaTeX bookmarks {len(lsec)} section(s) but the "
                            f"Typst PDF has no outline at all")
            continue
        depth = max(title.split(" ")[0].count(".") for title, _ in lsec)
        tsec = [(title, page) for title, page in _numbered_sections(tout)
                if title.split(" ")[0].count(".") <= depth]
        exempt = M.EXPECTED_OUTLINE_DIFFS.get(name)
        if [s[0] for s in lsec] != [s[0] for s in tsec]:
            if exempt:
                if report:
                    print(f"diff  {name}: expected outline difference ({exempt})")
                continue
            failures.append(
                f"{name}: section bookmark titles differ vs LaTeX\n"
                f"    LaTeX: {[s[0] for s in lsec]}\n    Typst: {[s[0] for s in tsec]}")
            continue
        page1 = [(lt, lp, tp) for (lt, lp), (_tt, tp) in zip(lsec, tsec)
                 if lp == 1 and tp != 1]
        if page1:
            failures.append(
                f"{name}: section bookmark targets a page-1 section off page 1: "
                + ", ".join(f"{lt!r} L=p{lp} T=p{tp}" for lt, lp, tp in page1))
        elif report:
            print(f"ok   {name}: {len(lsec)} section bookmark(s) match")
    return failures


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


def gate_links(report: bool = False) -> list[str]:
    """Tier 1.7 — external and internal hyperlink coverage.

    URI annotation multisets are compared exactly for every twin. Tests that set minimum
    internal-link counts also get normalized /GoTo and /Dest coverage checks.
    """
    failures: list[str] = []
    for name, t in TESTS.items():
        if t.kind != "twin":
            continue
        lref, tpdf = latex_pdf(name, t), typst_pdf(name)
        if not lref.exists() or not tpdf.exists():
            failures.append(f"{name}: missing PDF ({'LaTeX' if not lref.exists() else 'Typst'})")
            continue
        try:
            lu, tu = extract_uris(lref), extract_uris(tpdf)
        except RuntimeError as exc:
            failures.append(f"{name}: {exc}")
            continue
        miss, extra = lu - tu, tu - lu
        expected_link_diff = M.EXPECTED_LINK_DIFFS.get(name)
        if expected_link_diff is not None:
            expected_miss = Counter(expected_link_diff.missing)
            expected_extra = Counter(expected_link_diff.extra)
            if miss != expected_miss or extra != expected_extra:
                failures.append(
                    f"{name}: hyperlink residual changed ({expected_link_diff.reason})\n"
                    f"    expected LaTeX-only: {dict(expected_miss)}, got {dict(miss)}\n"
                    f"    expected Typst-only: {dict(expected_extra)}, got {dict(extra)}")
            elif report:
                print(f"diff  {name}: exact expected hyperlink multiset residual")
        elif miss or extra:
            failures.append(
                f"{name}: hyperlink multisets differ\n"
                f"    only in LaTeX: {dict(miss)}\n    only in Typst: {dict(extra)}")
        elif report:
            print(f"ok   {name}: {sum(tu.values())} hyperlink annotations match")
    for name, t in TESTS.items():
        if not (t.min_internal_links or t.min_internal_destinations):
            continue
        tpdf = typst_pdf(name)
        if not tpdf.exists():
            failures.append(f"{name}: Typst PDF missing for internal-link assertion")
            continue
        try:
            ti = extract_internal_links(tpdf)
        except RuntimeError as exc:
            failures.append(f"{name}: {exc}")
            continue
        if ti["count"] < t.min_internal_links:
            failures.append(
                f"{name}: expected at least {t.min_internal_links} internal links, "
                f"found {ti['count']}")
        if ti["unique_targets"] < t.min_internal_destinations:
            failures.append(
                f"{name}: expected at least {t.min_internal_destinations} internal "
                f"link destinations, found {ti['unique_targets']}")
        # Every resolved internal-link target must land on a real page: a target
        # page outside [1, pages] means a dangling/misresolved destination.
        stray = sorted(p for p in ti["target_pages"] if not 1 <= p <= ti["pages"])
        if stray:
            failures.append(
                f"{name}: internal links target out-of-range pages {stray} "
                f"(document has {ti['pages']} pages)")
        elif report:
            print(f"ok   {name}: {ti['count']} internal links, "
                  f"{ti['unique_targets']} destination(s)")
    return failures


# --- Tier 1.8: per-letter font/size/colour gate (PyMuPDF) ---
# pdftotext sees only characters; this catches a letter rendered in the wrong font
# family, weight, size, or colour — e.g. sigchi-a body that should be sans (acmart's
# \sffamily document default) but came out serif, or an author block a step too small.
def _font_role(font: str) -> str:
    """Canonical family for a PDF BaseFont, so LinBiolinum (LaTeX) and LibertinusSans
    (Typst) both map to 'sans'. Math/symbol fonts collapse to 'sym'."""
    f = font.lower()
    if any(k in f for k in ("mono", "inconsolata", "zi4", "dejavu")):
        return "mono"
    if any(k in f for k in ("math", "txsy", "newcm", "dingbat", "cmsy", "cmmi", "cmex", "msam", "msbm")):
        return "sym"
    if "biolinum" in f or "sans" in f:
        return "sans"
    if "libertine" in f or "serif" in f:
        return "serif"
    return "other:" + f


def _font_color(c: int) -> tuple[int, int, int]:
    """Quantise an sRGB int to a 16-step grid — absorbs the engines' 8-bit CMYK
    rounding (e.g. link blue #155195 vs #155095) while keeping real colours apart."""
    q = lambda x: min(255, (x + 8) // 16 * 16)
    return (q((c >> 16) & 255), q((c >> 8) & 255), q(c & 255))


@_pdf_memo
def _font_scan(pdf: Path) -> tuple[Counter, dict]:
    """Multiset of (letter, family, bold, italic, size, colour) over every glyph,
    plus the first (1-based) page each such key appears on for failure localization.

    LETTERS only — punctuation and symbols sit at font boundaries / come from
    divergent symbol fonts, so their family is noise. Mono SIZE is dropped: LaTeX's
    zi4 and our bundled Inconsolata are scaled differently, so the nominal size is
    incomparable (the family still is). The ITALIC flag is dropped for math/symbol
    glyphs: it comes from the font descriptor, which is unreliable for combined math
    fonts (Typst's NewCMMath reports non-italic even though it renders the
    mathematical-italic glyphs slanted, just like LaTeX's separate italic math font)."""
    import fitz
    counts: Counter = Counter()
    first_page: dict = {}
    with fitz.open(pdf) as doc:
        for pageno, page in enumerate(doc, 1):
            for block in page.get_text("dict")["blocks"]:
                for line in block.get("lines", []):
                    for span in line["spans"]:
                        fam = _font_role(span["font"])
                        size = None if fam == "mono" else round(span["size"] * 2) / 2
                        italic = False if fam == "sym" else bool(span["flags"] & 2)
                        key = (fam, bool(span["flags"] & 16), italic,
                               size, _font_color(span["color"]))
                        for ch in unicodedata.normalize("NFKC", span["text"]):
                            ch = CHAR_FOLD.get(ch, ch)
                            if unicodedata.category(ch).startswith("L"):
                                full = (ch,) + key
                                counts[full] += 1
                                first_page.setdefault(full, pageno)
    return counts, first_page


def font_bag(pdf: Path) -> Counter:
    """Per-letter font multiset (see _font_scan)."""
    return _font_scan(pdf)[0]


def gate_fonts(report: bool = False) -> list[str]:
    """Tier 1.8 — per-letter font gate. Every alphabetic character must match LaTeX
    in family/weight/italic/size/colour. Needs PyMuPDF; twins with
    ``expected_font_diffs`` evidence may carry a known mismatch."""
    try:
        import fitz  # noqa: F401
    except ImportError:
        return ["Tier 1.8 (fonts) requires PyMuPDF (run `uv sync`)"]
    failures: list[str] = []
    for name, t in TESTS.items():
        if t.kind != "twin":
            continue
        lref, tpdf = latex_pdf(name, t), typst_pdf(name)
        if not lref.exists() or not tpdf.exists():
            failures.append(f"{name}: missing PDF ({'LaTeX' if not lref.exists() else 'Typst'})")
            continue
        expected_failures = _check_expected_font_diffs(
            name, t, pdf_text(lref), pdf_text(tpdf)) if t.expected_font_diffs else []
        (lb, lfp), (tb, tfp) = _font_scan(lref), _font_scan(tpdf)
        miss, extra = lb - tb, tb - lb
        # Annotate each residual key with the first page it occurs on (LaTeX page
        # for LaTeX-only keys, Typst page for Typst-only) so a one-letter family
        # diff names where to look.
        show = lambda residual, fp: {
            k: (n, f"p{fp.get(k, '?')}") for k, n in list(residual.items())[:8]}
        if t.expected_font_diffs:
            failures.extend(expected_failures)
            actual = _residual_digest(miss, extra)
            expected = _expected_residual(name, "font")
            if not expected:
                failures.append(f"{name}: expected_font_diffs requires an exact font residual signature")
            elif actual != expected:
                failures.append(
                    f"{name}: font residual changed (expected {expected}, got {actual})\n"
                    f"    only in LaTeX: {show(miss, lfp)}\n"
                    f"    only in Typst: {show(extra, tfp)}")
            elif report:
                print(f"diff  {name}: exact expected font residual {actual[:12]}")
        elif miss or extra:
            failures.append(
                f"{name}: per-letter fonts differ (PyMuPDF; key = char,family,bold,italic,size,colour; count,firstpage)\n"
                f"    only in LaTeX: {show(miss, lfp)}\n"
                f"    only in Typst: {show(extra, tfp)}")
        elif report:
            print(f"ok   {name}: fonts match")
    return failures


# --- Tier 1.9: per-chunk reading-order gate (tagged structure tree) ---
# The word/char bags are order-independent by design, so an element emitted in the
# wrong place — an affiliation/email swap in the contact line, a reordered citation
# field — slips through them. Typst writes a tagged PDF, so each logical chunk
# (title, an author line, the contact block, a heading, a bib entry) is recoverable
# in logical order from the structure tree; we check by LCS that its tokens occur in
# that order in the flat (untagged) LaTeX stream. See tools/pdf_chunks.py.
def gate_order(report: bool = False) -> list[str]:
    """Tier 1.9 — intra-chunk reading order vs LaTeX. Each tagged Typst chunk's
    tokens must appear in the flat LaTeX stream in the chunk's own order (other
    content may interpose — the check is sub-sequence/LCS based, so it is immune to
    reflow, page breaks and column flow). Needs pikepdf; twins with
    ``expected_order_diffs`` evidence may carry a known mismatch."""
    try:
        import pikepdf  # noqa: F401
    except ImportError:
        return ["Tier 1.9 (order) requires pikepdf (run `uv sync`)"]
    import pdf_chunks as PC
    failures: list[str] = []
    for name, t in TESTS.items():
        if t.kind != "twin":
            continue
        lref, tpdf = latex_pdf(name, t), typst_pdf(name)
        if not lref.exists() or not tpdf.exists():
            failures.append(f"{name}: missing PDF ({'LaTeX' if not lref.exists() else 'Typst'})")
            continue
        expected_failures = _check_expected_order_diffs(
            name, t, pdf_text(lref), pdf_text(tpdf)) if t.expected_order_diffs else []
        if t.expected_order_diffs:
            failures.extend(expected_failures)
        stream = PC.latex_stream(lref)
        chunks = PC.typst_chunks(tpdf)
        if not chunks:
            failures.append(f"{name}: Typst PDF has no tagged chunks for the order gate")
            continue
        bad = [(role, toks, r) for role, toks in chunks
               if (r := PC.chunk_order(toks, stream))["disorder"]]
        if t.expected_order_diffs:
            residual = Counter({
                (role, tuple(toks), result["disorder"], result["present"]): 1
                for role, toks, result in bad
            })
            actual = _residual_digest(residual, Counter())
            expected = _expected_residual(name, "order")
            if not expected:
                failures.append(f"{name}: expected_order_diffs requires an exact order residual signature")
            elif actual != expected:
                failures.append(
                    f"{name}: order residual changed (expected {expected}, got {actual}); "
                    f"{len(bad)} chunk(s) now fail")
            elif report:
                print(f"diff  {name}: exact expected order residual {actual[:12]}")
        elif bad:
            lines = [f"{name}: {len(bad)} chunk(s) out of order vs LaTeX "
                     f"(structure-tree order vs flat stream; read both pdftotext dumps)"]
            for role, toks, r in bad[:4]:
                lines.append(f"    <{role}> disorder={r['disorder']}/{r['present']}: "
                             f"{' '.join(toks)[:70]!r}")
            failures.append("\n".join(lines))
        elif report:
            print(f"ok   {name}: chunk order matches")
    return failures


# --- Tier 1.85: tagged-PDF semantics ---------------------------------------
def _structure_elements(node):
    """Yield every structure element below a StructTreeRoot in document order."""
    import pikepdf
    if isinstance(node, pikepdf.Array):
        for item in node:
            yield from _structure_elements(item)
        return
    if not isinstance(node, pikepdf.Dictionary):
        return
    if "/S" in node:
        yield node
    children = node.get("/K")
    if children is not None:
        yield from _structure_elements(children)


def gate_structure(report: bool = False) -> list[str]:
    """Tier 1.85 — require tagging on representative fixtures, then pin
    semantic roles, document languages, and image alternative descriptions."""
    try:
        import pikepdf
    except ImportError:
        return ["Tier 1.85 (structure) requires pikepdf (run `uv sync`)"]

    expected_languages = {
        "language-test": "fr",
        "language-de-test": "de",
        "language-es-test": "es",
        "sample-sigplan": "en",
    }
    tagged_fixtures = (
        "title-test", "body2-test", "biblatex-driver-test",
        *expected_languages.keys(),
    )

    failures: list[str] = []
    for name in tagged_fixtures:
        pdf_path = typst_pdf(name)
        if not pdf_path.exists():
            failures.append(f"{name}: missing Typst PDF")
            continue
        with pikepdf.Pdf.open(pdf_path) as pdf:
            mark_info = pdf.Root.get("/MarkInfo")
            root = pdf.Root.get("/StructTreeRoot")
            if not mark_info or not bool(mark_info.get("/Marked")):
                failures.append(f"{name}: PDF catalog is not marked as tagged")
            if not root:
                failures.append(f"{name}: PDF has no structure tree")
            elif not any(str(elem.get("/S")) == "/Document"
                         for elem in _structure_elements(root)):
                failures.append(f"{name}: structure tree has no Document element")

    for name, expected in expected_languages.items():
        pdf_path = typst_pdf(name)
        if not pdf_path.exists():
            continue  # already reported by the representative-fixture pass above
        with pikepdf.Pdf.open(pdf_path) as pdf:
            actual = str(pdf.Root.get("/Lang", ""))
        if actual != expected:
            failures.append(f"{name}: PDF language {actual!r} != {expected!r}")

    sample = "sample-sigplan"
    sample_pdf = typst_pdf(sample)
    if not sample_pdf.exists():
        return failures
    with pikepdf.Pdf.open(sample_pdf) as pdf:
        elements = list(_structure_elements(pdf.Root.get("/StructTreeRoot")))
        roles = Counter(str(elem.get("/S")) for elem in elements)
        alternatives = Counter(
            str(elem.get("/Alt")) for elem in elements if "/Alt" in elem
        )
    required_roles = {
        "/Document", "/H1", "/H2", "/P", "/L", "/LI", "/Table", "/TR",
        "/TD", "/Figure", "/Caption", "/Link", "/Formula",
    }
    missing_roles = sorted(role for role in required_roles if not roles[role])
    if missing_roles:
        failures.append(f"{sample}: missing semantic roles {', '.join(missing_roles)}")
    expected_alternatives = Counter({
        "Enjoying the baseball game from the third-base seats. "
        "Ichiro Suzuki preparing to bat.": 1,
        "A woman and a girl in white dresses sit in an open car.": 1,
    })
    if alternatives != expected_alternatives:
        failures.append(
            f"{sample}: image alternatives changed\n"
            f"    expected: {dict(expected_alternatives)}\n"
            f"    actual:   {dict(alternatives)}")
    if report and not failures:
        print(
            f"ok   {len(tagged_fixtures)} tagged PDFs; languages; "
            f"{len(required_roles)} role kinds; "
            f"{sum(alternatives.values())} image alternatives")
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


def cmd_unit(_args) -> int:
    failures = gate_unit(report=True)
    for f in failures:
        print(f, file=sys.stderr)
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
    "package", "golden", "text", "metadata", "errors", "links", "validate",
    "fonts", "structure", "order", "outline", "metrics", "word-positions", "rules",
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
    for slug, title, thunk in _check_gates(args, compiled):
        if selected is not None and slug not in selected:
            continue
        print(f"\n== {title} ==")
        ok &= _run_gate(title, thunk())
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


# --- Vector recolor-overlay primitives (gs + qpdf + pdfjam, no rasterization) ---

def _page_count(pdf: Path) -> int:
    out = subprocess.run(["pdfinfo", str(pdf)], capture_output=True, text=True).stdout
    m = re.search(r"(?m)^Pages:\s*(\d+)", out)
    return int(m.group(1)) if m else 0


def _qpdf(argv: list[str]) -> None:
    # qpdf exits 3 on warnings (e.g. a recovered xref); only treat worse as fatal.
    p = subprocess.run(["qpdf", *argv], capture_output=True, text=True)
    if p.returncode not in (0, 3):
        raise RuntimeError(f"qpdf {argv}: {p.stderr.strip()}")


def _gs_recolor(src: Path, dst: Path, rgb: tuple[float, float, float], tmp: Path) -> None:
    """Recolor `src`'s device-colour vector ink to the flat colour `rgb` (0-1), losslessly.

    PDF colour operators (rg/g/k) aren't PostScript-level, so a `-c` override can't
    intercept them when gs reads a PDF directly; lowering to PostScript first (ps2write)
    turns them into setrgbcolor/setgray/setcmykcolor, which the second pass overrides.
    `bind` captures the *original* operators inside each redefinition, so the forced
    colour is set without recursing. Near-white is left alone so page backgrounds /
    knockouts aren't tinted.

    Coverage gap: ink set through a spot/ICC colourspace (`setcolor`, e.g. acmart's
    JDS cover panel and its text) and embedded images keep their original colours —
    intercepting `setcolor` generically needs per-colourspace operand counting that
    isn't worth the fragility. Typst output uses only device colours, so Typst always
    recolours fully; the gap only shows on a couple of LaTeX cover pages."""
    ps = tmp / f"{src.stem}.ps"
    subprocess.run(["gs", "-q", "-dNOPAUSE", "-dBATCH", "-sDEVICE=ps2write", "-o", str(ps), str(src)],
                   check=True, capture_output=True)
    flat = "{} {} {} setrgbcolor".format(*rgb)
    override = (
        f"/setrgbcolor{{3 copy add add 2.97 ge{{setrgbcolor}}{{pop pop pop {flat}}}ifelse}}bind def "
        f"/setgray{{dup .97 ge{{setgray}}{{pop {flat}}}ifelse}}bind def "
        f"/setcmykcolor{{4 copy add add add .03 le{{setcmykcolor}}{{pop pop pop pop {flat}}}ifelse}}bind def "
        f"/sethsbcolor{{pop pop pop {flat}}}bind def"
    )
    subprocess.run(["gs", "-q", "-dNOPAUSE", "-dBATCH", "-sDEVICE=pdfwrite",
                    "-o", str(dst), "-c", override, "-f", str(ps)], check=True, capture_output=True)


def _vector_overlay(name: str, ref: Path, ours: Path, tmp: Path, out: Path) -> Path:
    """Typst ink recoloured red, stacked on top of LaTeX ink recoloured blue, into `out`.

    Typst (red) is always the overlay and LaTeX (blue) the base: Typst pages don't
    paint an opaque background, so red sits on top without hiding LaTeX, while LaTeX's
    panels/cover fills stay underneath. Normal blend (not alpha), so on exact overlap
    red wins and any drift leaves a blue halo. If page counts differ, qpdf overlays
    the shared prefix and LaTeX's extra pages show solo (the side-by-side shows the
    rest)."""
    blue, red = tmp / f"{name}-blue.pdf", tmp / f"{name}-red.pdf"
    _gs_recolor(ref, blue, (0, 0, 1), tmp)
    _gs_recolor(ours, red, (1, 0, 0), tmp)
    _qpdf(["--overlay", str(red), "--", str(blue), str(out)])
    return out


def _vector_sidebyside(name: str, ref: Path, ours: Path, tmp: Path, out: Path) -> Path:
    """LaTeX | Typst into `out`: collate the two page-for-page, then 2-up each pair
    onto one framed landscape page (qpdf --collate + pdfjam)."""
    inter = tmp / f"{name}-inter.pdf"
    _qpdf(["--collate", "--empty", "--pages", str(ref), str(ours), "--", str(inter)])
    subprocess.run(["pdfjam", "--quiet", "--nup", "2x1", "--landscape", "--frame", "true",
                    str(inter), "-o", str(out)], check=True, capture_output=True)
    return out


def cmd_overlay(args) -> int:
    """Per-twin vector <name>-overlay.pdf + <name>-side-by-side.pdf (no raster).

    <name>-overlay.pdf: Typst ink recoloured red over LaTeX ink recoloured blue (gs+qpdf).
    <name>-side-by-side.pdf: LaTeX | Typst, 2-up per page (qpdf+pdfjam). Both keep
    selectable vector text; per-twin work runs in parallel."""
    stems = args.stems or [n for n, t in TESTS.items() if t.kind == "twin"]
    DIFF.mkdir(parents=True, exist_ok=True)
    # The previous combined bundles are superseded by the per-twin files; drop them
    # so the directory doesn't carry stale, misleading output.
    for stale in ("overlay.pdf", "side-by-side.pdf"):
        (DIFF / stale).unlink(missing_ok=True)

    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)

        def process(name: str):
            t = TESTS.get(name)
            if t is None:
                print(f"skip  {name}: not in test matrix")
                return None
            ref, ours = LATEX / f"{name}.pdf", typst_pdf(name)
            if not ref.exists() or not ours.exists():
                print(f"skip  {name}: missing {'LaTeX' if not ref.exists() else 'Typst'} PDF")
                return None
            ov = _vector_overlay(name, ref, ours, tmp, DIFF / f"{name}-overlay.pdf")
            sd = _vector_sidebyside(name, ref, ours, tmp, DIFF / f"{name}-side-by-side.pdf")
            print(f"{name:>20}: {ov.name} ({_page_count(ov)}p), {sd.name} ({_page_count(sd)}p)")
            return name

        results = [r for r in _pmap(process, stems, default_jobs()) if r]

    if not results:
        print("no PDFs produced (build them first: test.py build)")
        return 1
    print(f"\nwrote {2 * len(results)} PDFs to {DIFF.relative_to(ROOT)}/ — per twin, "
          "<name>-overlay.pdf (Typst red / LaTeX blue) + <name>-side-by-side.pdf (LaTeX | Typst), vector")
    return 0


# LaTeX/Typst templates for the validation suite (copyright modes + options).
_VALIDATE_TEX = r"""\documentclass[acmsmall{opts}]{{acmart}}
\acmJournal{{JACM}}
\acmVolume{{37}}\acmNumber{{4}}\acmArticle{{111}}\acmYear{{2018}}\acmMonth{{8}}
\acmDOI{{XXXXXXX.XXXXXXX}}\copyrightyear{{2018}}
{pre}
\begin{{document}}
\title{{Validating Options}}
\author{{Ben Trovato}}
\email{{trovato@corporation.com}}
\affiliation{{\institution{{Institute for Clarity in Documentation}}\city{{Dublin}}\country{{USA}}}}
\begin{{abstract}}
A short abstract used for validating acmart options and copyright modes.
\end{{abstract}}
\maketitle
\section{{Introduction}}\label{{sec:intro}}
Body text that visits \url{{https://www.acm.org}} and refers to \autoref{{sec:intro}}.
This sentence pads the paragraph with enough words to wrap onto a second line so
that review-mode line numbering has multiple lines to enumerate down the page.
\end{{document}}
"""

_VALIDATE_TYP = r"""#import "/src/lib.typ": acmart
#show: acmart.with(
  format: "acmsmall",
{opts}  title: "Validating Options",
  journal: "JACM", acm-volume: 37, acm-number: 4, acm-article: 111,
  acm-year: 2018, acm-month: 8, doi: "XXXXXXX.XXXXXXX", copyright-year: 2018,
  authors: ((name: "Ben Trovato", email: "trovato@corporation.com",
             affiliation: (institution: "Institute for Clarity in Documentation",
                           city: "Dublin", country: "USA")),),
  abstract: [A short abstract used for validating acmart options and copyright modes.],
)
= Introduction <sec:intro>
Body text that visits #link("https://www.acm.org") and refers to @sec:intro.
This sentence pads the paragraph with enough words to wrap onto a second line so
that review-mode line numbering has multiple lines to enumerate down the page.
"""


def _validate_variant_results(
    names: list[str],
    jobs: int,
    force: bool = False,
) -> list[tuple[str, float, str]]:
    import numpy as np
    from PIL import Image

    LATEX.mkdir(parents=True, exist_ok=True)
    TYPST.mkdir(parents=True, exist_ok=True)
    DIFF.mkdir(parents=True, exist_ok=True)

    def render(pdf: Path):
        with tempfile.TemporaryDirectory() as td:
            out = Path(td) / "p"
            subprocess.run(["pdftoppm", "-r", "150", "-f", "1", "-l", "1", "-png",
                            str(pdf), str(out)], check=True, capture_output=True)
            f = sorted(Path(td).glob("p*.png"))[0]
            return np.asarray(Image.open(f).convert("RGB"))

    def mismatch(a, b):
        ga, gb = a.mean(axis=2), b.mean(axis=2)
        h, w = max(ga.shape[0], gb.shape[0]), max(ga.shape[1], gb.shape[1])

        def pad(g):
            o = np.full((h, w), 255.0)
            o[:g.shape[0], :g.shape[1]] = g[:h, :w]
            return o

        return float((np.abs(pad(ga) - pad(gb)) > 40).mean()) * 100.0

    def save_side(name, ref, our):
        h, w = max(ref.shape[0], our.shape[0]), max(ref.shape[1], our.shape[1])

        def pad(im):
            o = np.full((h, w, 3), 255, np.uint8)
            o[:im.shape[0], :im.shape[1]] = im[:h, :w]
            return o

        gap = np.full((h, 16, 3), 255, np.uint8)
        Image.fromarray(np.concatenate([pad(ref), gap, pad(our)], axis=1)).save(
            DIFF / f"var-{name}-side.png")

    def variant(name: str) -> tuple[str, float, str]:
        opts, pre, typ_opts = M.VARIANTS[name]
        tex = LATEX / f"var-{name}.tex"
        new_tex = _VALIDATE_TEX.format(opts=opts, pre=pre)
        # Only rewrite when the content changes, so an unchanged variant keeps its
        # mtime and ref_is_fresh can skip its (slow) LaTeX rebuild.
        if not (tex.exists() and tex.read_text() == new_tex):
            tex.write_text(new_tex)
        typ = OUT / f"var-{name}.typ"
        typ.write_text(_VALIDATE_TYP.format(opts=typ_opts))
        if force or not ref_is_fresh(tex, LATEX / f"var-{name}.pdf"):
            latex_build(tex)
        rc, stderr = compile_typst(typ, TYPST / f"var-{name}.pdf")
        typ.unlink(missing_ok=True)
        if rc != 0:
            detail = stderr.strip() or f"rc={rc}"
            raise RuntimeError(f"{name}: Typst validation compile failed\n{detail}")
        ref, our = render(LATEX / f"var-{name}.pdf"), render(TYPST / f"var-{name}.pdf")
        save_side(name, ref, our)
        note = ""
        if name == "screen":
            def link_rgb(img):
                rgb = img.reshape(-1, 3).astype(int)
                colourful = rgb[(rgb.max(1) - rgb.min(1)) > 40]
                return colourful[colourful.sum(1).argmin()] if len(colourful) else None
            rc, oc = link_rgb(ref), link_rgb(our)
            if rc is not None and oc is not None:
                d = int(max(abs(rc - oc)))
                # A ±1-2/channel delta is expected (Typst writes CMYK as 8-bit).
                if d > 2:
                    note += f"link rgb ref~{tuple(rc)} our~{tuple(oc)} (Δ{d}) "
        return name, mismatch(ref, our), note

    ensure_class(LATEX)  # warm the class before the parallel fan-out (write race)
    return _pmap(variant, names, jobs)


def _validate_failures(rows: list[tuple[str, float, str]]) -> list[str]:
    failures = []
    missing = sorted(set(M.VARIANTS) - set(M.VARIANT_MISMATCH_MAX))
    extra = sorted(set(M.VARIANT_MISMATCH_MAX) - set(M.VARIANTS))
    if missing:
        failures.append("validation variants missing mismatch thresholds: " + ", ".join(missing))
    if extra:
        failures.append("validation thresholds without variants: " + ", ".join(extra))
    for name, pct, _note in rows:
        limit = M.VARIANT_MISMATCH_MAX.get(name)
        if limit is None:
            failures.append(f"{name}: no validation mismatch threshold")
        elif pct > limit:
            failures.append(f"{name}: validation mismatch {pct:.2f}% > {limit:.2f}%")
    return failures


def gate_validate(jobs: int, force: bool = False) -> list[str]:
    rows = _validate_variant_results(list(M.VARIANTS), jobs, force)
    return _validate_failures(rows)


def cmd_validate(args) -> int:
    names = args.names or list(M.VARIANTS)
    rows = _validate_variant_results(names, args.jobs, args.force)
    failures = _validate_failures(rows)
    print(f"{'variant':16} {'mismatch%':>9} {'max%':>7}   notes")
    print("-" * 60)
    for name, pct, note in rows:
        limit = M.VARIANT_MISMATCH_MAX.get(name)
        max_label = f"{limit:.2f}" if limit is not None else "unset"
        print(f"{name:16} {pct:9.2f} {max_label:>7}   {note}")
    print(f"\nside-by-sides: {DIFF.relative_to(ROOT)}/var-*-side.png")
    for failure in failures:
        print(f"FAIL {failure}", file=sys.stderr)
    return 1 if failures else 0


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


def cmd_linepitch(args) -> int:
    import numpy as np
    from PIL import Image

    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        subprocess.run(["pdftoppm", "-r", str(args.dpi), "-f", str(args.page),
                        "-l", str(args.page), "-png", args.pdf, str(tmp / "p")],
                       check=True, capture_output=True)
        png = sorted(tmp.glob("p*.png"))[0]
        img = np.asarray(Image.open(png).convert("L"), dtype=np.float32)

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
    sub.add_parser("min-version", help="compile compatibility fixtures under Typst 0.12.0").set_defaults(fn=cmd_min_version)

    o = sub.add_parser("overlay",
                       help="per-twin vector overlay + side-by-side PDFs vs LaTeX")
    o.add_argument("stems", nargs="*",
                   help="test stems to include (default: every twin)")
    o.set_defaults(fn=cmd_overlay)

    v = sub.add_parser("validate", parents=[par],
                       help="copyright/option variants vs LaTeX (page-1 mismatch pct)")
    v.add_argument("names", nargs="*", help="variant names (default: all)")
    v.set_defaults(fn=cmd_validate)

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
    sub.add_parser("structure", help="report tagged-PDF semantic checks").set_defaults(fn=cmd_structure)
    sub.add_parser("order", help="report the Tier 1.9 per-chunk reading-order check").set_defaults(fn=cmd_order)

    lp = sub.add_parser("linepitch", help="measure baseline pitch / first-line position")
    lp.add_argument("pdf")
    lp.add_argument("--dpi", type=int, default=300)
    lp.add_argument("--page", type=int, default=1)
    lp.set_defaults(fn=cmd_linepitch)

    args = ap.parse_args()
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
