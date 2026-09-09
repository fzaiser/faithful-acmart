"""Memoized PDF readers.

Import PDF libraries lazily so compile-only commands can run with standard Python."""

from __future__ import annotations

import functools
import hashlib
import re
import statistics
import unicodedata
from collections import Counter
from pathlib import Path

from pdf_text_tokens import CHAR_FOLD


_EXTRACT_CACHE: dict[tuple, object] = {}


def _pdf_memo(fn):
    """Cache by extractor, path, mtime, and extra arguments."""
    @functools.wraps(fn)
    def wrapped(pdf, *args, **kwargs):
        try:
            stamp = Path(pdf).stat().st_mtime_ns
        except OSError:
            stamp = None
        key = (fn.__name__, str(pdf), stamp, args, tuple(sorted(kwargs.items())))
        if key not in _EXTRACT_CACHE:
            _EXTRACT_CACHE[key] = fn(pdf, *args, **kwargs)
        return _EXTRACT_CACHE[key]
    return wrapped


def extractor_version() -> str:
    import fitz
    return f"pymupdf {fitz.VersionBind} (mupdf {fitz.VersionFitz})"


def page_count(pdf: Path) -> int:
    import fitz
    try:
        with fitz.open(pdf) as doc:
            return doc.page_count
    except RuntimeError:  # PyMuPDF's missing-file and bad-data errors.
        return -1


_INFO_FIELDS = {
    "title": "Title", "author": "Author", "subject": "Subject", "keywords": "Keywords",
    "creator": "Creator", "producer": "Producer",
    "creationDate": "CreationDate", "modDate": "ModDate",
}


@_pdf_memo
def pdf_info(pdf: Path) -> dict[str, str]:
    """Return populated fields keyed by their PDF /Info names."""
    import fitz
    try:
        with fitz.open(pdf) as doc:
            meta = doc.metadata or {}
    except RuntimeError:
        return {}
    return {label: meta[key] for key, label in _INFO_FIELDS.items() if meta.get(key)}


def _pixmap(page, dpi: int, gray: bool = False):
    import fitz
    return page.get_pixmap(dpi=dpi, colorspace=fitz.csGRAY if gray else fitz.csRGB)


def rasterize(pdf: Path, dpi: int, prefix: Path) -> list[Path]:
    """Write pages as <prefix>-<n>.png and return paths in page order."""
    import fitz
    prefix.parent.mkdir(parents=True, exist_ok=True)
    paths: list[Path] = []
    with fitz.open(pdf) as doc:
        width = len(str(doc.page_count))
        for n, page in enumerate(doc, 1):
            path = prefix.with_name(f"{prefix.name}-{n:0{width}d}.png")
            _pixmap(page, dpi).save(str(path))
            paths.append(path)
    return paths


def raster_array(pdf: Path, page: int, dpi: int, *, gray: bool = False):
    """Return pixels as an RGB (h, w, 3) or grayscale (h, w) array."""
    import fitz
    import numpy as np
    with fitz.open(pdf) as doc:
        pix = _pixmap(doc[page - 1], dpi, gray)
    arr = np.frombuffer(pix.samples, np.uint8)
    return arr.reshape(pix.h, pix.w) if gray else arr.reshape(pix.h, pix.w, pix.n)


def page_hashes(pdf: Path, dpi: int) -> list[str]:
    """Hash page dimensions and raw pixel samples, independently of PNG encoding."""
    import fitz
    hashes: list[str] = []
    with fitz.open(pdf) as doc:
        for page in doc:
            pix = _pixmap(page, dpi)
            digest = hashlib.sha256(f"{pix.w}x{pix.h}x{pix.n}:".encode())
            digest.update(pix.samples)
            hashes.append(digest.hexdigest())
    return hashes


def _word(run: list[dict]) -> tuple:
    return (
        min(c["bbox"][0] for c in run), min(c["bbox"][1] for c in run),
        max(c["bbox"][2] for c in run), max(c["bbox"][3] for c in run),
        "".join(c["c"] for c in run), run[0]["origin"][1],
    )


