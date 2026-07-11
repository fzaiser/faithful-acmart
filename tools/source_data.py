"""Transcribed-source consistency gates.

Reparse the journal / bibliography / copyright tables out of the bundled
acmart.dtx and ACM-Reference-Format.bst and diff them against the Typst source
(``gate_source_data``), plus the manifest allowlist / fresh-package build
(``gate_package``)."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import tempfile
import tomllib
from pathlib import Path

import test_matrix as M
from harness import ROOT, ACMART, TESTS_DIR, TEST_CLOCK_ENV


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
