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
# the in-repo mutation corpus (tests/bib-oracle/). The comparison is total: the
# two entry-key sets and, per entry, the two field-name sets must agree, so a
# bibtex run that produced nothing cannot pass as "nothing to compare". Only two
# field-set differences are allowed, both narrow — a field the dump .bst never
# declared, and one bibtex supplied through crossref inheritance. It is on-demand
# only (NOT in `check`/CI): it needs the real bibtex binary and is a maintenance
# audit, not a gate. Inputs must be well-formed — the corpus documents that
# contract.
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
_ORACLE_FIELD_RE = re.compile(r"^  (\S+) =(.*)$")


def _parse_oracle_bbl(text: str) -> dict[str, dict[str, str]]:
    """Read the dump .bst's output back into {key: {field: value}}.

    ``write$`` wraps past ~79 columns, breaking at a space and indenting the rest
    by two spaces — which looks exactly like a field line, and can even fall
    between the ``=`` and the value. So a record is accumulated until its closing
    ``>`` arrives instead of being matched line by line; the space each break
    consumed is put back. Matching line by line instead silently drops every long
    value, which then reads as a field bibtex never parsed."""
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
    """The value bibtex's crossref inheritance gives `key`.`field`, or None.

    The Typst reader is a plain parser and resolves no ``crossref``, so a field
    bibtex reports and it does not is expected exactly when an ancestor supplies
    it. A parent's ``title`` also feeds a child's ``booktitle``."""
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
    bbl = workdir / f"{stem}.bbl"
    bbl.unlink(missing_ok=True)
    proc = subprocess.run(["bibtex", stem], cwd=workdir, capture_output=True, text=True)
    # A failing bibtex, or one that wrote no .bbl, must not read as "nothing to
    # compare": that is how an oracle reports success on an empty comparison.
    if proc.returncode != 0 or not bbl.exists():
        blg = workdir / f"{stem}.blg"
        detail = (proc.stdout + proc.stderr).strip() or (
            blg.read_text().strip() if blg.exists() else "")
        raise RuntimeError(
            f"bibtex failed on {bib.name} (exit {proc.returncode}"
            + ("" if bbl.exists() else ", no .bbl") + f"):\n{detail}")
    return _parse_oracle_bbl(bbl.read_text())


def _compare(bib_name: str, typst, bibtex, declared: set[str]) -> tuple[int, list[str]]:
    """Compare the two readers' entry keys, field names, and field values.

    Field names are matched case-insensitively: bibtex lowercases what it reads,
    while the dump .bst echoes back the spelling declared in ``_ORACLE_FIELDS``.
    Two field-set differences are expected and everything else is reported —
    a field the dump never declared (bibtex does not read it at all), and one
    bibtex supplied through crossref inheritance (`_inherited`)."""
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
    """Compare the Typst .bib reader against real bibtex over well-formed input."""
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