@_pdf_memo
def words(pdf: Path) -> dict:
    """Return page dimensions, word boxes, and dominant line baselines, keyed by 1-based page.

    Words are (x0, y0, x1, y1, text, baseline) tuples in content-stream order.
    A baseline shift starts a new word so superscripts cannot change the adjoining word's baseline."""
    import fitz
    pages: dict = {}
    with fitz.open(pdf) as doc:
        for n, page in enumerate(doc, 1):
            ws: list[tuple] = []
            baselines: list[float] = []
            for block in page.get_text("rawdict")["blocks"]:
                for line in block.get("lines", []):
                    chars = [c for span in line["spans"] for c in span["chars"]]
                    if not chars:
                        continue
                    # Superscripts must not set the line baseline.
                    baselines.append(Counter(
                        round(c["origin"][1], 2) for c in chars).most_common(1)[0][0])
                    run: list[dict] = []
                    for char in chars + [{"c": " "}]:
                        if char["c"].isspace():
                            if run:
                                ws.append(_word(run))
                            run = []
                        elif run and abs(char["origin"][1] - run[0]["origin"][1]) > 0.1:
                            ws.append(_word(run))
                            run = [char]
                        else:
                            run.append(char)
            pages[n] = {"w": page.rect.width, "h": page.rect.height,
                        "words": ws, "baselines": baselines}
    return pages


def page_metrics(page: dict) -> dict | None:
    ws = page["words"]
    if not ws:
        return None
    left = min(w[0] for w in ws)
    right = page["w"] - max(w[2] for w in ws)
    # A heading number and title can extract as separate lines on the same baseline.
    ys = sorted(page["baselines"])
    baselines = [ys[0]]
    for y in ys[1:]:
        if y - baselines[-1] > 2.0:
            baselines.append(y)
    gaps = [b - a for a, b in zip(baselines, baselines[1:])]
    pitch = statistics.median(gaps) if gaps else 0.0
    # Exclude jumps to page footers while retaining heading skips.
    grid = [g for g in gaps if g <= 3 * pitch] if pitch else []
    return {"left": left, "right": right, "top": baselines[0], "lines": len(baselines),
            "pitch": pitch, "pitches": grid}


@_pdf_memo
def pdf_text(pdf: Path, page: int | None = None) -> str:
    """Return content-stream text with a form feed after every page."""
    import fitz
    with fitz.open(pdf) as doc:
        pages = [doc[page - 1]] if page is not None else list(doc)
        return "".join(p.get_text("text") + "\f" for p in pages)

@_pdf_memo
def extract_uris(pdf: Path) -> Counter[str]:
    """Return external link targets, preserving multiplicity."""
    try:
        import pikepdf
    except ImportError as exc:
        raise RuntimeError("pikepdf is required for the hyperlink gate") from exc
    found: Counter[str] = Counter()
    with pikepdf.open(pdf) as doc:
        for page in doc.pages:
            for annotation in page.get("/Annots", []) or []:
                action = annotation.get("/A")
                if action is not None and action.get("/S") == "/URI" and "/URI" in action:
                    found[str(action["/URI"])] += 1
    return found


@_pdf_memo
def extract_internal_links(pdf: Path) -> dict:
    """Normalize named GoTo actions and direct Dest arrays to common internal targets."""
    try:
        import pikepdf
    except ImportError as exc:
        raise RuntimeError("pikepdf is required for the internal-link gate") from exc

    def walk_dest_names(node, out: dict[str, object]) -> None:
        if "/Names" in node:
            names = list(node["/Names"])
            for i in range(0, len(names), 2):
                out[str(names[i])] = names[i + 1]
        for kid in node.get("/Kids", []) or []:
            walk_dest_names(kid, out)

    def dest_name(value) -> str:
        name = str(value)
        return name[1:] if name.startswith("/") else name

    def resolve_dest(value, dests: dict[str, object]):
        if value is None:
            return None
        if isinstance(value, (pikepdf.String, pikepdf.Name)):
            value = dests.get(dest_name(value))
            if value is None:
                return None
        return value.get("/D", value) if hasattr(value, "get") else value

    def normalize_dest(value, dests: dict[str, object], page_by_objgen: dict) -> tuple | None:
        dest = resolve_dest(value, dests)
        if dest is None:
            return None
        try:
            page = page_by_objgen.get(dest[0].objgen)
        except (AttributeError, IndexError, TypeError):
            return None
        if page is None:
            return None
        coords = []
        for part in list(dest)[1:5]:
            try:
                coords.append(round(float(part), 1))
            except (TypeError, ValueError):
                coords.append(str(part))
        return (page, *coords)

    with pikepdf.open(pdf) as doc:
        page_by_objgen = {page.objgen: i for i, page in enumerate(doc.pages, 1)}
        dests: dict[str, object] = {}
        names = doc.Root.get("/Names")
        if names and "/Dests" in names:
            walk_dest_names(names["/Dests"], dests)
        root_dests = doc.Root.get("/Dests")
        if root_dests:
            for key, value in root_dests.items():
                dests[dest_name(key)] = value

        links: list[tuple[int, tuple]] = []
        for src_page, page in enumerate(doc.pages, 1):
            for annot in page.get("/Annots", []) or []:
                if annot.get("/Subtype") != "/Link":
                    continue
                dest = None
                action = annot.get("/A")
                if action and str(action.get("/S")) == "/GoTo":
                    dest = action.get("/D")
                elif "/Dest" in annot:
                    dest = annot.get("/Dest")
                normalized = normalize_dest(dest, dests, page_by_objgen)
                if normalized is not None:
                    links.append((src_page, normalized))

    return {
        "count": len(links),
        "unique_targets": len({target for _, target in links}),
        "pages": len(doc.pages),
        # Target counts differ across engines; use these pages to check destination validity.
        "target_pages": Counter(target[0] for _, target in links),
    }
