"""PDF extraction utilities and the per-run extraction cache.

Text, rasters, word geometry and document metadata all come from PyMuPDF, whose
version the uv lockfile pins, so every machine extracts identically; pikepdf reads
the object-level structure (links, tags). Both are imported inside the readers that
need them, so the Typst-only commands (``min-version`` runs on a bare Python in CI)
start without the uv environment. Every reader is memoized on (path, mtime) via
``_pdf_memo`` so each PDF is parsed once per ``check`` run. Pure reading — no gating
logic lives here."""

from __future__ import annotations

import functools
import hashlib
import re
import statistics
import unicodedata
from collections import Counter
from pathlib import Path

from pdf_text_tokens import CHAR_FOLD


# Per-run extraction memo: threaded through the `check` gates so each PDF is
# parsed once (PDF parsing is the run's dominant cost) instead of once per gate.
# Keyed on path + mtime so a rebuilt PDF is never served stale.
_EXTRACT_CACHE: dict[tuple, object] = {}


def _pdf_memo(fn):
    """Cache an extractor's result per (function, pdf path, mtime, extra args)."""
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


# ---------------------------------------------------------------------------
# Text, rasters, word geometry, metadata (PyMuPDF)
# ---------------------------------------------------------------------------
def extractor_version() -> str:
    """The PyMuPDF/MuPDF pair behind every text, raster and metadata read.

    Raster hashes and text residual digests are reproducible only under the same
    extractor, so the golden header records it and the matrix gate pins it.
    """
    import fitz
    return f"pymupdf {fitz.VersionBind} (mupdf {fitz.VersionFitz})"


def page_count(pdf: Path) -> int:
    import fitz
    try:
        with fitz.open(pdf) as doc:
            return doc.page_count
    except RuntimeError:  # PyMuPDF's missing-file and bad-data errors
        return -1


_INFO_FIELDS = {
    "title": "Title", "author": "Author", "subject": "Subject", "keywords": "Keywords",
    "creator": "Creator", "producer": "Producer",
    "creationDate": "CreationDate", "modDate": "ModDate",
}


@_pdf_memo
def pdf_info(pdf: Path) -> dict[str, str]:
    """Document-information fields that are set, keyed by their PDF /Info names."""
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
    """Render every page to ``<prefix>-<n>.png``; the paths come back in page order."""
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
    """One page's pixels as a numpy array: (h, w, 3) RGB, or (h, w) when gray."""
    import fitz
    import numpy as np
    with fitz.open(pdf) as doc:
        pix = _pixmap(doc[page - 1], dpi, gray)
    arr = np.frombuffer(pix.samples, np.uint8)
    return arr.reshape(pix.h, pix.w) if gray else arr.reshape(pix.h, pix.w, pix.n)


def page_hashes(pdf: Path, dpi: int) -> list[str]:
    """SHA-256 of each page's rendered pixels (size + raw samples, no PNG encoding)."""
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
    """1-based page -> {w, h, words: [(x0, y0, x1, y1, text, baseline), ...],
    baselines: [one dominant baseline per text line]}.

    A word is a whitespace-free run of one text line sharing one baseline, in
    content-stream order; its box is the union of its glyph boxes and ``baseline``
    is that baseline's y. A baseline shift ends the word, so a superscript footnote
    mark is not glued to the word after it (their baselines differ, and the mark
    would otherwise lend its raised baseline to the whole word).
    """
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
                    # The line's baseline is the one most of its glyphs sit on; a
                    # raised footnote mark or superscript does not make a line.
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
    """Layout geometry for one page: text-block margins, line count, baseline pitch."""
    ws = page["words"]
    if not ws:
        return None
    left = min(w[0] for w in ws)
    right = page["w"] - max(w[2] for w in ws)
    # Cluster the text lines' baselines: a new line starts when the gap exceeds 2pt
    # (a hanging section number and its title are separate line objects on one baseline).
    ys = sorted(page["baselines"])
    baselines = [ys[0]]
    for y in ys[1:]:
        if y - baselines[-1] > 2.0:
            baselines.append(y)
    gaps = [b - a for a, b in zip(baselines, baselines[1:])]
    pitch = statistics.median(gaps) if gaps else 0.0
    # Per-line text pitches: drop page-spanning gaps (the last body line -> page
    # footer is a ~400pt jump, not a baseline pitch). Heading skips (~1.5-2x the
    # body pitch) are kept, so two single-column pages whose lines break the same
    # way can be compared pitch-for-pitch, catching a single mis-spaced line that
    # the median hides.
    grid = [g for g in gaps if g <= 3 * pitch] if pitch else []
    return {"left": left, "right": right, "top": baselines[0], "lines": len(baselines),
            "pitch": pitch, "pitches": grid}


