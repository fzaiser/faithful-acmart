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


_MD_LINK_RE = re.compile(r"\]\(([^)\s]+)\)")
_IMAGE_SUFFIXES = {".svg", ".png", ".jpg", ".jpeg", ".gif", ".webp"}


def _relative_link_targets(text: str) -> list[str]:
    """Markdown link targets that are repository paths (no URLs, no pure anchors)."""
    return [
        target for target in (m.group(1) for m in _MD_LINK_RE.finditer(text))
        if ":" not in target and not target.startswith("#")
    ]


def _split_markdown(text: str) -> tuple[str, str]:
    """(prose, code): fenced-block lines and inline code spans go to `code`.

    The staging rewrite and the reference checks treat the two differently, so
    the gate needs the split even though it is a line-based approximation of
    CommonMark, not a parse.
    """
    prose_lines: list[str] = []
    code_parts: list[str] = []
    in_fence = False
    for line in text.splitlines():
        if line.lstrip().startswith(("```", "~~~")):
            in_fence = not in_fence
            continue
        if in_fence:
            code_parts.append(line)
        else:
            code_parts.extend(re.findall(r"`+[^`]+`+", line))
            prose_lines.append(re.sub(r"`+[^`]+`+", " ", line))
    return "\n".join(prose_lines), "\n".join(code_parts)


def _is_shipped(target: str, rels: set[str]) -> bool:
    path = target.partition("#")[0].rstrip("/")
    return path in rels or any(rel.startswith(path + "/") for rel in rels)


def _release_readme(text: str, manifest: dict, rels: set[str]) -> str:
    """Pin the relative links whose targets do not ship to the release tag.

    The repository README links relatively throughout; in the release copy,
    links into the bundle stay relative and everything else becomes an
    immutable tag URL — raw.githubusercontent.com for images, so they render
    on Typst Universe.
    """
    package = manifest["package"]
    repository = package["repository"]
    tag = f"v{package['version']}"
    for target in sorted(set(_relative_link_targets(text))):
        if _is_shipped(target, rels):
            continue
        path, _, fragment = target.partition("#")
        path = path.rstrip("/")
        if Path(path).suffix.lower() in _IMAGE_SUFFIXES:
            host = repository.replace("github.com", "raw.githubusercontent.com")
            url = f"{host}/{tag}/{path}"
        else:
            view = "tree" if (ROOT / path).is_dir() else "blob"
            url = f"{repository}/{view}/{tag}/{path}"
        if fragment:
            url += f"#{fragment}"
        text = text.replace(f"]({target})", f"]({url})")
    return text


def _stage_package(package_dir: Path) -> list[str]:
    manifest = _package_manifest()
    selected = _package_files()
    rels = [p.relative_to(ROOT).as_posix() for p in selected]
    for source, rel in zip(selected, rels):
        destination = package_dir / rel
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
    readme = package_dir / "README.md"
    readme.write_text(_release_readme(readme.read_text(), manifest, set(rels)))
    return rels


def _compile_against_packages(main: Path, package_root: Path) -> subprocess.CompletedProcess:
    """Compile a document that imports the staged bundle from `package_root`."""
    return subprocess.run(
        ["typst", "compile", str(main), str(main.with_name("out.pdf")),
         "--package-path", str(package_root), "--root", str(main.parent),
         "--font-path", str(ROOT / "fonts"), "--ignore-system-fonts"],
        capture_output=True, text=True, env={**os.environ, **TEST_CLOCK_ENV},
    )