@_pdf_memo
def horizontal_rules(pdf: Path) -> dict[int, list[tuple]]:
    """Return (thickness, color, x midpoint, width) rules by 1-based page.

    Read horizontal lines and thin rectangles from stroked drawing paths."""
    import fitz
    out: dict[int, list[tuple]] = {}
    doc = fitz.open(pdf)
    try:
        for pno in range(doc.page_count):
            rules: list[tuple] = []
            for drawing in doc[pno].get_drawings():
                if drawing["type"] not in ("s", "sf", "fs"):
                    continue
                width = drawing.get("width") or 0.0
                colour = drawing.get("color") or (0.0, 0.0, 0.0)
                colour_q = tuple(round(c * 16) / 16 for c in colour)
                for item in drawing["items"]:
                    if item[0] == "l":
                        p1, p2 = item[1], item[2]
                        if abs(p1.y - p2.y) < 0.4 and abs(p1.x - p2.x) > 2:
                            rules.append((width, colour_q, (p1.x + p2.x) / 2, abs(p2.x - p1.x)))
                    elif item[0] == "re":
                        r = item[1]
                        if r.height < 3 and r.width > 2:
                            rules.append((r.height, colour_q, (r.x0 + r.x1) / 2, r.width))
            if rules:
                out[pno + 1] = rules
    finally:
        doc.close()
    return out
@_pdf_memo
def outline(pdf: Path) -> list[tuple[int, str, int]]:
    """Return bookmarks as (level, normalized title, target page)."""
    import fitz
    doc = fitz.open(pdf)
    try:
        return [(lvl, re.sub(r"\s+", " ", title).strip(), page)
                for lvl, title, page in doc.get_toc(simple=True)]
    finally:
        doc.close()
def _font_role(font: str) -> str:
    """Map engine-specific font names to common family roles."""
    f = font.lower()
    if any(k in f for k in ("mono", "inconsolata", "zi4", "dejavu")):
        return "mono"
    if any(k in f for k in ("math", "txsy", "newcm", "dingbat", "cmsy", "cmmi", "cmex", "msam", "msbm")):
        return "sym"
    if "biolinum" in f or "sans" in f:
        return "sans"
    if "libertine" in f or "serif" in f:
        return "serif"
    return "other:" + f


def _font_color(c: int) -> tuple[int, int, int]:
    """Quantize color to absorb the engines' CMYK rounding differences."""
    q = lambda x: min(255, (x + 8) // 16 * 16)
    return (q((c >> 16) & 255), q((c >> 8) & 255), q(c & 255))


@_pdf_memo
def _font_scan(pdf: Path) -> tuple[Counter, dict]:
    """Count (letter, family, bold, italic, size, color) tuples and record their first pages.

    Exclude punctuation and symbol-font boundaries from font comparisons.
    Ignore monospace size because the font builds scale differently, and math italic flags because their descriptors are unreliable."""
    import fitz
    counts: Counter = Counter()
    first_page: dict = {}
    with fitz.open(pdf) as doc:
        for pageno, page in enumerate(doc, 1):
            for block in page.get_text("dict")["blocks"]:
                for line in block.get("lines", []):
                    for span in line["spans"]:
                        fam = _font_role(span["font"])
                        size = None if fam == "mono" else round(span["size"] * 2) / 2
                        italic = False if fam == "sym" else bool(span["flags"] & 2)
                        key = (fam, bool(span["flags"] & 16), italic,
                               size, _font_color(span["color"]))
                        for ch in unicodedata.normalize("NFKC", span["text"]):
                            ch = CHAR_FOLD.get(ch, ch)
                            if unicodedata.category(ch).startswith("L"):
                                full = (ch,) + key
                                counts[full] += 1
                                first_page.setdefault(full, pageno)
    return counts, first_page


def font_bag(pdf: Path) -> Counter:
    return _font_scan(pdf)[0]
