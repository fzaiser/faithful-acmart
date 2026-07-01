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
_STANDALONE_NUMBER_LINE = re.compile(r"(?m)^\s*\d+\s*$")
_PAGE_FOLIO_LINE = re.compile(r"(?m)^[^\S\r\n]*\d+[^\S\r\n]*(?=\r?\n\s*\f|\f|\Z)")
_URLISH_TLD = re.compile(r"(?i)^[\w.-]+\.(?:com|org|edu|net|gov|io|cfm|pdf|html?)\b")
_URL_COMPONENT = re.compile(r"[\w]+", re.UNICODE)


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


def normalize(text: str) -> str:
    """Collapse Poppler text for exact text assertions."""
    text = _without_standalone_number_lines(_clean(text)).replace("­", "")
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
    context = before + "-" + after
    return "-" if _looks_urlish(context) else ""


def _prepare_for_tokens(raw: str) -> str:
    text = _URL_SCHEME.sub("", _without_standalone_number_lines(_clean(raw)))
    text = _EOL_HYPHEN.sub(lambda m: _join_eol_hyphen(m, text), text)
    text = text.replace("­", "")
    return re.sub(r"\s+", " ", text).strip()


def _url_tokens(piece: str) -> list[str]:
    return [t for t in _URL_COMPONENT.findall(piece.strip(_EDGE_PUNCT)) if t]


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
        elif cat[0] == "S":
            flush()
            out.append(ch)
        else:
            flush()
    flush()
    return [t for t in out if t]


def tokenize(raw: str) -> list[str]:
    """Ordered token stream used by word bags and intra-chunk order checks."""
    tokens: list[str] = []
    for piece in _prepare_for_tokens(raw).split():
        if _looks_urlish(piece):
            tokens.extend(_url_tokens(piece))
        else:
            tokens.extend(_word_symbol_tokens(piece))
    return tokens


def bag_tokens(raw: str) -> Counter:
    """Token multiset for order-independent text comparison."""
    return Counter(tokenize(raw))


def bag_coverage(a: str, b: str) -> tuple[float, Counter, Counter]:
    """Fraction of tokens that agree as multisets, plus LaTeX-only/Typst-only rests."""
    ca, cb = bag_tokens(a), bag_tokens(b)
    miss, extra = ca - cb, cb - ca
    total = sum(ca.values()) + sum(cb.values())
    return 1 - sum((miss + extra).values()) / max(1, total), miss, extra


def char_bag(raw: str) -> Counter:
    """Whitespace-, dash-, variation-selector-, and page-folio-free char bag."""
    text = _without_review_line_number_lines(_without_page_folio_lines(_clean(raw))).translate(_DROP_DASHES)
    for old, new in CHAR_FOLD.items():
        text = text.replace(old, new)
    return Counter(re.sub(r"\s+", "", text))
