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

# Heal line-break hyphens before folding dashes, or real dashes could be deleted.
_DASH_FOLD = {
    "‐": "-",
    "‑": "-",
    "‒": "-",
    "–": "-",
    "—": "-",
    "−": "-",
}

_SOFT_HYPHEN = "­"
_EDGE_PUNCT = ".,;:!?()[]{}\"'*•-/"
_DROP_DASHES = str.maketrans("", "", "­‐‑‒–—−-")
_URL_SCHEME = re.compile(r"https?\s*:\s*/\s*/")
_EOL_HYPHEN = re.compile(r"[­‐‑-]\s*\n\s*")
_WORD_HYPHEN_SPACE = re.compile(r"([^\W\d_]{2,})[­‐‑-]\s+([^\W\d_]{2,})", re.UNICODE)
_STANDALONE_NUMBER_LINE = re.compile(r"(?m)^\s*\d+\s*$")
_URLISH_TLD = re.compile(r"(?i)^[\w.-]+\.(?:com|org|edu|net|gov|io|cfm|pdf|html?)\b")
_URL_COMPONENT = re.compile(r"[\w]+", re.UNICODE)

_MIN_RULER_RUN = 20


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
    for old, new in CHAR_FOLD.items():
        text = text.replace(old, new)
    return text


def _fold_dashes(text: str) -> str:
    for old, new in _DASH_FOLD.items():
        text = text.replace(old, new)
    return text


def _without_review_line_number_lines(text: str) -> str:
    """Remove long runs of ruler numbers; isolated section numbers must survive."""
    lines = text.replace("\f", "\n").split("\n")
    numbered = [_STANDALONE_NUMBER_LINE.fullmatch(line) is not None for line in lines]
    out = list(lines)
    start = None
    for i in range(len(lines) + 1):
        if i < len(lines) and numbered[i]:
            start = i if start is None else start
            continue
        if start is not None and i - start >= _MIN_RULER_RUN:
            out[start:i] = [" "] * (i - start)
        start = None
    return "\n".join(out)


def _drop_layout_numbers(text: str, *, review_line_numbers: bool = False) -> str:
    return _without_review_line_number_lines(text) if review_line_numbers else text


def _looks_urlish(piece: str) -> bool:
    return (
        "/" in piece
        or "@" in piece
        or piece.startswith("www.")
        or _URLISH_TLD.match(piece) is not None
    )


def _healed_word(text: str, start: int, end: int, core: str) -> str:
    """Inspect only the word being joined so URL detection is independent of surrounding line breaks."""
    left = start
    while left > 0 and not text[left - 1].isspace():
        left -= 1
    right = end
    while right < len(text) and not text[right].isspace():
        right += 1
    return text[left:start] + core + text[end:right]


def _join_eol_hyphen(match: re.Match, text: str) -> str:
    """Remove hyphenation at a line break, retaining literal URL hyphens."""
    if match.group().startswith(_SOFT_HYPHEN):
        return ""
    start, end = match.span()
    return "-" if _looks_urlish(_healed_word(text, start, end, "-")) else ""


def _join_word_hyphen_space(match: re.Match, text: str) -> str:
    """Handle breaks extracted as a hyphen followed by a space within a line."""
    start, end = match.span()
    joined = match.group(1) + match.group(2)
    if match.group()[len(match.group(1))] == _SOFT_HYPHEN:
        return joined
    core = match.group(1) + "-" + match.group(2)
    return core if _looks_urlish(_healed_word(text, start, end, core)) else joined


def _heal_line_breaks(text: str) -> str:
    text = _EOL_HYPHEN.sub(lambda m: _join_eol_hyphen(m, text), text)
    text = _WORD_HYPHEN_SPACE.sub(lambda m: _join_word_hyphen_space(m, text), text)
    return text.replace(_SOFT_HYPHEN, "")


def normalize(text: str, *, review_line_numbers: bool = False) -> str:
    """Normalize extracted prose for assertions, retaining URL schemes."""
    text = _fold_dashes(_heal_line_breaks(_drop_layout_numbers(
        _clean(text), review_line_numbers=review_line_numbers)))
    return re.sub(r"\s+", " ", text).strip()


def _prepare_for_tokens(raw: str, *, review_line_numbers: bool = False) -> str:
    text = _URL_SCHEME.sub("", _drop_layout_numbers(
        _clean(raw), review_line_numbers=review_line_numbers))
    return re.sub(r"\s+", " ", _fold_dashes(_heal_line_breaks(text))).strip()


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
    """Return the ordered token stream used by word and reading-order comparisons."""
    tokens: list[str] = []
    for piece in _prepare_for_tokens(raw, review_line_numbers=review_line_numbers).split():
        if _looks_urlish(piece):
            tokens.extend(_url_tokens(piece))
        else:
            tokens.extend(_word_symbol_tokens(piece))
    return tokens


def bag_tokens(raw: str, *, review_line_numbers: bool = False) -> Counter:
    return Counter(tokenize(raw, review_line_numbers=review_line_numbers))


def bag_coverage(
    a: str, b: str, *, review_line_numbers: bool = False,
) -> tuple[float, Counter, Counter]:
    """Return the agreeing fraction and each engine's unmatched token counts."""
    ca = bag_tokens(a, review_line_numbers=review_line_numbers)
    cb = bag_tokens(b, review_line_numbers=review_line_numbers)
    miss, extra = ca - cb, cb - ca
    total = sum(ca.values()) + sum(cb.values())
    return 1 - sum((miss + extra).values()) / max(1, total), miss, extra


def char_bag(raw: str, *, review_line_numbers: bool = False) -> Counter:
    """Count normalized characters, excluding whitespace and dashes.

    Dash differences are checked separately so their exemptions cannot hide other characters."""
    text = _prepare_for_tokens(raw, review_line_numbers=review_line_numbers).replace("-", "")
    text = text.replace("~", "")
    for old, new in CHAR_FOLD.items():
        text = text.replace(old, new)
    return Counter(re.sub(r"\s+", "", text))


def dash_bag(raw: str, *, review_line_numbers: bool = False) -> Counter:
    text = _prepare_for_tokens(raw, review_line_numbers=review_line_numbers)
    return Counter(ch for ch in text if ch == "-")
