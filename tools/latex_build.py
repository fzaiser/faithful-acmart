"""LaTeX reference building.

Stage the bundled acmart class + vendored assets, compile a ``.tex`` to a stable
PDF (rerunning until cross-references settle), and the latex-oracle gate that
verifies the staged dependencies and the log recognizers."""

from __future__ import annotations

import os
import re
import subprocess
import threading
from pathlib import Path

from test_matrix import TESTS
from harness import (
    ROOT, LATEX, ACMART, TESTS_DIR, TEST_CLOCK_ENV, _pmap,
)
from pdf_extract import page_count, pdf_text


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
