#!/usr/bin/env python3
"""typst-acmart test & build harness — the one command runner.

This is the Python-owned replacement for the old Makefile + shell scripts. The
test data lives in `tools/test_matrix.py`; this file turns it into commands.

Run with the project venv (it has Pillow/numpy/fonttools for the visual diff and
validation):

    tools/venv/bin/python tools/test.py <command> [args]

Commands
--------
  build            build the LaTeX references, every Typst test PDF, and the example
  check            run all regression gates (smoke / unit / golden / text / errors / metrics)
  unit             run the pure-Typst unit tests in tests/unit/*.typ (no LaTeX needed)
  accept           rebuild Typst PDFs and refresh the Tier 1 golden hashes
  diff STEM        per-page side-by-side + overlay vs the LaTeX reference (--pages, --dpi)
  validate [names] copyright/option variants vs LaTeX, page-1 mismatch %
  probe            dump a format's ground-truth dimensions from the bundled class (--format)
  reference [name] build a LaTeX sample reference PDF (default: acmsmall)
  example          build the Typst example (template/main.typ)
  list             print the test matrix
  clean            remove all generated output (tests/out/)
  metrics          print the Tier 2 layout-metric table for every page (no gating)
  linepitch FILE   measure baseline pitch / first-line position in a PDF (--dpi, --page)

External tools required: Typst, TeX Live (pdflatex, bibtex), Poppler (pdftoppm,
pdftotext, pdfinfo). All generated output lives under tests/out/ (gitignored).
"""

from __future__ import annotations

import argparse
import difflib
import hashlib
import os
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
import unicodedata
from collections import Counter
from pathlib import Path

import test_matrix as M
from test_matrix import TESTS, Test, reference_for

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


# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------
def latex_pdf(name: str, t: Test) -> Path:
    return LATEX / f"{reference_for(name, t)}.pdf"


def typst_pdf(name: str) -> Path:
    return TYPST / f"{name}.pdf"


