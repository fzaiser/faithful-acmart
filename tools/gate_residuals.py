"""Shared residual-signature and expected-diff checking.

Used by the text, font, and order gates: a stable digest of a signed gate
residual, the matrix lookup for a test's expected signature, and the
fragment-presence checker behind ``expected_{text,font,order}_diffs``."""

from __future__ import annotations

import hashlib
from collections import Counter
from pathlib import Path

import test_matrix as M
from test_matrix import Test
from pdf_text_tokens import normalize
from harness import latex_pdf, typst_pdf
from pdf_extract import pdf_text


def _residual_digest(missing: Counter, extra: Counter) -> str:
    """Stable SHA-256 of a signed gate residual.

    Counter keys may be strings or font/order tuples, so serialize their reprs in
    sorted order rather than relying on insertion order or JSON type coercion.
    """
    payload = repr((
        sorted(((repr(key), count) for key, count in missing.items())),
        sorted(((repr(key), count) for key, count in extra.items())),
    )).encode()
    return hashlib.sha256(payload).hexdigest()


def _expected_residual(name: str, kind: str) -> str:
    residual = M.EXPECTED_RESIDUALS.get(name)
    return getattr(residual, kind) if residual is not None else ""


def _assertion_targets(name: str, t: Test, a: M.Assertion) -> list[tuple[str, Path]]:
    if a.engine == "typst":
        return [("Typst", typst_pdf(name))]
    if a.engine == "latex":
        return [("LaTeX", latex_pdf(name, t))]
    if a.engine == "both":
        return [("LaTeX", latex_pdf(name, t)), ("Typst", typst_pdf(name))]
    raise ValueError(f"unknown text assertion engine {a.engine!r}")


def _check_expected_pdf_diffs(
    name: str,
    t: Test,
    diffs: tuple,
    kind: str,
    lraw: str,
    traw: str,
    *,
    require_text_difference: bool,
) -> list[str]:
    failures: list[str] = []
    for i, d in enumerate(diffs, 1):
        cause = getattr(d, "cause", None)
        explanation = getattr(cause, "reason", "").strip() or f"expected {kind} diff {i}"
        norm_kw = {"review_line_numbers": t.review_line_numbers}
        lneedle, tneedle = normalize(d.latex, **norm_kw), normalize(d.typst, **norm_kw)
        scope = f" page {d.page}" if d.page is not None else ""
        if not isinstance(cause, M.DIFF_CAUSE_TYPES):
            failures.append(
                f"{name}: {explanation} has invalid {kind} diff cause {cause!r}")
        if not lneedle:
            failures.append(f"{name}: {explanation} has an empty LaTeX {kind} fragment")
        if not tneedle:
            failures.append(f"{name}: {explanation} has an empty Typst {kind} fragment")
        if require_text_difference and lneedle and tneedle and lneedle == tneedle:
            failures.append(f"{name}: {explanation} {kind} fragments normalize identically")
        if not lneedle or not tneedle:
            continue

        lhaystack = (
            normalize(pdf_text(latex_pdf(name, t), page=d.page), **norm_kw)
            if d.page is not None else normalize(lraw, **norm_kw)
        )
        thaystack = (
            normalize(pdf_text(typst_pdf(name), page=d.page), **norm_kw)
            if d.page is not None else normalize(traw, **norm_kw)
        )
        if lneedle not in lhaystack:
            failures.append(
                f"{name}: LaTeX{scope} missing expected {kind} diff {i} ({explanation}): {lneedle!r}")
        if tneedle not in thaystack:
            failures.append(
                f"{name}: Typst{scope} missing expected {kind} diff {i} ({explanation}): {tneedle!r}")
    return failures


def _check_expected_text_diffs(name: str, t: Test, lraw: str, traw: str) -> list[str]:
    return _check_expected_pdf_diffs(
        name, t, t.expected_text_diffs, "text", lraw, traw,
        require_text_difference=True,
    )


def _check_expected_font_diffs(name: str, t: Test, lraw: str, traw: str) -> list[str]:
    return _check_expected_pdf_diffs(
        name, t, t.expected_font_diffs, "font", lraw, traw,
        require_text_difference=False,
    )


def _check_expected_order_diffs(name: str, t: Test, lraw: str, traw: str) -> list[str]:
    return _check_expected_pdf_diffs(
        name, t, t.expected_order_diffs, "order", lraw, traw,
        require_text_difference=True,
    )
