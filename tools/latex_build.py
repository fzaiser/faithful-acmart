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


# Stage these dependencies beside acmart.cls so TeX resolves the bundled versions.
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

# Concurrent first-use Biber processes race while extracting into the macOS PAR cache.
_BIBER_LOCK = threading.Lock()


def _sync_file(src: Path, dst: Path) -> None:
    """Copy changed files while preserving mtimes for unchanged inputs."""
    data = src.read_bytes()
    if not dst.exists() or dst.read_bytes() != data:
        dst.write_bytes(data)


# TeX tools can emit non-UTF-8 font names.
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
    """Compile until references stabilize and return the page count.

    Fail on tool errors or unresolved placeholders."""
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
# Include shared bibliography and image inputs when invalidating cached references.
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
    if not pdf.exists() or not tex.exists():
        return False
    return pdf.stat().st_mtime >= max(tex.stat().st_mtime, _shared_inputs_mtime())
def gate_latex_oracle(report: bool = False) -> list[str]:
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
    ensure_class(LATEX)  # Stage shared assets before parallel builds to avoid write races.
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
