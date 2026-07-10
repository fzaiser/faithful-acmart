"""Shared PDF text normalization/tokenization for the regression harness.

The input is Poppler extraction text, not source text. The goal is to remove
layout/extraction noise while keeping real words visible to the gates.
"""

from __future__ import annotations

import re
import unicodedata
from collections import Counter

CHAR_FOLD = {
    "‘": "'",
    "’": "'",
    "“": '"',
    "”": '"',
    "«": '"',
    "»": '"',
    "„": '"',
    "∗": "*",
    "⁎": "*",
    "∙": "•",
}

_REPLACE = {
    "‐": "-",
    "‑": "-",
    "‒": "-",
    "–": "-",
    "—": "-",
    "−": "-",
    **CHAR_FOLD,
}

_EDGE_PUNCT = ".,;:!?()[]{}\"'*•-/"
_DROP_DASHES = str.maketrans("", "", "­‐‑‒–—−-")
_URL_SCHEME = re.compile(r"https?\s*:\s*/\s*/")
_EOL_HYPHEN = re.compile(r"[­‐‑-]\s*\n\s*")
_WORD_HYPHEN_SPACE = re.compile(r"([^\W\d_]{2,})[­‐‑-]\s+([^\W\d_]{2,})", re.UNICODE)
_STANDALONE_NUMBER_LINE = re.compile(r"(?m)^\s*\d+\s*$")
_PAGE_FOLIO_LINE = re.compile(r"(?m)^[^\S\r\n]*\d+[^\S\r\n]*(?=\r?\n\s*\f|\f|\Z)")
_URLISH_TLD = re.compile(r"(?i)^[\w.-]+\.(?:com|org|edu|net|gov|io|cfm|pdf|html?)\b")
_URL_COMPONENT = re.compile(r"[\w]+", re.UNICODE)


def _split_fragile_component(token: str) -> list[str]:
    if "_" in token or (len(token) > 4 and any(ch.isdigit() for ch in token)):
        return list(token)
    return [token]


def _is_variation_selector(ch: str) -> bool:
    cp = ord(ch)
    return 0xFE00 <= cp <= 0xFE0F or 0xE0100 <= cp <= 0xE01EF


def _clean(text: str) -> str:
    text = unicodedata.normalize("NFKC", text)
    text = "".join(ch for ch in text if not _is_variation_selector(ch))
    for old, new in _REPLACE.items():
        text = text.replace(old, new)
    return text


def _without_standalone_number_lines(text: str) -> str:
    return _STANDALONE_NUMBER_LINE.sub(" ", text.replace("\f", "\n"))


def _without_page_folio_lines(text: str) -> str:
    return _PAGE_FOLIO_LINE.sub(" ", text)


def _without_review_line_number_lines(text: str) -> str:
    if len(_STANDALONE_NUMBER_LINE.findall(text.replace("\f", "\n"))) < 20:
        return text
    return _without_standalone_number_lines(text)


def _drop_layout_numbers(text: str, *, review_line_numbers: bool = False) -> str:
    """Drop numbers that are LAYOUT chrome, not content: page folios (a number line
    right before a page break) and the review-mode line-number ruler (>=20
    standalone numbers). SECTION numbers are deliberately KEPT — they are content,
    they appear in both engines, and they match: LaTeX typesets the number in its
    own \\@hangfrom box so Poppler reads it on its own line while Typst reads it
    inline with the title, but that is only a line-break difference the order-
    independent bags and the whitespace-collapsing `normalize` absorb. (Dropping
    every standalone-number line, as this once did, instead swept section numbers
    up too, which forced the heading to keep an over-wide gap so its number would
    land on its own extracted line — see DESIGN.md.)"""
    text = _without_page_folio_lines(text)
    return _without_review_line_number_lines(text) if review_line_numbers else text


def normalize(text: str, *, review_line_numbers: bool = False) -> str:
    """Collapse Poppler text for exact text assertions."""
    text = _drop_layout_numbers(
        _clean(text), review_line_numbers=review_line_numbers).replace("­", "")
    return re.sub(r"\s+", " ", text).strip()


def _looks_urlish(piece: str) -> bool:
    return (
        "/" in piece
        or "@" in piece
        or piece.startswith("www.")
        or _URLISH_TLD.match(piece) is not None
    )