def gate_package(report: bool = False, out_dir: Path | None = None) -> list[str]:
    """Manifest allowlist, fresh-package compile, and official offline lint.

    With `out_dir`, a passing run additionally writes the staged bundle there,
    ready to commit into a typst/packages checkout.
    """
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
        repository = package["repository"]
        broken = sorted({
            target for target in _relative_link_targets(source_readme)
            if not (ROOT / target.partition("#")[0].rstrip("/")).exists()
        })
        if broken:
            failures.append("README links to missing paths: " + ", ".join(broken))
        if any(f"{repository}/{view}/main/" in source_readme for view in ("blob", "tree")):
            failures.append(
                "repository README must use relative links, not main-branch URLs")
        # The staging rewrite parses only plain inline `](target)` links; a titled,
        # angle-bracketed, or reference-style link would silently escape it.
        sloppy = [m.group(0) for m in re.finditer(r"\]\([^)]*\s[^)]*\)", source_readme)]
        if re.search(r"(?m)^ {0,3}\[(?!\^)[^\]]+\]:", source_readme):
            sloppy.append("a reference-style link definition")
        if sloppy:
            failures.append(
                "README links the staging rewrite cannot parse — use plain inline "
                "](target) links without titles: " + ", ".join(sloppy))
        prose, code = _split_markdown(source_readme)
        if "](" in code:
            failures.append(
                "README has ](…) inside a code span or fence; the staging rewrite "
                "cannot tell it from a link, so reword that code")
        headings = re.findall(r"(?m)^#{1,6} +(.+?)\s*$", prose)
        slugs = {re.sub(r" +", "-", re.sub(r"[^\w\- ]", "", h.lower())) for h in headings}
        missing_anchors = sorted({
            target for target in re.findall(r"\]\((#[^)\s]+)\)", source_readme)
            if target[1:] not in slugs
        })
        if missing_anchors:
            failures.append(
                "README anchor links to missing headings: " + ", ".join(missing_anchors))
        unshipped = sorted({
            target for target in _relative_link_targets(staged_readme)
            if not _is_shipped(target, set(rels))
        })
        if unshipped:
            failures.append(
                f"staged README links to unshipped paths (expected {release_tag} URLs): "
                + ", ".join(unshipped))

        # Every token starting `@preview/` must read exactly `name:version` for
        # this package. Whole-token matching is what makes a typo'd name, a
        # missing colon, a short `:0.1`, or a suffixed/garbled version fail
        # instead of slipping past. Prose may close its sentence right after
        # the token; in code spans, fences, and the template the token is part
        # of a command or import, so nothing may follow it.
        token_re = re.compile(r"@preview/[^\s\"'`)\]]*")
        exact = rf"@preview/{re.escape(package['name'])}:{re.escape(package['version'])}"
        strict_ref = re.compile(exact + r"\Z")
        prose_ref = re.compile(exact + r"[.,;:]?\Z")
        scans = [(prose, prose_ref), (code, strict_ref)] + [
            (path.read_text(), strict_ref)
            for path in sorted((ROOT / "template").glob("*.typ"))]
        tokens = [m.group(0) for text, _ in scans for m in token_re.finditer(text)]
        bad = sorted({m.group(0) for text, pattern in scans
                      for m in token_re.finditer(text) if not pattern.match(m.group(0))})
        if bad or not tokens:
            failures.append(
                f"README/template must reference @preview/{package['name']}:"
                f"{package['version']} only, found: " + (", ".join(bad) or "no references"))

        project = root / "project"
        shutil.copytree(package_dir / "template", project)
        compile_proc = _compile_against_packages(project / "main.typ", package_root)
        if compile_proc.returncode != 0 or not (project / "out.pdf").exists():
            failures.append(
                "fresh staged package failed to compile:\n" +
                (compile_proc.stderr + compile_proc.stdout).strip())

        fences = re.findall(r"^```typst\n(.*?)^```$", source_readme, re.M | re.S)
        # CommonMark also accepts indented, longer, or tilde fences; those would
        # silently skip compilation, so require the one canonical form.
        loose_fences = re.findall(r"(?mi)^ {0,3}(?:`{3,}|~{3,})[ \t]*typst\b", source_readme)
        if len(loose_fences) != len(fences):
            failures.append(
                f"README has {len(loose_fences)} typst fences but only {len(fences)} in "
                "the canonical form the gate compiles (```typst at column 0)")
        if not fences:
            failures.append("README has no ```typst example to compile")
        # Fragment examples (no import of their own) are compiled under the
        # quick-start context: the package import plus a minimal show rule.
        preamble = (
            f'#import "@preview/{package["name"]}:{package["version"]}": *\n'
            "#show: acmart.with(\n"
            '  title: "README Example",\n'
            "  acm-year: 2018,\n"
            "  acm-month: 8,\n"
            '  authors: ((name: "Ada Lovelace", email: "ada@example.org",\n'
            '    affiliation: (institution: "Analytical Engine Institute", country: "UK")),),\n'
            ")\n"
        )
        for index, fence in enumerate(fences, start=1):
            example = root / f"readme-example-{index}"
            example.mkdir()
            shutil.copy2(package_dir / "template" / "refs.bib", example / "refs.bib")
            source = fence if "#import" in fence else preamble + fence
            (example / "main.typ").write_text(source)
            fence_proc = _compile_against_packages(example / "main.typ", package_root)
            if fence_proc.returncode != 0:
                failures.append(
                    f"README ```typst example {index} failed to compile:\n" +
                    (fence_proc.stderr + fence_proc.stdout).strip())

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

        if out_dir is not None and not failures:
            out_dir = out_dir.resolve()
            if out_dir.is_relative_to(ROOT):
                failures.append(
                    f"--out must point outside the repository; a bundle under {ROOT} "
                    "would be picked up as package source by the next run")
            elif out_dir.exists() and (not out_dir.is_dir() or any(out_dir.iterdir())):
                failures.append(f"{out_dir} exists and is not an empty directory")
            else:
                shutil.copytree(package_dir, out_dir, dirs_exist_ok=True)
                if report:
                    print(f"staged the release bundle in {out_dir}")
    if report and not failures:
        print(
            f"ok   {len(rels)} shipped files; fresh template compile; "
            f"{len(fences)} README examples; offline package lint")
    return failures
