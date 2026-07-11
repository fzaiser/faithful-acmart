"""PDF-semantic cross-engine gates.

Metadata (Tier 1.55), hyperlinks (1.7), per-letter fonts (1.8), tagged-PDF
structure (1.85), intra-chunk reading order (1.9), and bookmark/outline parity
(1.95). All read the extracted PDF semantics rather than rendered pixels."""

from __future__ import annotations

import re
from collections import Counter

import test_matrix as M
from test_matrix import TESTS
from harness import latex_pdf, typst_pdf
from pdf_extract import (
    pdf_info, pdf_text, extract_uris, extract_internal_links, _font_scan,
    outline,
)
from source_data import _fold_quotes
from gate_residuals import (
    _check_expected_font_diffs, _check_expected_order_diffs,
    _residual_digest, _expected_residual,
)


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
_SECTION_NUMBER = re.compile(r"^\d+(?:\.\d+)*\s")
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
