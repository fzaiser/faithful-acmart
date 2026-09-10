from __future__ import annotations

import base64
from itertools import zip_longest
from pathlib import Path
from typing import NamedTuple

from test_matrix import TESTS
from harness import ROOT, LATEX, DIFF, typst_pdf
from pdf_extract import page_count

_FRAME_MARGIN = 8

# Rec. 709 weights on sRGB components: a comparison intensity, not a claim of physical luminance.
_INTENSITY = "0.2126 0.7152 0.0722 0 0"
# feColorMatrix rows, red through alpha: intensity to (L, L, 1) and (1, L, L), both opaque.
_BLUE = f"{_INTENSITY} {_INTENSITY} 0 0 0 0 1 0 0 0 0 1"
_RED = f"0 0 0 0 1 {_INTENSITY} {_INTENSITY} 0 0 0 0 1"
_LAYERS = (("ref", _BLUE, ""), ("ours", _RED, ' style="mix-blend-mode:multiply"'))


class PageSvg(NamedTuple):
    """A page exported as a standalone SVG document, with its displayed size in points."""

    svg: str
    width: float
    height: float


def page_svgs(pdf: Path) -> list[PageSvg]:
    """Export every page of `pdf` as a standalone SVG at its displayed size.

    Text becomes paths, so a page renders the same wherever it is opened rather than picking up
    whichever fonts the viewer happens to have."""
    import fitz

    with fitz.open(pdf) as doc:
        return [PageSvg(page.get_svg_image(text_as_path=True), page.rect.width, page.rect.height)
                for page in doc]


def _n(value: float) -> str:
    return f"{value:g}"


def _tint(ident: str, page: PageSvg, matrix: str) -> str:
    """Flatten a page onto opaque white, then map its intensity to one comparison color.

    Flattening first lets each page's own transparency and white cover-ups resolve, so a white
    fill hides the ink under it instead of surviving into the multiply as a difference. The
    filter region is the page itself, so the white canvas stops at the page edge."""
    return (f'<filter id="{ident}" filterUnits="userSpaceOnUse" x="0" y="0" '
            f'width="{_n(page.width)}" height="{_n(page.height)}" '
            f'color-interpolation-filters="sRGB">'
            f'<feFlood flood-color="#ffffff" result="canvas"/>'
            f'<feComposite in="SourceGraphic" in2="canvas" operator="over"/>'
            f'<feColorMatrix type="matrix" values="{matrix}"/></filter>')


def _embed(page: PageSvg) -> str:
    """Carry a page in as its own document, so its generated identifiers stay private to it."""
    uri = base64.b64encode(page.svg.encode()).decode()
    return (f'<image x="0" y="0" width="{_n(page.width)}" height="{_n(page.height)}" '
            f'href="data:image/svg+xml;charset=utf-8;base64,{uri}"/>')


def comparison_svg(ref: PageSvg | None, ours: PageSvg | None) -> str:
    """Compose one page pair: blue LaTeX ink multiplied with red Typst ink.

    Ink only one engine painted stays blue or red, ink both painted goes dark, and matching
    gray or antialiased edges keep a faint tint, because multiplying two intensities is not one
    of them. The canvas holds both pages at their own size, anchored at the top left, so a page
    size difference shows as a difference instead of being scaled away; a page one engine did
    not produce leaves white, which multiplies to the other engine's tint alone."""
    layers = [(ident, page, matrix, blend)
              for (ident, matrix, blend), page in zip(_LAYERS, (ref, ours)) if page]
    width = max((page.width for _, page, _, _ in layers), default=0)
    height = max((page.height for _, page, _, _ in layers), default=0)
    defs = "".join(_tint(ident, page, matrix) for ident, page, matrix, _ in layers)
    body = "".join(f'<g filter="url(#{ident})"{blend}>{_embed(page)}</g>'
                   for ident, page, _, blend in layers)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{_n(width)}pt" '
            f'height="{_n(height)}pt" viewBox="0 0 {_n(width)} {_n(height)}">'
            f'<defs>{defs}</defs>'
            f'<g style="isolation:isolate">'
            f'<rect width="{_n(width)}" height="{_n(height)}" fill="#ffffff"/>{body}</g></svg>')


def _write_numbered(prefix: Path, documents: list[str]) -> list[Path]:
    """Write each document as <prefix>-<page>.svg and return the paths in page order."""
    prefix.parent.mkdir(parents=True, exist_ok=True)
    digits = len(str(len(documents)))
    paths = []
    for n, document in enumerate(documents, 1):
        path = prefix.with_name(f"{prefix.name}-{n:0{digits}d}.svg")
        path.write_text(document)
        paths.append(path)
    return paths