# ---------------------------------------------------------------------------
# PDF / raster helpers (Poppler)
# ---------------------------------------------------------------------------
def page_count(pdf: Path) -> int:
    out = subprocess.run(["pdfinfo", str(pdf)], capture_output=True, text=True).stdout
    m = re.search(r"^Pages:\s+(\d+)", out, re.M)
    return int(m.group(1)) if m else -1


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
        "­": "",    # soft hyphen
        "‐": "-", "‑": "-", "‒": "-", "–": "-",
        "—": "-", "−": "-",
        "‘": "'", "’": "'", "“": '"', "”": '"',
        "∗": "*", "⁎": "*", "∙": "•",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    # pdftotext often emits page folios as standalone lines; these are visual
    # page-style artifacts, not document text, and can differ harmlessly.
    text = re.sub(r"(?m)^\s*\d+\s*$", " ", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


# Edge punctuation stripped from each token before the word-bag comparison: we
# compare word *content*, so a trailing `,` vs `;` (where contact-info field
# separators or author-list joins differ between engines) is not a mismatch.
_EDGE_PUNCT = ".,;:!?()[]{}\"'*•-/"
# A hyphen at a line break (soft hyphen or a printable hyphen + EOL) is a
# typesetting artifact, not part of the word: rejoin `confer-\nence` -> `conference`
# so cross-engine line-breaking doesn't split one word into two tokens.
_EOL_HYPHEN = re.compile(r"[­‐‑-]\s*\n\s*")


# URL scheme prefix, tolerant of whitespace the engines insert at a break (LaTeX
# can split a DOI as `https:` <newline> `//doi…`). Stripped from both bags: where
# a URL breaks after the scheme pdftotext splits it off, and acmart vs our port
# disagree on whether the scheme is even shown — cosmetic; the path is what counts.
_URL_SCHEME = re.compile(r"https?\s*:\s*/\s*/")


def bag_tokens(raw: str) -> Counter:
    """Token multiset for order-independent text comparison of a raw pdftotext dump."""
    text = _URL_SCHEME.sub("", normalize(_EOL_HYPHEN.sub("", raw)))
    return Counter(t for w in text.split() if (t := w.strip(_EDGE_PUNCT)))


def bag_coverage(a: str, b: str) -> tuple[float, Counter, Counter]:
    """Fraction of tokens that agree as MULTISETS, plus the LaTeX-only / Typst-only rests.

    1.0 means identical bags regardless of order; lower means tokens went missing
    or appeared. Insensitive to block reordering, line breaks, and edge punctuation.
    """
    ca, cb = bag_tokens(a), bag_tokens(b)
    miss, extra = ca - cb, cb - ca
    total = sum(ca.values()) + sum(cb.values())
    return 1 - sum((miss + extra).values()) / max(1, total), miss, extra


# Quote/star/bullet glyph variants the two engines encode differently, folded to
# a canonical form for the char bag. Dashes are NOT here — they're dropped wholesale
# (below), because line-break hyphenation differs between engines (they break
# different words) and pdftotext drops the break hyphen inconsistently, so any
# surviving dash count is noise.
_CHAR_FOLD = {"‘": "'", "’": "'", "“": '"', "”": '"', "∗": "*", "⁎": "*", "∙": "•"}
_DROP_DASHES = str.maketrans("", "", "­‐‑‒–—−-")  # soft hyphen, hyphens, dashes, minus


def char_bag(raw: str) -> Counter:
    """Whitespace- and dash-free character multiset (NFKC + quote/star folding).

    A stricter tripwire than the word bag: order- and line-break-independent too,
    but it keeps punctuation, so a stray comma or period the word bag's edge-strip
    hides shows up here. Deliberately self-contained (not via normalize()) — it
    needs none of the word bag's tokenization machinery. What it does NOT check is
    delegated elsewhere: numbers and dashes to the word bag's tokens, page folios
    to the fixtures (titleless twins re-assert \\thispagestyle{empty} so neither
    engine prints one). Whatever difference survives here is real.
    """
    text = unicodedata.normalize("NFKC", raw).translate(_DROP_DASHES)
    for old, new in _CHAR_FOLD.items():
        text = text.replace(old, new)
    return Counter(re.sub(r"\s+", "", text))


_URI = re.compile(rb"/URI\s*\(([^)]*)\)")


def extract_uris(pdf: Path) -> set[str]:
    """Hyperlink (/URI) targets in a PDF. LaTeX/hyperref compresses annotations
    into object streams, so decompress with qpdf when available; Typst writes them
    uncompressed, so the raw pass already catches those."""
    data = pdf.read_bytes()
    found = set(_URI.findall(data))
    if shutil.which("qpdf"):
        out = subprocess.run(
            ["qpdf", "--qdf", "--object-streams=disable", "--decode-level=all", str(pdf), "-"],
            capture_output=True,
        ).stdout
        found |= set(_URI.findall(out))
    return {u.decode("latin1") for u in found}


# ---------------------------------------------------------------------------
# Typst compilation
# ---------------------------------------------------------------------------
def compile_typst(src: Path, out: Path) -> tuple[int, str]:
    """Compile a .typ via tc; return (returncode, stderr). Captures warnings."""
    out.parent.mkdir(parents=True, exist_ok=True)
    proc = subprocess.run(
        [str(TC), "compile", str(src), str(out), "--diagnostic-format", "short"],
        capture_output=True, text=True,
    )
    return proc.returncode, proc.stderr


def compile_all_typst() -> dict[str, tuple[int, str]]:
    """Compile every test's Typst source once into tests/out/typst/.

    Returns {name: (returncode, stderr)} so the smoke gate can inspect warnings
    without recompiling.
    """
    TYPST.mkdir(parents=True, exist_ok=True)
    results: dict[str, tuple[int, str]] = {}
    for name, t in TESTS.items():
        results[name] = compile_typst(TESTS_DIR / t.subdir / f"{name}.typ", typst_pdf(name))
    return results


# ---------------------------------------------------------------------------
# LaTeX build (ported from latex-build.sh / build-reference.sh)
# ---------------------------------------------------------------------------
# pdflatex/bibtex write non-UTF-8 bytes (font names etc.) to stdout; we read the
# .log file for status, so just swallow their console output decode-tolerantly.
def _quiet(cmd: list[str], **kw) -> None:
    subprocess.run(cmd, capture_output=True, text=True, errors="replace", **kw)


def _pdflatex(tex_basename: str, srcdir: Path, outdir: Path, env: dict) -> None:
    _quiet(
        ["pdflatex", "-interaction=nonstopmode", f"-output-directory={outdir}",
         str(srcdir / tex_basename)],
        env=env, cwd=outdir,
    )


def ensure_class(outdir: Path) -> None:
    """Generate acmart.cls (and bundled assets) into outdir from acmart/ sources.

    Always builds against the BUNDLED acmart class, never the system one — the two
    can differ (e.g. section-title uppercasing). Regenerated if missing or stale.
    """
    outdir.mkdir(parents=True, exist_ok=True)
    cls = outdir / "acmart.cls"
    dtx = ACMART / "acmart.dtx"
    if not cls.exists() or dtx.stat().st_mtime > cls.stat().st_mtime:
        for f in ("acmart.ins", "acmart.dtx"):
            (outdir / f).write_bytes((ACMART / f).read_bytes())
        _quiet(["pdflatex", "-interaction=nonstopmode", "acmart.ins"], cwd=outdir)
    for asset in ("ACM-Reference-Format.bst", "acm-jdslogo.png"):
        dst = outdir / asset
        if not dst.exists() and (ACMART / asset).exists():
            dst.write_bytes((ACMART / asset).read_bytes())


def latex_build(tex: Path, outdir: Path = LATEX) -> int:
    """Compile a .tex to a STABLE PDF in outdir; return its page count.

    Reruns pdflatex until cross-references / TotPages settle, runs bibtex, and
    fails if a 'Temporary page' placeholder survives or LaTeX reports an error.
    """
    outdir.mkdir(parents=True, exist_ok=True)
    ensure_class(outdir)
    srcdir = tex.resolve().parent
    base = tex.stem

    env = {
        **os.environ,
        # acmart.cls in outdir must win over any system install; include the
        # bundled sample bibliographies so twins can \bibliography{sample-base}.
        "TEXINPUTS": f"{outdir}:{srcdir}:",
        "BIBINPUTS": f"{outdir}:{srcdir}:{ACMART / 'samples'}:",
    }

    _pdflatex(f"{base}.tex", srcdir, outdir, env)
    _quiet(["bibtex", base], cwd=outdir, env=env)
    _pdflatex(f"{base}.tex", srcdir, outdir, env)

    log = outdir / f"{base}.log"
    for _ in range(6):
        text = log.read_text(errors="replace") if log.exists() else ""
        if re.search(r"Rerun to get|Label\(s\) may have changed|Temporary page", text):
            _pdflatex(f"{base}.tex", srcdir, outdir, env)
        else:
            break

    pdf = outdir / f"{base}.pdf"
    if not pdf.exists():
        raise SystemExit(f"ERROR: {pdf} was not produced (see {log}).")
    logtext = log.read_text(errors="replace") if log.exists() else ""
    if re.search(r"(?m)^! |Emergency stop|Fatal error occurred|No output PDF file produced", logtext):
        raise SystemExit(f"ERROR: LaTeX reported an error building {base} (see {log}).")
    if "Temporary page" in pdf_text(pdf):
        raise SystemExit(f"ERROR: {pdf} still contains a 'Temporary page'.")
    return page_count(pdf)


def extract_samples(outdir: Path) -> None:
    """Copy the acmart sample sources into outdir and run samples.ins to extract them."""
    samples = ACMART / "samples"
    for f in ("samples.ins", "samples.dtx"):
        (outdir / f).write_bytes((samples / f).read_bytes())
    for src in list(samples.glob("*.bib")) + list(samples.glob("*.png")) + [
        ACMART / "ACM-Reference-Format.bst"
    ]:
        if src.exists():
            (outdir / src.name).write_bytes(src.read_bytes())
    _quiet(["pdflatex", "-interaction=nonstopmode", "samples.ins"], cwd=outdir)


def build_reference(sample: str = "acmsmall", outdir: Path = LATEX) -> int:
    """Build a LaTeX sample reference PDF (e.g. acmsmall) into outdir."""
    outdir.mkdir(parents=True, exist_ok=True)
    ensure_class(outdir)
    if not (outdir / f"{sample}.tex").exists():
        extract_samples(outdir)
    return latex_build(outdir / f"{sample}.tex", outdir)


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
# could change its output: the class source, the bundled sample sources/bibs/bst,
# and the twins' own .bib files. This is deliberately conservative — touching any
# .bib rebuilds all refs — because over-invalidating is cheap and correctness
# beats precision here. `--force` bypasses it entirely.
_shared_inputs_mtime_cache: float | None = None


def _shared_inputs_mtime() -> float:
    global _shared_inputs_mtime_cache
    if _shared_inputs_mtime_cache is None:
        paths = [ACMART / "acmart.dtx", ACMART / "ACM-Reference-Format.bst"]
        paths += list((ACMART / "samples").glob("*.dtx"))
        paths += list((ACMART / "samples").glob("*.bib"))
        paths += list((TESTS_DIR / "twins").glob("*.bib"))
        _shared_inputs_mtime_cache = max(
            (p.stat().st_mtime for p in paths if p.exists()), default=0.0)
    return _shared_inputs_mtime_cache


def ref_is_fresh(tex: Path, pdf: Path) -> bool:
    """True if ``pdf`` is up to date with ``tex`` and all shared LaTeX inputs."""
    if not pdf.exists() or not tex.exists():
        return False
    return pdf.stat().st_mtime >= max(tex.stat().st_mtime, _shared_inputs_mtime())


def build_all_latex(jobs: int = 1, force: bool = False) -> None:
    """Build every LaTeX reference the matrix needs: twin .tex files + sample refs.

    Twin references are independent, so they build in parallel (``jobs`` at a
    time). Up-to-date references are skipped unless ``force`` (see ``ref_is_fresh``).
    """
    ensure_class(LATEX)  # serial, before fan-out: avoids a class/asset write race
    # Upstream-ref samples first (extracts the sample sources once; usually just
    # acmsmall). Kept serial because the first one runs the shared extract step.
    samples = {reference_for(n, t) for n, t in TESTS.items() if t.kind == "upstream-ref"}
    for s in sorted(samples):
        if not force and ref_is_fresh(LATEX / f"{s}.tex", LATEX / f"{s}.pdf"):
            print(f"  reference {s} (cached)")
            continue
        print(f"  reference {s}")
        build_reference(s)

    twins = [(name, TESTS_DIR / t.subdir / f"{name}.tex")
             for name, t in TESTS.items() if t.kind == "twin"]

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
def gate_smoke(compiled: dict[str, tuple[int, str]]) -> list[str]:
    """Tier 0 — compile cleanliness, page counts, twin page-count parity.

    Uses the already-captured compile results (no recompilation).
    """
    failures: list[str] = []
    for name, t in TESTS.items():
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

        if t.page_parity:
            lref = latex_pdf(name, t)
            if lref.exists():
                lp = page_count(lref)
                if lp != got:
                    local.append(f"{name}: page-count parity broken (LaTeX {lp} vs Typst {got})")
            else:
                local.append(f"{name}: LaTeX reference {lref.name} missing (run `test.py build`)")

        if not local:
            print(f"ok   {name} ({got}p)")
        failures.extend(local)
    return failures


def _golden_hashes() -> dict[str, list[str]]:
    out: dict[str, list[str]] = {}
    for name, t in TESTS.items():
        if not t.golden:
            continue
        pdf = typst_pdf(name)
        if pdf.exists():
            out[name] = page_hashes(pdf, M.GOLDEN_DPI)
    return out


def write_golden() -> None:
    GOLDEN.mkdir(parents=True, exist_ok=True)
    hashes = _golden_hashes()
    lines = [
        f"# Tier 1 golden raster hashes — Typst {M.TYPST_VERSION} @ {M.GOLDEN_DPI}dpi",
        "# regenerate with: tools/test.py accept",
    ]
    for name in sorted(hashes):
        for i, h in enumerate(hashes[name], 1):
            lines.append(f"{name} {i} {h}")
    GOLDEN_FILE.write_text("\n".join(lines) + "\n")


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
        if not t.golden:
            print(f"skip {name} (golden disabled)")
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


def _assertion_targets(name: str, t: Test, a: M.Assertion) -> list[tuple[str, Path]]:
    if a.engine == "typst":
        return [("Typst", typst_pdf(name))]
    if a.engine == "latex":
        return [("LaTeX", latex_pdf(name, t))]
    if a.engine == "both":
        return [("LaTeX", latex_pdf(name, t)), ("Typst", typst_pdf(name))]
    raise ValueError(f"unknown text assertion engine {a.engine!r}")


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
            ltext, ttext = normalize(lraw), normalize(traw)
            if ltext != ttext:
                local.append(f"{name}: normalized text differs\n    {_first_diff(ltext, ttext)}")
            elif report:
                print(f"equal {name}")
        elif t.text_equal == "bag":
            cov, miss, extra = bag_coverage(lraw, traw)
            if miss or extra:
                local.append(
                    f"{name}: word bags differ ({cov * 100:.2f}% common)\n"
                    f"    only in LaTeX: {', '.join(list(miss)[:12])}\n"
                    f"    only in Typst: {', '.join(list(extra)[:12])}")
            elif report:
                print(f"bag   {name}: word-bag exact (order-independent)")
        elif t.text_equal is False:
            if not t.text_reason:
                local.append(f"{name}: text_equal=false requires text_reason")
            elif report:
                print(f"skip  {name}: {t.text_reason}")
        elif report:
            print(f"skip  {name}: text equality not configured")

        # Universal char-bag tripwire on top of the above: every twin's content
        # must match as an exact character multiset (order-, line-break-, number-
        # and scheme-independent), unless it carries a documented char_diff
        # exemption — a known content difference or a pdftotext extraction artifact.
        if t.char_diff:
            if report:
                print(f"skip  {name}: char bag exempt ({t.char_diff})")
        else:
            ca, cb = char_bag(lraw), char_bag(traw)
            cm, ce = ca - cb, cb - ca
            if cm or ce:
                local.append(
                    f"{name}: char bags differ (read both pdftotext dumps to locate)\n"
                    f"    only in LaTeX: {dict(cm)}\n    only in Typst: {dict(ce)}")
            elif report:
                print(f"char  {name}: exact")

        for i, a in enumerate(t.text_assertions, 1):
            needle = normalize(a.text)
            if not needle:
                local.append(f"{name}: text assertion {i} has empty text")
                continue
            for label, pdf in _assertion_targets(name, t, a):
                haystack = normalize(pdf_text(pdf, page=a.page))
                scope = f" page {a.page}" if a.page is not None else ""
                if a.kind == "contains" and needle not in haystack:
                    local.append(f"{name}: {label}{scope} missing text assertion {i}: {needle!r}")
                elif a.kind == "absent" and needle in haystack:
                    local.append(f"{name}: {label}{scope} contains forbidden assertion {i}: {needle!r}")
                elif a.kind not in ("contains", "absent"):
                    local.append(f"{name}: unknown text assertion kind {a.kind!r}")

        if not local and not report and (
                t.text_equal is not None or t.text_assertions or not t.char_diff):
            print(f"ok   {name}")
        failures.extend(local)
    return failures


def _error_source(extra_arg: str, body: str = "= Body\nText.") -> str:
    return f"""#import "/src/lib.typ": acmart

#show: acmart.with(
  format: "acmsmall",
  title: "Expected Error",
  authors: ((name: "Ada Lovelace"),),
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
            capture_output=True, text=True,
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
        if not t.metrics or t.kind != "twin":
            if not report and t.kind == "twin":
                print(f"skip {name} (metrics disabled)")
            continue
        lref, tpdf = latex_pdf(name, t), typst_pdf(name)
        if not lref.exists() or not tpdf.exists():
            failures.append(f"{name}: missing PDF ({'LaTeX' if not lref.exists() else 'Typst'})")
            continue
        lm, tm = _metrics_for(lref), _metrics_for(tpdf)
        pages = [1] if t.page1_only else sorted(set(lm) & set(tm))
        gated = [("left", tol["left"], "left margin"), ("top", tol["top"], "top margin")]
        if t.uniform_pitch:
            gated.append(("pitch", tol["pitch"], "baseline pitch"))

        # Per-line pitch is gated only on SINGLE-page uniform_pitch twins. A
        # multi-page doc's page 1 is full, so acmsmall's \@textbottom rubber glue
        # stretches its paragraph gaps to the bottom margin (the documented fill we
        # can't replicate) — gating per-line spacing there would chase that drift.
        line_pitch = t.uniform_pitch and t.pages == 1
        if report:
            print(name + ":")
        local: list[str] = []
        for p in pages:
            a, b = lm.get(p), tm.get(p)
            if a is None or b is None:
                continue
            lpd = _line_pitch_drift(a["pitches"], b["pitches"]) if line_pitch else None
            if report:
                lpd_s = (f"  line-pitch {lpd[0]:.2f}pt×{lpd[1]}" if lpd and lpd[1]
                         else "  line-pitch n/a (lines differ)" if line_pitch else "")
                print(f"  {name} p{p}: "
                      f"L {a['left']:.1f}/{b['left']:.1f}  R {a['right']:.1f}/{b['right']:.1f}  "
                      f"T {a['top']:.1f}/{b['top']:.1f}  "
                      f"lines {a['lines']}/{b['lines']}  pitch {a['pitch']:.2f}/{b['pitch']:.2f}"
                      f"{lpd_s}   (L/T/pitch/line-pitch gated; R/lines report-only)")
                continue
            for key, lim, label in gated:
                d = abs(a[key] - b[key])
                if d > lim:
                    local.append(f"{name} p{p}: {label} Δ={d:.2f}pt (LaTeX {a[key]:.2f} vs "
                                 f"Typst {b[key]:.2f}, tol {lim})")
            # Per-line pitch: only when the line-break structure matches (aligned
            # pitch sequences); otherwise the median pitch above is the gate.
            if lpd and lpd[1] and lpd[0] > tol["line_pitch"]:
                local.append(f"{name} p{p}: single-line pitch Δ={lpd[0]:.2f}pt over {lpd[1]} "
                             f"lines (tol {tol['line_pitch']}) — a line is off the body grid")
        if not report and not local:
            print(f"ok   {name}")
        failures.extend(local)
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
    bad = [n for n, (rc, _) in compiled.items() if rc != 0]
    print("Building the Typst example…")
    compile_typst(TEMPLATE, TYPST / "main.pdf")
    print(f"\nBuilt {len(TESTS)} Typst PDFs + example into {TYPST.relative_to(ROOT)}/.")
    if bad:
        print(f"WARNING: {len(bad)} Typst sources failed to compile: {', '.join(bad)}",
              file=sys.stderr)
        return 1
    return 0


def gate_links(report: bool = False) -> list[str]:
    """Tier 1.7 — hyperlink (/URI) set must match LaTeX+hyperref, for twins that
    set link_check (e.g. the bst-backend bib-all, whose DOI/URL/arXiv links are a
    fidelity goal pdftotext can't see)."""
    failures: list[str] = []
    for name, t in TESTS.items():
        if not getattr(t, "link_check", False) or t.kind != "twin":
            continue
        lref, tpdf = latex_pdf(name, t), typst_pdf(name)
        if not lref.exists() or not tpdf.exists():
            failures.append(f"{name}: missing PDF ({'LaTeX' if not lref.exists() else 'Typst'})")
            continue
        lu, tu = extract_uris(lref), extract_uris(tpdf)
        miss, extra = lu - tu, tu - lu
        if miss or extra:
            failures.append(
                f"{name}: hyperlink sets differ\n"
                f"    only in LaTeX: {sorted(miss)}\n    only in Typst: {sorted(extra)}")
        elif report:
            print(f"ok   {name}: {len(tu)} hyperlinks match")
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
    gate_unit(report=True)
    failures = gate_unit()
    return 1 if failures else 0


def cmd_check(args) -> int:
    print("Building LaTeX references…")
    build_all_latex(jobs=args.jobs, force=args.force)
    print("Compiling Typst test PDFs once…")
    compiled = compile_all_typst()

    ok = True
    print("\n== Tier 0 (smoke) ==")
    ok &= _run_gate("Tier 0 (smoke)", gate_smoke(compiled))
    print("\n== Tier 0.5 (unit) ==")
    ok &= _run_gate("Tier 0.5 (unit)", gate_unit())
    print("\n== Tier 1 (golden) ==")
    ok &= _run_gate("Tier 1 (golden)", gate_golden())
    print("\n== Tier 1.5 (text) ==")
    ok &= _run_gate("Tier 1.5 (text)", gate_text())
    print("\n== Tier 1.6 (expected errors) ==")
    ok &= _run_gate("Tier 1.6 (expected errors)", gate_errors())
    print("\n== Tier 1.7 (hyperlinks) ==")
    ok &= _run_gate("Tier 1.7 (hyperlinks)", gate_links())
    print("\n== Tier 2 (metrics) ==")
    ok &= _run_gate("Tier 2 (metrics)", gate_metrics())
    return 0 if ok else 1


def cmd_accept(_args) -> int:
    print("Compiling Typst test PDFs…")
    compile_all_typst()
    write_golden()
    print(f"wrote {GOLDEN_FILE.relative_to(ROOT)}")
    return 0


def cmd_reference(args) -> int:
    pages = build_reference(args.sample)
    print(f"Built {LATEX / (args.sample + '.pdf')} ({pages} pages)")
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


def cmd_diff(args) -> int:
    import numpy as np
    from PIL import Image

    t = TESTS.get(args.stem)
    ref_stem = reference_for(args.stem, t) if t else args.stem
    ref = LATEX / f"{ref_stem}.pdf"
    ours = typst_pdf(args.stem)
    DIFF.mkdir(parents=True, exist_ok=True)

    def render(pdf: Path, tag: str, tmp: Path) -> list[Path]:
        subprocess.run(["pdftoppm", "-r", str(args.dpi), "-png", str(pdf), str(tmp / tag)],
                       check=True, capture_output=True)
        return sorted(tmp.glob(f"{tag}-*.png"))

    def to_gray(p: Path):
        return np.asarray(Image.open(p).convert("L"), dtype=np.float32)

    def pad(arr, h, w):
        o = np.full((h, w), 255.0, dtype=arr.dtype)
        o[:arr.shape[0], :arr.shape[1]] = arr[:h, :w]
        return o

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

    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        ref_pngs = render(ref, "ref", tmp)
        our_pngs = render(ours, "our", tmp)
        npages = max(len(ref_pngs), len(our_pngs))
        pages = parse_pages(args.pages, npages)
        print(f"reference: {len(ref_pngs)} pages, ours: {len(our_pngs)} pages, dpi={args.dpi}")
        for i in pages:
            r = to_gray(ref_pngs[i]) if i < len(ref_pngs) else None
            o = to_gray(our_pngs[i]) if i < len(our_pngs) else None
            if r is None or o is None:
                print(f"page {i+1}: MISSING in {'ours' if o is None else 'reference'}")
                continue
            h, w = max(r.shape[0], o.shape[0]), max(r.shape[1], o.shape[1])
            r, o = pad(r, h, w), pad(o, h, w)
            mismatch = float((np.abs(r - o) > 40).mean()) * 100.0
            print(f"page {i+1}: {mismatch:5.2f}% mismatch  "
                  f"(ref {ref.name}, our {ours.name})")
            overlay = np.full((h, w, 3), 255, dtype=np.uint8)
            ref_ink, our_ink = 255 - r, 255 - o
            overlay[..., 0] = (255 - our_ink).astype(np.uint8)
            overlay[..., 2] = (255 - ref_ink).astype(np.uint8)
            overlay[..., 1] = (255 - np.maximum(ref_ink, our_ink)).astype(np.uint8)
            Image.fromarray(overlay).save(DIFF / f"overlay-p{i+1:02d}.png")
            gap = 16
            sbs = np.full((h, w * 2 + gap), 255, dtype=np.uint8)
            sbs[:, :w] = r.astype(np.uint8)
            sbs[:, w + gap:] = o.astype(np.uint8)
            Image.fromarray(sbs).save(DIFF / f"side-p{i+1:02d}.png")
    print(f"\nwrote diffs to {DIFF.relative_to(ROOT)}/ "
          "(overlay-pNN.png = ref red / ours blue / shared dark; side-pNN.png = ref | ours)")
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


def cmd_validate(args) -> int:
    import numpy as np
    from PIL import Image

    names = args.names or list(M.VARIANTS)
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

    def variant(name: str) -> str:
        opts, pre, typ_opts = M.VARIANTS[name]
        tex = LATEX / f"var-{name}.tex"
        new_tex = _VALIDATE_TEX.format(opts=opts, pre=pre)
        # Only rewrite when the content changes, so an unchanged variant keeps its
        # mtime and ref_is_fresh can skip its (slow) LaTeX rebuild.
        if not (tex.exists() and tex.read_text() == new_tex):
            tex.write_text(new_tex)
        typ = OUT / f"var-{name}.typ"
        typ.write_text(_VALIDATE_TYP.format(opts=typ_opts))
        if args.force or not ref_is_fresh(tex, LATEX / f"var-{name}.pdf"):
            latex_build(tex)
        compile_typst(typ, TYPST / f"var-{name}.pdf")
        typ.unlink()
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
        return f"{name:16} {mismatch(ref, our):9.2f}   {note}"

    ensure_class(LATEX)  # warm the class before the parallel fan-out (write race)
    rows = _pmap(variant, names, args.jobs)
    print(f"{'variant':16} {'mismatch%':>9}   notes")
    print("-" * 50)
    for row in rows:
        print(row)
    print(f"\nside-by-sides: {DIFF.relative_to(ROOT)}/var-*-side.png")
    return 0


def cmd_list(_args) -> int:
    print(f"{'stem':24} {'kind':13} pages  flags")
    print("-" * 78)
    for name, t in TESTS.items():
        flags = []
        if t.reference:
            flags.append(f"ref={t.reference}")
        if t.page1_only:
            flags.append("page1_only")
        if t.uniform_pitch:
            flags.append("uniform_pitch")
        if t.text_equal is True:
            flags.append("text_equal")
        elif t.text_equal == "bag":
            flags.append("text_bag")
        if t.text_assertions:
            flags.append(f"assert×{len(t.text_assertions)}")
        if not t.metrics:
            flags.append("no-metrics")
        if not t.golden:
            flags.append("no-golden")
        print(f"{name:24} {t.kind:13} {t.pages:>5}  {' '.join(flags)}")
    print(f"\n{len(TESTS)} tests "
          f"({sum(t.kind == 'twin' for t in TESTS.values())} twin, "
          f"{sum(t.kind == 'upstream-ref' for t in TESTS.values())} upstream-ref, "
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
    sub.add_parser("check", parents=[par],
                   help="run all regression gates").set_defaults(fn=cmd_check)
    sub.add_parser("accept", help="rebuild Typst PDFs and refresh golden hashes").set_defaults(fn=cmd_accept)
    sub.add_parser("unit", help="run pure-Typst unit tests (tests/unit/*.typ); no LaTeX").set_defaults(fn=cmd_unit)

    d = sub.add_parser("diff", help="visual diff a Typst output vs its LaTeX reference")
    d.add_argument("stem")
    d.add_argument("--pages", default=None, help="e.g. 1-2 or 1,3 (default: all)")
    d.add_argument("--dpi", type=int, default=150)
    d.set_defaults(fn=cmd_diff)

    v = sub.add_parser("validate", parents=[par],
                       help="copyright/option variants vs LaTeX (page-1 mismatch pct)")
    v.add_argument("names", nargs="*", help="variant names (default: all)")
    v.set_defaults(fn=cmd_validate)

    p = sub.add_parser("probe", help="dump a format's dimensions from the bundled class")
    p.add_argument("--format", default="acmsmall")
    p.set_defaults(fn=cmd_probe)

    r = sub.add_parser("reference", help="build a LaTeX sample reference PDF")
    r.add_argument("sample", nargs="?", default="acmsmall")
    r.set_defaults(fn=cmd_reference)

    sub.add_parser("example", help="build the Typst example (template/main.typ)").set_defaults(fn=cmd_example)
    sub.add_parser("list", help="print the test matrix").set_defaults(fn=cmd_list)
    sub.add_parser("clean", help="remove tests/out/").set_defaults(fn=cmd_clean)
    sub.add_parser("metrics", help="print the Tier 2 metric table (no gating)").set_defaults(fn=cmd_metrics)

    lp = sub.add_parser("linepitch", help="measure baseline pitch / first-line position")
    lp.add_argument("pdf")
    lp.add_argument("--dpi", type=int, default=300)
    lp.add_argument("--page", type=int, default=1)
    lp.set_defaults(fn=cmd_linepitch)

    args = ap.parse_args()
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
