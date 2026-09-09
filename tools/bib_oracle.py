"""Compare parsed bibliography fields with BibTeX; invoked by bib-oracle."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from harness import ROOT, OUT, TESTS_DIR, ACMART


_ORACLE_FIELDS = (
    "address advisor archiveprefix author booktitle chapter city date edition "
    "editor eprint eprinttype eprintclass howpublished institution journal key "
    "location month note number organization pages primaryclass publisher school "
    "series title type volume year issue articleno eid day doi url bookpages "
    "numpages lastaccessed coden isbn issn lccn distinctURL archived venue"
).split()

_ORACLE_TYP = (
    '#import "/src/parts/bibtex.typ": parse-bib\n'
    "#metadata(parse-bib(read(sys.inputs.bib))) <bib-oracle>\n"
)


def _oracle_bst() -> str:
    """Generate a field-dump style seeded with ACM string macros."""
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
_ORACLE_FIELD_RE = re.compile(r"^  (\S+) =(.*)$")


def _parse_oracle_bbl(text: str) -> dict[str, dict[str, str]]:
    """Read {key: {field: value}} records through their closing delimiter.

    BibTeX can wrap values across lines that resemble new field declarations."""
    out: dict[str, dict[str, str]] = {}
    current: str | None = None
    pending: tuple[str, str] | None = None
    for line in text.splitlines():
        if pending is not None:
            name, value = pending
            value = (value + " " + line.strip()).strip()
        else:
            head = _ORACLE_ENTRY_RE.match(line)
            if head:
                current = head.group(1)
                out[current] = {}
                continue
            field = _ORACLE_FIELD_RE.match(line)
            if not field or current is None:
                continue
            name, value = field.group(1), field.group(2).strip()
        if value.startswith("<") and value.endswith(">"):
            out[current][name] = value[1:-1]
            pending = None
        else:
            pending = (name, value)
    return out


def _inherited(db: dict[str, dict[str, str]], key: str, field: str) -> str | None:
    """Return a field inherited through crossref, including the parent-title to booktitle mapping."""
    by_lower = {k.lower(): k for k in db}
    names = (field, "title") if field == "booktitle" else (field,)
    entry = db.get(by_lower.get(key.lower(), ""))
    seen: set[str] = set()
    while entry is not None and "crossref" in entry:
        parent = entry["crossref"].lower()
        if parent in seen:
            return None
        seen.add(parent)
        entry = db.get(by_lower.get(parent, ""))
        if entry is None:
            return None
        for name in names:
            if name in entry:
                return entry[name]
    return None


def _typst_reader_fields(bib_in_root: str) -> dict[str, dict[str, str]]:
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
    bbl = workdir / f"{stem}.bbl"
    bbl.unlink(missing_ok=True)
    proc = subprocess.run(["bibtex", stem], cwd=workdir, capture_output=True, text=True)
    if proc.returncode != 0 or not bbl.exists():
        blg = workdir / f"{stem}.blg"
        detail = (proc.stdout + proc.stderr).strip() or (
            blg.read_text().strip() if blg.exists() else "")
        raise RuntimeError(
            f"bibtex failed on {bib.name} (exit {proc.returncode}"
            + ("" if bbl.exists() else ", no .bbl") + f"):\n{detail}")
    return _parse_oracle_bbl(bbl.read_text())


def _compare(bib_name: str, typst, bibtex, declared: set[str]) -> tuple[int, list[str]]:
    """Compare keys, declared fields, and values, allowing fields added by BibTeX inheritance."""
    diffs: list[str] = []
    compared = 0
    for key in sorted(set(typst) - set(bibtex)):
        diffs.append(f"{bib_name} {key}: entry read by the Typst reader only")
    for key in sorted(set(bibtex) - set(typst)):
        diffs.append(f"{bib_name} {key}: entry read by bibtex only")
    for key in sorted(set(typst) & set(bibtex)):
        theirs = {name.lower(): value for name, value in bibtex[key].items()}
        ours = {name.lower(): value for name, value in typst[key].items()}
        for name in sorted(set(ours) - set(theirs)):
            if name in declared:
                diffs.append(f"{bib_name} {key}.{name}: read by the Typst reader only "
                             f"({ours[name]!r})")
        for name in sorted(set(theirs) - set(ours)):
            if _inherited(typst, key, name) != theirs[name]:
                diffs.append(f"{bib_name} {key}.{name}: read by bibtex only "
                             f"({theirs[name]!r})")
        for name in sorted(set(ours) & set(theirs)):
            compared += 1
            if ours[name] != theirs[name]:
                diffs.append(f"{bib_name} {key}.{name}:\n"
                             f"    bibtex: {theirs[name]!r}\n"
                             f"    typst:  {ours[name]!r}")
    return compared, diffs


def cmd_bib_oracle(_args) -> int:
    if shutil.which("bibtex") is None:
        print("bib-oracle needs the real `bibtex` binary (TeX Live).", file=sys.stderr)
        return 2
    bst = _oracle_bst()
    declared = {field.lower() for field in _ORACLE_FIELDS}
    bibs = sorted((TESTS_DIR / "twins").glob("*.bib")) \
        + sorted((TESTS_DIR / "bib-oracle").glob("*.bib"))
    total_fields = total_entries = 0
    diffs: list[str] = []
    with tempfile.TemporaryDirectory() as td:
        work = Path(td)
        for bib in bibs:
            in_root = "/" + bib.relative_to(ROOT).as_posix()
            try:
                typst = _typst_reader_fields(in_root)
                bibtex = _bibtex_reader_fields(bib, bst, work)
            except (RuntimeError, json.JSONDecodeError) as exc:
                diffs.append(f"{bib.name}: {exc}")
                print(f"FAIL {bib.name}", file=sys.stderr)
                continue
            compared, local = _compare(bib.name, typst, bibtex, declared)
            diffs += local
            total_fields += compared
            total_entries += len(typst)
            status = "ok  " if not local else "FAIL"
            print(f"{status} {bib.name}: {len(typst)} entries, {compared} field values")
    print(f"\nCompared {total_fields} field values across {total_entries} entries "
          f"in {len(bibs)} .bib files.")
    for diff in diffs:
        print("  - " + diff.replace("\n", "\n    "), file=sys.stderr)
    if diffs:
        print(f"BIB-ORACLE FAILED: {len(diffs)} difference(s).", file=sys.stderr)
        return 1
    print("BIB-ORACLE: Typst reader is byte-identical to bibtex on every field.")
    return 0
