"""Checks for the LaTeX-vs-Typst comparison outputs, over PDFs built here."""

from __future__ import annotations

import base64
import contextlib
import io
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock
from xml.etree import ElementTree

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))

import overlay
from harness import OUT
from overlay import (
    _vector_sidebyside, cmd_overlay, comparison_svg, page_svgs, write_comparison,
)

SVG = "{http://www.w3.org/2000/svg}"
_INK = b"0 0 0 rg 50 50 100 100 re f"


def _pdf(path: Path, pages: int = 1, size=(200, 200), **attrs) -> Path:
    import pikepdf

    pdf = pikepdf.Pdf.new()
    for _ in range(pages):
        page = pdf.add_blank_page(page_size=size)
        page.Contents = pdf.make_stream(_INK)
        for key, value in attrs.items():
            page["/" + key] = value
    pdf.save(path)
    return path


class Comparison(unittest.TestCase):
    def setUp(self):
        # Under tests/out/ because the command reports its output path relative to the root.
        OUT.mkdir(parents=True, exist_ok=True)
        self.dir = Path(tempfile.mkdtemp(dir=OUT))
        self.addCleanup(shutil.rmtree, self.dir, ignore_errors=True)

    def pages(self, name, **kwargs):
        return page_svgs(_pdf(self.dir / f"{name}.pdf", **kwargs))

    def test_pairs_run_through_the_longer_document(self):
        for ref, ours in ((3, 1), (1, 3)):
            with self.subTest(ref=ref, ours=ours):
                paths = write_comparison(self.pages(f"a{ref}", pages=ref),
                                         self.pages(f"b{ours}", pages=ours),
                                         self.dir / f"{ref}{ours}-overlay")
                self.assertEqual([p.name for p in paths],
                                 [f"{ref}{ours}-overlay-{n}.svg" for n in (1, 2, 3)])

    def test_a_page_only_one_engine_produced_carries_one_layer(self):
        svg = comparison_svg(self.pages("solo")[0], None)
        self.assertEqual(svg.count("<image"), 1)
        self.assertNotIn("mix-blend-mode", svg)

    def test_a_missing_input_still_yields_a_comparison(self):
        paths = write_comparison([], self.pages("only", pages=2), self.dir / "gone-overlay")
        self.assertEqual(len(paths), 2)
        self.assertIn("mix-blend-mode", paths[0].read_text())

    def test_the_canvas_holds_both_pages_at_their_own_size(self):
        svg = comparison_svg(self.pages("small")[0], self.pages("large", size=(300, 260))[0])
        root = ElementTree.fromstring(svg)
        self.assertEqual(root.get("viewBox"), "0 0 300 260")
        self.assertEqual([(i.get("width"), i.get("height")) for i in root.iter(f"{SVG}image")],
                         [("200", "200"), ("300", "260")])

    def test_pages_are_measured_as_displayed(self):
        cropped = self.pages("cropped", CropBox=[20, 30, 180, 190])[0]
        rotated = self.pages("rotated", size=(200, 300), Rotate=90)[0]
        self.assertEqual((cropped.width, cropped.height), (160, 160))
        self.assertEqual((rotated.width, rotated.height), (300, 200))

    def test_every_filter_reference_resolves(self):
        svg = comparison_svg(self.pages("a")[0], self.pages("b")[0])
        root = ElementTree.fromstring(svg)
        defined = {f.get("id") for f in root.iter(f"{SVG}filter")}
        used = {g.get("filter")[5:-1] for g in root.iter(f"{SVG}g") if g.get("filter")}
        self.assertEqual(used, defined)
        self.assertTrue(used)

    def test_each_source_stays_a_document_of_its_own(self):
        svg = comparison_svg(self.pages("a")[0], self.pages("b")[0])
        href = "{http://www.w3.org/1999/xlink}href"
        for image in ElementTree.fromstring(svg).iter(f"{SVG}image"):
            uri = image.get("href") or image.get(href)
            prefix, _, payload = uri.partition(",")
            self.assertEqual(prefix, "data:image/svg+xml;charset=utf-8;base64")
            embedded = ElementTree.fromstring(base64.b64decode(payload))
            self.assertEqual(embedded.tag, f"{SVG}svg")

    def test_side_by_side_reserves_a_slot_for_each_engine(self):
        out = _vector_sidebyside(_pdf(self.dir / "l.pdf", pages=2, size=(200, 300)),
                                 _pdf(self.dir / "t.pdf", pages=1, size=(200, 300), Rotate=90),
                                 self.dir / "sbs.pdf")
        import pikepdf

        with pikepdf.Pdf.open(out) as pdf:
            boxes = [pikepdf.Rectangle(page.mediabox) for page in pdf.pages]
        # 200 + 300 wide and 300 tall, plus a margin between and around the two slots.
        self.assertEqual([(box.width, box.height) for box in boxes], [(524, 316)] * 2)

    def test_side_by_side_keeps_everything_the_crop_box_shows(self):
        """A trim box inside the crop box must not clip the sheet or the marks on it."""
        import fitz
        import pikepdf

        src = self.dir / "trimmed.pdf"
        pdf = pikepdf.Pdf.new()
        page = pdf.add_blank_page(page_size=(200, 200))
        # The first mark lies inside the crop box but outside the trim box.
        page.Contents = pdf.make_stream(b"0 0 0 rg 25 25 20 20 re f 90 90 20 20 re f")
        page.CropBox = [20, 20, 180, 180]
        page.TrimBox = [40, 40, 160, 160]
        pdf.save(src)

        out = _vector_sidebyside(src, src, self.dir / "trimmed-sbs.pdf")
        with fitz.open(out) as sheet:
            # Two 160-point slots, not the 120 points the trim box would leave.
            self.assertEqual((sheet[0].rect.width, sheet[0].rect.height), (344, 176))
            pixels = sheet[0].get_pixmap(dpi=72)
        self.assertEqual(pixels.pixel(20, 150), (0, 0, 0))

    def test_a_rerun_drops_the_pages_a_shorter_document_no_longer_has(self):
        latex, typst = self.dir / "latex", self.dir / "typst"
        latex.mkdir()
        typst.mkdir()
        _pdf(latex / "demo.pdf", pages=3)
        _pdf(typst / "demo.pdf", pages=3)
        diff = self.dir / "diff"
        args = mock.Mock(stems=["demo"])
        with mock.patch.multiple(overlay, DIFF=diff, LATEX=latex, TESTS={"demo": object()},
                                 typst_pdf=lambda name: typst / f"{name}.pdf"), \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(cmd_overlay(args), 0)
            self.assertEqual(len(list(diff.glob("demo-overlay-*.svg"))), 3)
            (diff / "demo-overlay.pdf").write_bytes(b"%PDF-1.7\n")
            _pdf(typst / "demo.pdf", pages=1)
            _pdf(latex / "demo.pdf", pages=1)
            self.assertEqual(cmd_overlay(args), 0)
        self.assertEqual([p.name for p in sorted(diff.glob("demo-overlay*"))],
                         ["demo-overlay-1.svg"])


if __name__ == "__main__":
    unittest.main()