def _join_eol_hyphen(match: re.Match, text: str) -> str:
    """Drop ordinary line-break hyphenation, keep URL-looking path hyphens."""
    start, end = match.span()
    before = re.split(r"\s+", text[max(0, start - 80):start])[-1]
    after = re.split(r"\s+", text[end:end + 80])[0]
    context = text[max(0, start - 120):min(len(text), end + 120)]
    return "-" if _looks_urlish(context) else ""


def _join_word_hyphen_space(match: re.Match, text: str) -> str:
    """Join Poppler's same-line rendering of a line-break hyphen.

    Some LaTeX discretionary/source hyphens extract as ``synop- sis`` rather
    than ``synop-\nsis``. This is the same layout artifact as an EOL hyphen; keep
    real URL hyphens when the surrounding text is URL-looking.
    """
    start, end = match.span()
    context = text[max(0, start - 120):min(len(text), end + 120)]
    return match.group(1) + ("-" if _looks_urlish(context) else "") + match.group(2)


def _prepare_for_tokens(raw: str, *, review_line_numbers: bool = False) -> str:
    text = _URL_SCHEME.sub("", _drop_layout_numbers(
        _clean(raw), review_line_numbers=review_line_numbers))
    text = _EOL_HYPHEN.sub(lambda m: _join_eol_hyphen(m, text), text)
    text = _WORD_HYPHEN_SPACE.sub(lambda m: _join_word_hyphen_space(m, text), text)
    text = text.replace("­", "")
    return re.sub(r"\s+", " ", text).strip()


def _url_tokens(piece: str) -> list[str]:
    out: list[str] = []
    for t in _URL_COMPONENT.findall(piece.strip(_EDGE_PUNCT)):
        if not t:
            continue
        out.extend(_split_fragile_component(t))
    return out


def _word_symbol_tokens(piece: str) -> list[str]:
    piece = piece.strip(_EDGE_PUNCT).translate(_DROP_DASHES)
    out: list[str] = []
    buf: list[str] = []

    def flush() -> None:
        if buf:
            out.append("".join(buf))
            buf.clear()

    for i, ch in enumerate(piece):
        cat = unicodedata.category(ch)
        if cat[0] in ("L", "M", "N") or ch == "_":
            buf.append(ch)
        elif ch == "'" and 0 < i < len(piece) - 1:
            buf.append(ch)
        elif ch == "~":
            flush()
        elif cat[0] == "S":
            flush()
            out.append(ch)
        else:
            flush()
    flush()
    split: list[str] = []
    for t in out:
        if t:
            split.extend(_split_fragile_component(t))
    return split


def tokenize(raw: str, *, review_line_numbers: bool = False) -> list[str]:
    """Ordered token stream used by word bags and intra-chunk order checks."""
    tokens: list[str] = []
    for piece in _prepare_for_tokens(raw, review_line_numbers=review_line_numbers).split():
        if _looks_urlish(piece):
            tokens.extend(_url_tokens(piece))
        else:
            tokens.extend(_word_symbol_tokens(piece))
    return tokens


def bag_tokens(raw: str, *, review_line_numbers: bool = False) -> Counter:
    """Token multiset for order-independent text comparison."""
    return Counter(tokenize(raw, review_line_numbers=review_line_numbers))


def bag_coverage(
    a: str, b: str, *, review_line_numbers: bool = False,
) -> tuple[float, Counter, Counter]:
    """Fraction of tokens that agree as multisets, plus LaTeX-only/Typst-only rests."""
    ca = bag_tokens(a, review_line_numbers=review_line_numbers)
    cb = bag_tokens(b, review_line_numbers=review_line_numbers)
    miss, extra = ca - cb, cb - ca
    total = sum(ca.values()) + sum(cb.values())
    return 1 - sum((miss + extra).values()) / max(1, total), miss, extra


def char_bag(raw: str, *, review_line_numbers: bool = False) -> Counter:
    """Whitespace/dash/layout-hyphen/page-chrome-free character multiset.

    Dash parity is deliberately a separate exact gate (`dash_bag`) so a known
    extraction-only dash mismatch does not exempt any other character.
    """
    text = _prepare_for_tokens(raw, review_line_numbers=review_line_numbers).replace("-", "")
    text = text.replace("~", "")
    for old, new in CHAR_FOLD.items():
        text = text.replace(old, new)
    return Counter(re.sub(r"\s+", "", text))


def dash_bag(raw: str, *, review_line_numbers: bool = False) -> Counter:
    """Normalized real-dash multiset after removing discretionary line breaks."""
    text = _prepare_for_tokens(raw, review_line_numbers=review_line_numbers)
    return Counter(ch for ch in text if ch == "-")