def write_page_svgs(pages: list[PageSvg], prefix: Path) -> list[Path]:
    """Write the untinted source pages, for reading a document in its original colors."""
    return _write_numbered(prefix, [page.svg for page in pages])


def write_comparison(ref: list[PageSvg], ours: list[PageSvg], prefix: Path) -> list[Path]:
    """Write one comparison per page pair, running through the longer of the two documents."""
    return _write_numbered(prefix, [comparison_svg(a, b) for a, b in zip_longest(ref, ours)])


def _visible(page):
    """Return the box a reader sees: the crop box, held inside the media box."""
    import pikepdf

    crop, media = pikepdf.Rectangle(page.cropbox), pikepdf.Rectangle(page.mediabox)
    return pikepdf.Rectangle(max(crop.llx, media.llx), max(crop.lly, media.lly),
                             min(crop.urx, media.urx), min(crop.ury, media.ury))


def _page_form(page):
    """Return a form drawing the page, bounded by what a reader sees.

    A page form otherwise takes the trim box when the document has one, which can sit inside
    the crop box and drop visible marks. The rotation the form carries is unaffected, since
    placement derives the offset from the box that ends up here."""
    form = page.as_form_xobject()
    form.BBox = _visible(page).as_array()
    return form


def _extent(form):
    """Return the area a page form covers once its own rotation and scaling apply."""
    import pikepdf

    box = pikepdf.Rectangle(form.BBox)
    matrix = form.get("/Matrix")
    return box if matrix is None else pikepdf.Matrix(*(float(v) for v in matrix)).transform(box)


def _vector_sidebyside(ref: Path, ours: Path, out: Path) -> Path:
    """Put each LaTeX page beside the Typst page of the same index, both framed and unrecolored.

    Every sheet gets the same geometry, so a page one engine did not produce leaves its half
    empty instead of shifting the rest of the comparison. Both engines keep one scale, and each
    page keeps the bounds a reader sees rather than its full media box."""
    import pikepdf

    with pikepdf.Pdf.open(ref) as left, pikepdf.Pdf.open(ours) as right:
        forms = [[_page_form(page) for page in pdf.pages] for pdf in (left, right)]
        boxes = [[_extent(form) for form in doc] for doc in forms]
        slots = [max((box.width for box in doc), default=0) for doc in boxes]
        width = sum(slots) + 3 * _FRAME_MARGIN
        height = max((box.height for doc in boxes for box in doc), default=0) + 2 * _FRAME_MARGIN
        dst = pikepdf.Pdf.new()
        for i in range(max(len(doc) for doc in boxes)):
            page = dst.add_blank_page(page_size=(width, height))
            x = _FRAME_MARGIN
            for doc, doc_boxes, slot in zip(forms, boxes, slots):
                if i < len(doc):
                    form = dst.copy_foreign(doc[i])
                    name = page.add_resource(form, pikepdf.Name.XObject)
                    box = doc_boxes[i]
                    top = height - _FRAME_MARGIN
                    rect = pikepdf.Rectangle(x, top - box.height, x + box.width, top)
                    page.contents_add(page.calc_form_xobject_placement(form, name, rect))
                    page.contents_add(f"q 0 G 0.4 w {rect.llx} {rect.lly} "
                                      f"{box.width} {box.height} re S Q\n".encode())
                x += slot + _FRAME_MARGIN
        dst.save(out)
    return out


def cmd_overlay(args) -> int:
    stems = args.stems or [n for n, t in TESTS.items() if t.kind == "twin"]
    DIFF.mkdir(parents=True, exist_ok=True)
    results = []
    # PyMuPDF forbids concurrent use, so pages convert one at a time.
    for name in stems:
        if TESTS.get(name) is None:
            print(f"skip  {name}: not in test matrix")
            continue
        ref, ours = LATEX / f"{name}.pdf", typst_pdf(name)
        if not ref.exists() or not ours.exists():
            print(f"skip  {name}: missing {'LaTeX' if not ref.exists() else 'Typst'} PDF")
            continue
        for stale in DIFF.glob(f"{name}-overlay*"):
            stale.unlink()
        svgs = write_comparison(page_svgs(ref), page_svgs(ours), DIFF / f"{name}-overlay")
        sd = _vector_sidebyside(ref, ours, DIFF / f"{name}-side-by-side.pdf")
        print(f"{name:>20}: {len(svgs)} overlay SVG(s), {sd.name} ({page_count(sd)}p)")
        results.append(name)

    if not results:
        print("no comparisons produced (build the PDFs first: test.py build)")
        return 1
    print(f"\nwrote comparisons for {len(results)} twin(s) to {DIFF.relative_to(ROOT)}/ — per "
          "twin, <name>-overlay-<page>.svg (LaTeX blue x Typst red, open in a browser) + "
          "<name>-side-by-side.pdf (LaTeX | Typst, original colors)")
    return 0
