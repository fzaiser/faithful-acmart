"""Tier 1.5 — extracted-text semantic gate.

Layered text comparison per twin: exact normalized sequence or word-bag, the
universal exact char-bag tripwire, the dash residual, the ``expected_text_diffs``
fragments, and the per-twin text assertions."""

from __future__ import annotations

import difflib
from collections import Counter

import test_matrix as M
from test_matrix import TESTS
from pdf_text_tokens import normalize, bag_coverage, char_bag, dash_bag
from harness import latex_pdf, typst_pdf
from pdf_extract import pdf_text
from gates_core import _poppler_mismatch_note
from gate_residuals import (
    _check_expected_text_diffs, _residual_digest, _expected_residual,
    _assertion_targets,
)


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
            ltext = normalize(lraw, review_line_numbers=t.review_line_numbers)
            ttext = normalize(traw, review_line_numbers=t.review_line_numbers)
            if ltext != ttext:
                local.append(f"{name}: normalized text differs\n    {_first_diff(ltext, ttext)}")
            elif report:
                print(f"equal {name}")
        elif t.text_equal == "bag":
            cov, miss, extra = bag_coverage(
                lraw, traw, review_line_numbers=t.review_line_numbers)
            if miss or extra:
                local.append(
                    f"{name}: word bags differ ({cov * 100:.2f}% common)\n"
                    f"    only in LaTeX: {', '.join(list(miss)[:12])}\n"
                    f"    only in Typst: {', '.join(list(extra)[:12])}")
            elif report:
                print(f"bag   {name}: word-bag exact (order-independent)")
        elif t.text_equal is False:
            if not t.expected_text_diffs:
                local.append(f"{name}: text_equal=false requires expected_text_diffs")
            elif report:
                print(f"skip  {name}: text equality exempt by expected_text_diffs")
        elif report:
            print(f"skip  {name}: text equality not configured")

        # Universal char-bag tripwire on top of the above: every twin's content
        # must match as an exact character multiset (order-, line-break-, number-
        # and scheme-independent), unless it carries expected_text_diffs evidence
        # for a known content difference or a pdftotext extraction artifact.
        ca = char_bag(lraw, review_line_numbers=t.review_line_numbers)
        cb = char_bag(traw, review_line_numbers=t.review_line_numbers)
        cm, ce = ca - cb, cb - ca
        if t.expected_text_diffs:
            actual = _residual_digest(cm, ce)
            expected = _expected_residual(name, "text")
            if not expected:
                local.append(f"{name}: expected_text_diffs requires an exact text residual signature")
            elif actual != expected:
                local.append(
                    f"{name}: text residual changed (expected {expected}, got {actual})\n"
                    f"    only in LaTeX: {dict(cm)}\n    only in Typst: {dict(ce)}")
            elif report:
                print(f"diff  {name}: exact expected char residual {actual[:12]}")
        elif cm or ce:
            local.append(
                f"{name}: char bags differ (read both pdftotext dumps to locate)\n"
                f"    only in LaTeX: {dict(cm)}\n    only in Typst: {dict(ce)}")
        else:
            if report:
                print(f"char  {name}: exact")

        da = dash_bag(lraw, review_line_numbers=t.review_line_numbers)
        db = dash_bag(traw, review_line_numbers=t.review_line_numbers)
        dm, de = da - db, db - da
        expected_dash = M.EXPECTED_DASH_DIFFS.get(name)
        if expected_dash is not None:
            expected_missing = Counter({"-": expected_dash.latex_only}) + Counter()
            expected_extra = Counter({"-": expected_dash.typst_only}) + Counter()
            if dm != expected_missing or de != expected_extra:
                local.append(
                    f"{name}: dash residual changed ({expected_dash.reason}); "
                    f"expected {dict(expected_missing)}/{dict(expected_extra)}, "
                    f"got {dict(dm)}/{dict(de)}")
            elif report:
                print(f"dash  {name}: exact expected residual {dict(dm)}/{dict(de)}")
        elif dm or de:
            local.append(
                f"{name}: normalized dash counts differ\n"
                f"    only in LaTeX: {dict(dm)}\n    only in Typst: {dict(de)}")

        local.extend(_check_expected_text_diffs(name, t, lraw, traw))
        if report and t.expected_text_diffs:
            print(f"diff  {name}: {len(t.expected_text_diffs)} expected text/char diff(s) documented")

        for i, a in enumerate(t.text_assertions, 1):
            needle = normalize(a.text, review_line_numbers=t.review_line_numbers)
            if not needle:
                local.append(f"{name}: text assertion {i} has empty text")
                continue
            for label, pdf in _assertion_targets(name, t, a):
                haystack = normalize(
                    pdf_text(pdf, page=a.page), review_line_numbers=t.review_line_numbers)
                scope = f" page {a.page}" if a.page is not None else ""
                if a.kind == "contains" and needle not in haystack:
                    local.append(f"{name}: {label}{scope} missing text assertion {i}: {needle!r}")
                elif a.kind == "absent" and needle in haystack:
                    local.append(f"{name}: {label}{scope} contains forbidden assertion {i}: {needle!r}")
                elif a.kind not in ("contains", "absent"):
                    local.append(f"{name}: unknown text assertion kind {a.kind!r}")

        if not local and not report:
            print(f"ok   {name}")
        failures.extend(local)
    if failures and (note := _poppler_mismatch_note()):
        failures.append(note)
    return failures