@_pdf_memo
def pdf_text(pdf: Path, page: int | None = None) -> str:
    """Plain text in content-stream order, a form feed closing every page (the
    layout-number stripping in ``pdf_text_tokens`` keys on that page break)."""
    import fitz
    with fitz.open(pdf) as doc:
        pages = [doc[page - 1]] if page is not None else list(doc)
        return "".join(p.get_text("text") + "\f" for p in pages)

@_pdf_memo
def extract_uris(pdf: Path) -> Counter[str]:
    """External hyperlink annotation targets, preserving multiplicity."""
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
    """Internal PDF link summary, normalized across named and direct destinations.

    LaTeX/hyperref usually writes named /GoTo actions; Typst writes direct /Dest
    arrays. Destination names are engine-specific, so the gate compares counts and
    normalized target coverage instead of raw names.
    """
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
        # Multiset of resolved target page numbers (previously computed then
        # discarded). Cross-engine equality against LaTeX is deliberately NOT
        # gated: measured across the twin set the two engines' internal-link
        # target-page multisets diverge broadly and legitimately — hyperref emits
        # more internal links than Typst (section \autoref backrefs, author-year
        # multi-\cite), and on multi-page docs pagination drifts (the documented
        # \flushbottom/ragged-bottom difference). So a cross-engine comparison
        # would need a per-twin exemption the size of the divergence; the outline
        # gate owns cross-engine SECTION target pages (page-1 anchored), and this
        # multiset instead feeds a Typst-side validity check (targets in range).
        "target_pages": Counter(target[0] for _, target in links),
    }
@_pdf_memo
def horizontal_rules(pdf: Path) -> dict[int, list[tuple]]:
    """1-based page -> list of (thickness, colour, x_mid, x_width) horizontal rules.

    A rule is a stroked line or a thin filled rectangle whose long axis is
    horizontal. LaTeX draws booktabs/footnote rules as thin filled boxes and
    strokes; Typst strokes them — both reduce to the same tuple, so the gate is
    engine-neutral. Colour is quantised to a 1/16 grid to absorb CMYK rounding."""
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
    """PDF bookmarks as (level, normalized-title, target-page) via PyMuPDF."""
    import fitz
    doc = fitz.open(pdf)
    try:
        return [(lvl, re.sub(r"\s+", " ", title).strip(), page)
                for lvl, title, page in doc.get_toc(simple=True)]
    finally:
        doc.close()
# --- Tier 1.8: per-letter font/size/colour gate (PyMuPDF) ---
# The text gates see only characters; this catches a letter rendered in the wrong font
# family, weight, size, or colour — e.g. sigchi-a body that should be sans (acmart's
# \sffamily document default) but came out serif, or an author block a step too small.
def _font_role(font: str) -> str:
    """Canonical family for a PDF BaseFont, so LinBiolinum (LaTeX) and LibertinusSans
    (Typst) both map to 'sans'. Math/symbol fonts collapse to 'sym'."""
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
    """Quantise an sRGB int to a 16-step grid — absorbs the engines' 8-bit CMYK
    rounding (e.g. link blue #155195 vs #155095) while keeping real colours apart."""
    q = lambda x: min(255, (x + 8) // 16 * 16)
    return (q((c >> 16) & 255), q((c >> 8) & 255), q(c & 255))


@_pdf_memo
def _font_scan(pdf: Path) -> tuple[Counter, dict]:
    """Multiset of (letter, family, bold, italic, size, colour) over every glyph,
    plus the first (1-based) page each such key appears on for failure localization.

    LETTERS only — punctuation and symbols sit at font boundaries / come from
    divergent symbol fonts, so their family is noise. Mono SIZE is dropped: LaTeX's
    zi4 and our bundled Inconsolata are scaled differently, so the nominal size is
    incomparable (the family still is). The ITALIC flag is dropped for math/symbol
    glyphs: it comes from the font descriptor, which is unreliable for combined math
    fonts (Typst's NewCMMath reports non-italic even though it renders the
    mathematical-italic glyphs slanted, just like LaTeX's separate italic math font)."""
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
    """Per-letter font multiset (see _font_scan)."""
    return _font_scan(pdf)[0]
