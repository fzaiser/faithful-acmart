"""Install and select the pinned TeX Live that builds the LaTeX references."""

from __future__ import annotations

import hashlib
import os
import shutil
import subprocess
import tarfile
import tempfile
from pathlib import Path


# Font residuals depend on exact package versions, so references come from a frozen repository.
TEXLIVE_YEAR = "2025"
REPOSITORY = f"https://ftp.math.utah.edu/pub/tex/historic/systems/texlive/{TEXLIVE_YEAR}/tlnet-final"

PACKAGES = (
    "amsfonts", "amsmath", "auxhook", "babel", "babel-english", "babel-french",
    "babel-german", "babel-spanish", "biber", "biblatex", "biblatex-trad", "bibtex",
    "bigintcalc", "bitset", "booktabs", "caption", "carlisle", "cmap", "comment",
    "doclicense", "draftwatermark", "ec", "environ", "epstopdf-pkg", "etexcmds",
    "etoolbox", "everyshi", "fancyhdr", "figureversions", "float", "fontaxes",
    "fontname", "framed", "geometry", "gettitlestring", "graphics", "graphics-cfg",
    "graphics-def", "hycolor", "hyperref", "hyperxmp", "hyphen-french", "hyphen-german",
    "hyphen-spanish", "ifmtarg", "iftex", "inconsolata", "infwarerr", "intcalc",
    "kastrup", "kvdefinekeys", "kvoptions", "kvsetkeys", "l3backend", "l3kernel",
    "l3packages", "latex", "latex-bin", "latexconfig", "libertine", "logreq", "ltxcmds",
    "microtype", "mmap", "mptopdf", "natbib", "ncctools", "newtx", "oberdiek",
    "pdfescape", "pdftex", "pdftexcmds", "preprint", "refcount", "rerunfilecheck",
    "setspace", "stringenc", "totpages", "trimspaces", "uniquecounter", "upquote",
    "url", "xcolor", "xkeyval", "xpatch", "xstring", "xurl", "zref",
)

TEXLIVE_DIR = (Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
               / "faithful-acmart" / f"texlive-{TEXLIVE_YEAR}")
STAMP = TEXLIVE_DIR / "installed.sha256"


def _fingerprint() -> str:
    return hashlib.sha256("\n".join([REPOSITORY, *sorted(PACKAGES)]).encode()).hexdigest()


def _installed() -> bool:
    return STAMP.exists() and STAMP.read_text().strip() == _fingerprint()


def _bin_dir() -> Path:
    return next((TEXLIVE_DIR / "bin").iterdir())


def texlive_env(env: dict[str, str] | None = None) -> dict[str, str]:
    """Return `env` (default: this process's) with the pinned TeX Live first on PATH."""
    if not _installed():
        raise SystemExit(
            f"TeX Live {TEXLIVE_YEAR} for the LaTeX references is missing or outdated in "
            f"{TEXLIVE_DIR}; run `uv run python tools/test.py texlive`.")
    selected = dict(os.environ if env is None else env)
    selected["PATH"] = f"{_bin_dir()}{os.pathsep}{selected.get('PATH', '')}"
    return selected


def cmd_texlive(_args) -> int:
    if _installed():
        print(f"TeX Live {TEXLIVE_YEAR} is up to date in {TEXLIVE_DIR}")
        return 0
    shutil.rmtree(TEXLIVE_DIR, ignore_errors=True)
    with tempfile.TemporaryDirectory() as td:
        work = Path(td)
        archive = work / "install-tl-unx.tar.gz"
        subprocess.run(["curl", "-fsSL", "-o", str(archive), f"{REPOSITORY}/install-tl-unx.tar.gz"],
                       check=True)
        with tarfile.open(archive) as tar:
            tar.extractall(work, filter="data")
        installer = next(work.glob("install-tl-*/install-tl"))
        profile = work / "texlive.profile"
        # Portable mode keeps TEXMFHOME and the per-user trees inside TEXLIVE_DIR.
        profile.write_text(
            "selected_scheme scheme-infraonly\n"
            f"TEXDIR {TEXLIVE_DIR}\n"
            f"TEXMFLOCAL {TEXLIVE_DIR}/texmf-local\n"
            f"TEXMFHOME {TEXLIVE_DIR}/texmf-local\n"
            f"TEXMFSYSCONFIG {TEXLIVE_DIR}/texmf-config\n"
            f"TEXMFCONFIG {TEXLIVE_DIR}/texmf-config\n"
            f"TEXMFSYSVAR {TEXLIVE_DIR}/texmf-var\n"
            f"TEXMFVAR {TEXLIVE_DIR}/texmf-var\n"
            "instopt_portable 1\n"
            "instopt_adjustpath 0\n"
            "instopt_adjustrepo 0\n"
            "tlpdbopt_autobackup 0\n"
            "tlpdbopt_install_docfiles 0\n"
            "tlpdbopt_install_srcfiles 0\n")
        subprocess.run(["perl", str(installer), "--profile", str(profile),
                        "--repository", REPOSITORY], check=True)
    subprocess.run([str(_bin_dir() / "tlmgr"), "--repository", REPOSITORY, "install", *PACKAGES],
                   check=True)
    STAMP.write_text(_fingerprint() + "\n")
    print(f"Installed TeX Live {TEXLIVE_YEAR} in {TEXLIVE_DIR}")
    return 0
