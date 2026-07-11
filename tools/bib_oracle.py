"""On-demand .bib-reader byte-identity oracle.

Compares the pure-Typst ``.bib`` reader against real bibtex over the twins' and
the mutation-corpus ``.bib`` files, using a dump-everything ``.bst``. Not part of
``check`` — it needs the real bibtex binary and is a maintenance audit."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from harness import ROOT, OUT, TESTS_DIR, ACMART


# --- bib-oracle: real-bibtex .bib-reader byte-identity oracle (on-demand) ---
#
# The pure-Typst .bib reader (src/parts/bibtex.typ) claims byte-identity with real
# bibtex on well-formed input, diverging only where bibtex REJECTS the input (its
# crate-style \{ \} \" escaping). This command keeps that property from rotting: a
# generated dump .bst re-emits every entry's parsed field VALUES, and the Typst
# reader's field values are compared against them over the twins' .bib files plus
# the in-repo mutation corpus (tests/bib-oracle/). It is on-demand only (NOT in
# `check`/CI): it needs the real bibtex binary and is a maintenance audit, not a
# gate. Inputs must be well-formed — the corpus documents that contract.
_ORACLE_FIELDS = (
    "address advisor archiveprefix author booktitle chapter city date edition "
    "editor eprint eprinttype eprintclass howpublished institution journal key "
    "location month note number organization pages primaryclass publisher school "
    "series title type volume year issue articleno eid day doi url bookpages "
    "numpages lastaccessed coden isbn issn lccn distinctURL archived venue"
).split()

# Typst reader as a queryable metadata dump; reads the .bib named by sys.inputs.
_ORACLE_TYP = (
    '#import "/src/parts/bibtex.typ": parse-bib\n'
    "#metadata(parse-bib(read(sys.inputs.bib))) <bib-oracle>\n"
)


def _oracle_bst() -> str:
    """A dump-everything .bst: seeds the ACM BST's own MACROs (so month/journal
    expansion matches the reader) and writes each present field verbatim."""
    bst_src = (ACMART / "ACM-Reference-Format.bst").read_text()
    macros = re.findall(r'MACRO\s*\{([^}]+)\}\s*\{("[^"]*")\}', bst_src)
    lines = ["ENTRY", "  { " + " ".join(_ORACLE_FIELDS) + " }", "  {}", "  {}", "",
             "FUNCTION {dump}", "{",
             '  "@" cite$ * "{" * write$ newline$']
    for field in _ORACLE_FIELDS:
        lines.append(
            f'  {field} missing$ {{ skip$ }} '
            f'{{ "  {field} = <" {field} * ">" * write$ newline$ }} if$')
    lines += ['  "}" write$ newline$', "}", ""]
    lines += [f'MACRO {{{name}}} {{{value}}}' for name, value in macros]
    lines += ["", "READ", "ITERATE {dump}"]
    return "\n".join(lines) + "\n"


_ORACLE_ENTRY_RE = re.compile(r"^@(.+)\{$")
_ORACLE_FIELD_RE = re.compile(r"^  (\S+) = <(.*)>$")


def _parse_oracle_bbl(text: str) -> dict[str, dict[str, str]]:
    out: dict[str, dict[str, str]] = {}
    current: str | None = None
    for line in text.splitlines():
        head = _ORACLE_ENTRY_RE.match(line)
        if head:
            current = head.group(1)
            out[current] = {}
            continue
        field = _ORACLE_FIELD_RE.match(line)
        if field and current is not None:
            out[current][field.group(1)] = field.group(2)
    return out


def _typst_reader_fields(bib_in_root: str) -> dict[str, dict[str, str]]:
    """Field values the Typst reader parses, via `typst query` on the dump doc."""
    OUT.mkdir(parents=True, exist_ok=True)
    dump = OUT / "bib-oracle-dump.typ"
    dump.write_text(_ORACLE_TYP)
    proc = subprocess.run(
        ["typst", "query", str(dump), "<bib-oracle>", "--field", "value", "--one",
         "--root", str(ROOT), "--font-path", str(ROOT / "fonts"),
         "--ignore-system-fonts", "--input", f"bib={bib_in_root}"],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"typst reader failed for {bib_in_root}:\n{proc.stderr.strip()}")
    db = json.loads(proc.stdout)
    return {key: entry["fields"] for key, entry in db.items()}


def _bibtex_reader_fields(bib: Path, bst: str, workdir: Path) -> dict[str, dict[str, str]]:
    stem = bib.stem
    (workdir / "dump.bst").write_text(bst)
    (workdir / f"{stem}.bib").write_bytes(bib.read_bytes())
    (workdir / f"{stem}.aux").write_text(
        f"\\bibstyle{{dump}}\n\\bibdata{{{stem}}}\n\\citation{{*}}\n")
    subprocess.run(["bibtex", stem], cwd=workdir, capture_output=True, text=True)
    bbl = workdir / f"{stem}.bbl"
    return _parse_oracle_bbl(bbl.read_text()) if bbl.exists() else {}


def cmd_bib_oracle(_args) -> int:
    """Compare the Typst .bib reader against real bibtex over well-formed input."""
    if shutil.which("bibtex") is None:
        print("bib-oracle needs the real `bibtex` binary (TeX Live).", file=sys.stderr)
        return 2
    bst = _oracle_bst()
    bibs = sorted((TESTS_DIR / "twins").glob("*.bib")) \
        + sorted((TESTS_DIR / "bib-oracle").glob("*.bib"))
    total_fields = total_mismatch = total_entries = 0
    diffs: list[str] = []
    with tempfile.TemporaryDirectory() as td:
        work = Path(td)
        for bib in bibs:
            in_root = "/" + bib.relative_to(ROOT).as_posix()
            try:
                typst = _typst_reader_fields(in_root)
            except (RuntimeError, json.JSONDecodeError) as exc:
                diffs.append(f"{bib.name}: {exc}")
                continue
            bibtex = _bibtex_reader_fields(bib, bst, work)
            shared = 0
            for key, fields in typst.items():
                if key not in bibtex:
                    continue
                shared += 1
                for name, value in fields.items():
                    if name not in bibtex[key]:
                        continue  # Typst-declared / bibtex-inherited-only field
                    total_fields += 1
                    if bibtex[key][name] != value:
                        total_mismatch += 1
                        diffs.append(f"{bib.name} {key}.{name}:\n"
                                     f"    bibtex: {bibtex[key][name]!r}\n"
                                     f"    typst:  {value!r}")
            total_entries += shared
            print(f"ok   {bib.name}: {len(typst)} entries, "
                  f"{shared} shared with bibtex")
    print(f"\nCompared {total_fields} field values across {total_entries} entries "
          f"in {len(bibs)} .bib files.")
    for diff in diffs:
        print("  - " + diff.replace("\n", "\n    "), file=sys.stderr)
    if total_mismatch or diffs:
        print(f"BIB-ORACLE FAILED: {total_mismatch} field value mismatch(es).", file=sys.stderr)
        return 1
    print("BIB-ORACLE: Typst reader is byte-identical to bibtex on every field.")
    return 0
