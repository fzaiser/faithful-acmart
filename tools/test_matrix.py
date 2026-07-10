"""Test matrix — the single source of truth for the regression harness.

`tools/test.py` is the command runner; this module is its data. Everything the
gates need lives here as typed Python: the test list (one `Test` per stem), the
text assertions, the Tier 2 metric tolerances, the expected compile-error cases,
the copyright/option validation variants, the pinned Typst version, and the
golden raster DPI.

Test kinds
----------
- ``twin``  matched ``NAME.tex`` (real LaTeX acmart) + ``NAME.typ`` (ours),
            compared page-by-page; assets (bib, images) in ``tests/twins/``.
- ``smoke`` Typst-only doc with no LaTeX twin: compiled (warning-free) and,
            when deterministic, golden-hashed. Alias/feature paths the
            matched twins don't cover.

The Tier 1 goldens are captured with `TYPST_VERSION` + the bundled fonts at
`GOLDEN_DPI`; bumping Typst means regenerating them (`tools/test.py accept`).
"""

from __future__ import annotations

from dataclasses import dataclass

# The engine the Tier 1 goldens were captured with. Bumping Typst means
# regenerating the golden hashes (`tools/test.py accept`).
TYPST_VERSION = "0.14.2"

# Raster resolution (dpi) for the Tier 1 page-hash snapshots.
GOLDEN_DPI = 150

# PDF document-information fields emitted by Typst's native `document` metadata.
# acmart also sets PDF Subject from CCS concepts, but Typst currently exposes no
# document-level subject field, so that one intentional engine limitation is not
# listed here.
METADATA_EXPECTATIONS: dict[str, dict[str, str]] = {
    "title-test": {
        "Title": "The Name of the Title Is Hope",
        "Author": "Ben Trovato, Lars Thørväld, Valerie Béranger",
        "Keywords": "datasets, neural networks, gaze detection, text tagging",
    },
    "anonymous-test": {
        "Title": "An Anonymous Submission",
        "Author": "Anonymous Author(s)",
        "Keywords": "datasets, anonymity",
    },
}

# Tier 2 gate tolerances (PDF points; both engines emit 1/72in big points).
# Only robust, renderer-agnostic invariants are gated. Right margin and line
# count depend on cross-engine line-breaking, so metrics report them but does
# not gate on them.
METRICS_TOLERANCE = {
    "left": 1.0,   # text-block left edge — true horizontal invariant, gated tightly
    "top": 4.5,    # first-content vertical position — loose: absorbs glyph-bbox
                   # ascent conventions and title-page variance, still catches gross shifts
    "pitch": 0.6,  # median baseline-to-baseline pitch — gated only with metrics_uniform_pitch
    "line_pitch": 0.8,  # max single-line pitch deviation — gated with metrics_uniform_pitch
                        # whose lines break identically across engines (so the per-line
                        # pitch sequences align). Catches one mis-spaced line that the
                        # median absorbs; skipped when line counts diverge.
}


@dataclass(frozen=True)
class Assertion:
    """A targeted text-layer assertion for a noisy twin (Tier 1.5).

    ``engine``: which PDF(s) to scan — ``typst``, ``latex``, or ``both``.
    ``kind``:   ``contains`` (text must be present) or ``absent`` (must not be).
    ``page``:   1-based page to scan, or ``None`` for the whole document.
    """

    text: str
    kind: str = "contains"
    engine: str = "typst"
    page: int | None = None


@dataclass(frozen=True)
class ExtractionArtifact:
    """A tolerated mismatch caused by PDF extraction or layout-stream asymmetry."""

    reason: str


@dataclass(frozen=True)
class AcceptedTypstBehavior:
    """A documented Typst-vs-LaTeX behavior difference we explicitly accept."""

    reason: str


@dataclass(frozen=True)
class TypstBug:
    """A documented Typst-vs-LaTeX behavior difference that should be fixed."""

    reason: str


DiffCause = ExtractionArtifact | AcceptedTypstBehavior | TypstBug
DIFF_CAUSE_TYPES = (ExtractionArtifact, AcceptedTypstBehavior, TypstBug)


@dataclass(frozen=True)
class ExpectedTextDiff:
    """A documented, validated text fragment pair for an intentional mismatch.

    These are for twins whose whole-document word or char bags cannot be exact:
    ``latex`` and ``typst`` are coherent snippets from the extracted PDF text.
    ``cause`` carries both the category and the local, human-readable reason.
    """

    latex: str
    typst: str
    cause: DiffCause
    page: int | None = None


@dataclass(frozen=True)
class ExpectedFontDiff:
    """A documented, validated fragment pair anchoring a font-gate exemption.

    The snippets identify the content whose rendered font/size/shape differs.
    They may normalize to the same text, because font differences often affect
    the same glyphs rather than the extracted characters.
    """

    latex: str
    typst: str
    cause: DiffCause
    page: int | None = None


@dataclass(frozen=True)
class ExpectedOrderDiff:
    """A documented, validated fragment pair anchoring an order-gate exemption.

    The snippets should show the LaTeX flat extraction order and the Typst
    extracted/logical order that the harness intentionally tolerates.
    """

    latex: str
    typst: str
    cause: DiffCause
    page: int | None = None


@dataclass(frozen=True)
class ResidualSignatures:
    """Exact hashes of accepted gate residuals for one twin.

    Human-readable Expected*Diff entries explain and anchor a difference; these
    hashes ensure that exemption accepts only the measured char/font/order delta,
    not any future mismatch in the same document.
    """

    text: str = ""
    font: str = ""
    order: str = ""


# Populated below the test matrix. Keeping signatures separate makes their role
# explicit: they are machine snapshots, while Test.expected_*_diff is reviewable
# evidence and rationale.
EXPECTED_RESIDUALS: dict[str, ResidualSignatures] = {
    "acmcp-test": ResidualSignatures(text="1391876e63685b7da0e6a923dc6c4c106590930a70cdf4665088614cae243c44"),
    "mathfields": ResidualSignatures(font="33b5c052b30812736e907581e38b04c1be363ec608e59cd34c8a13ce193f5170"),
    "sample-acmsmall": ResidualSignatures(text="8cba954a5520fd058c6ee4b3ef213b985cb2dfc4605901a961fc7cad13facde4", font="98e1639cc36abda915fc635b599a331980f4a1443934b3dcbe664abc1a0ccb46", order="b011bb574b0c3e6332e072a3cf7268d88ac0e06d7416674ed7e2a03b8e784142"),
    "sample-manuscript": ResidualSignatures(text="527362f83210ff0362215154e012092aab9bd63ce53912de5b238fb09c890f30", font="ba2c719c2aa71bf411ef3fa382d5365f3b4ab49c2f8f7ccb4ca175b689f95a43", order="457f10d3f56df13ff4baff3612fe22eada818355eee6dcfe4c5154de5d9dee74"),
    "sample-acmlarge": ResidualSignatures(text="8cba954a5520fd058c6ee4b3ef213b985cb2dfc4605901a961fc7cad13facde4", font="261a3c04b619777bdce2946bfee4f5bdd1b995fa1390e8829caede1a2f1b2406", order="c32956ff5fef018c73b6d9b5f9084c8653cb892302fd05884ff6f7a53506f95e"),
    "sample-sigconf": ResidualSignatures(text="8cba954a5520fd058c6ee4b3ef213b985cb2dfc4605901a961fc7cad13facde4", font="719bd7515c439d8ca322032e6cbe879cc7911b2582a8ed6f752157b284ec94d5", order="da3fad63db3dd04dfedfaf2d5eb1fb23c583708920c465d37d5e913d8ef36e86"),
    "sample-sigplan": ResidualSignatures(text="7d9968c88a217d27c519a492459acf69ce9cec81d249b76ecb62f945ae36e54d", font="3047dcaee4a2bdbdae98523a9df44b4b10a0041399d537ed6b0e1a177cc8549f", order="2d25d7956168f03ea10393c2f996cf32ed0895f7c56704510fde7665358cdb2b"),
    "sample-acmsmall-submission": ResidualSignatures(text="177dedfe4469ece8a23d03c2ed894a6e48f85a1b734c78afaec531eebd7b1d59", font="261a3c04b619777bdce2946bfee4f5bdd1b995fa1390e8829caede1a2f1b2406", order="33160f565094321d629e06954ac6ddcc79817d22be972d4ef949a4983b19fb99"),
    "sample-acmsmall-conf": ResidualSignatures(text="8cba954a5520fd058c6ee4b3ef213b985cb2dfc4605901a961fc7cad13facde4", font="98e1639cc36abda915fc635b599a331980f4a1443934b3dcbe664abc1a0ccb46", order="ac32e5ff5c93cf0d09c0e1321fa82f286ca07119223b60c96fa53b4644dbe6d4"),
    "sample-acmtog": ResidualSignatures(text="8cba954a5520fd058c6ee4b3ef213b985cb2dfc4605901a961fc7cad13facde4", font="21c511d6c66fbcd45e3ec5844a286813ac485ccbd8c3a3cc2e880f76a9e8c926", order="99003eab1044dc98b50f27a2e1cbc5a03e58413cd714e1318bd76ce7a4250922"),
    "sample-acmtog-conf": ResidualSignatures(text="8cba954a5520fd058c6ee4b3ef213b985cb2dfc4605901a961fc7cad13facde4", font="21c511d6c66fbcd45e3ec5844a286813ac485ccbd8c3a3cc2e880f76a9e8c926", order="ac32e5ff5c93cf0d09c0e1321fa82f286ca07119223b60c96fa53b4644dbe6d4"),
    "sample-sigconf-i13n": ResidualSignatures(text="8cba954a5520fd058c6ee4b3ef213b985cb2dfc4605901a961fc7cad13facde4", font="106dbb64d8ba5ef21a762614e6b2da77f95885be88619e99bf7847c7f23d9b88", order="d3c9c50f4594efe40103a7db9e56117878bc6399a13653dd6eb25c8b2e7aae14"),
    "sample-sigconf-authordraft": ResidualSignatures(text="195c1ea29cf78801a70a29f0adea32e9ea84435d5bc4625002832b1f892e76df", font="719bd7515c439d8ca322032e6cbe879cc7911b2582a8ed6f752157b284ec94d5", order="5e7664bcc6fd86d84a63ee11df1e2d86c6a650bf7181fb107743053292711289"),
    "sample-acmsmall-biblatex": ResidualSignatures(text="5a6d00df8ca31bf0749a95d1a044429c6892ada636dac526b75e92df6f6ed961", font="49aeb0090f34955cfe4955eb61ec3205d5316489e0e531efc5b177d41a4d0312", order="325dd262a0d7815097013690111f9d8452db63d9960cc95fb7a902c22c9b0867"),
    "sample-sigconf-biblatex": ResidualSignatures(text="314ea015168ec50ce6b645fecc148d93820ff6964468897a8d096c0a555200b9", font="331464ac0b75d83068122c1a2016d6e6e77733b7111debd67a0e13bcbb89a919", order="202add8013355fa3d61b8a1ebfa99845cab8bb6a9edf0303679e5002a45ac2be"),
    "sample-acmengage": ResidualSignatures(order="1badbb9a301a35b813960065b70e1c6ffee6bf6940a19c9e2c0e65f0edf23478"),
}


@dataclass(frozen=True)
class ExpectedLinkDiff:
    """Exact external-link multiset residual plus its rationale."""

    reason: str
    missing: tuple[str, ...] = ()
    extra: tuple[str, ...] = ()


@dataclass(frozen=True)
class ExpectedDashDiff:
    """Exact normalized dash-count residual plus its rationale."""

    reason: str
    latex_only: int = 0
    typst_only: int = 0


_LINK_MULTIPLICITY = "exact annotation-multiplicity difference in the integration fixture"
EXPECTED_LINK_DIFFS: dict[str, ExpectedLinkDiff] = {
    "manuscript-pages-test": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, extra=("https://doi.org/XXXXXXX.XXXXXXX",)),
    "acmlarge-test": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, extra=("https://doi.org/XXXXXXX.XXXXXXX",)),
    "acmcp-test": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, extra=("https://example.com/data",)),
    "sample-acmsmall": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, extra=("https://www.acm.org/publications/proceedings-template",)),
    "sample-manuscript": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, missing=("https://doi.org/10.1145/1188913.1188915", "https://doi.org/10.1145/1057270.1057278"), extra=("https://www.acm.org/publications/taps/describing-figures/",)),
    "sample-acmlarge": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, missing=("https://doi.org/10.1007/3-540-09237-4", "https://doi.org/10.1145/1057270.1057278"), extra=("http://ccrma.stanford.edu/~jos/bayes/bayes.html",)),
    "sample-sigconf": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, missing=("https://doi.org/10.1007/3-540-65193-4_29",), extra=("https://doi.org/XXXXXXX.XXXXXXX", "https://dl.acm.org/ccs/ccs.cfm")),
    "sample-sigplan": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, missing=("https://www.acm.org/publications/proceedings-template", "https://doi.org/10.1145/1188913.1188915", "https://doi.org/10.1145/567752.567774", "https://doi.org/10.1007/3-540-09237-4", "https://doi.org/10.1007/3-540-09237-4", "https://doi.org/10.1145/1057270.1057278"), extra=("https://doi.org/10.1109/ICWS.2004.64",)),
    "sample-acmsmall-submission": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, extra=("https://www.acm.org/publications/proceedings-template",)),
    "sample-acmsmall-conf": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, extra=("https://www.acm.org/publications/proceedings-template",)),
    "sample-acmtog": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, missing=("https://doi.org/10.1145/1219092.1219093", "https://doi.org/10.1137/080734467")),
    "sample-acmtog-conf": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, missing=("https://doi.org/10.1145/1219092.1219093", "https://doi.org/10.1137/080734467")),
    "sample-sigconf-i13n": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, missing=("https://doi.org/10.1007/3-540-65193-4_29",), extra=("https://doi.org/XXXXXXX.XXXXXXX", "https://dl.acm.org/ccs/ccs.cfm")),
    "sample-sigconf-authordraft": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, missing=("https://doi.org/10.1007/3-540-65193-4_29",), extra=("https://doi.org/XXXXXXX.XXXXXXX", "https://dl.acm.org/ccs/ccs.cfm")),
    "sample-acmsmall-biblatex": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, missing=("https://doi.org/10.1145/1057270.1057278",), extra=("https://www.acm.org/publications/proceedings-template", "https://github.com/nuprl/tag-sound", "http://archive.softwareheritage.org/swh:1:dir:cd0b0abeee707e57cd699e2e2ebd075da8ebf1f7;origin=https://github.com/nuprl/tag-sound;visit=swh:1:snp:7967bc0abee8bf3bfffb9252207a07b73538525a;anchor=swh:1:rev:4cc09ca228947a99c8f4ac45eefb76e96ee96e53")),
    "sample-sigconf-biblatex": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, missing=("https://doi.org/10.1145/1188913.1188915", "https://hal.archives-ouvertes.fr/hal-02090402v1", "https://doi.org/10.1007/3-540-65193-4_29"), extra=("https://doi.org/XXXXXXX.XXXXXXX", "https://dl.acm.org/ccs/ccs.cfm", "https://github.com/scilab/scilab", "http://archive.softwareheritage.org/swh:1:cnt:43a6b232768017b03da934ba22d9cc3f2726a6c5;origin=https://github.com/rdicosmo/parmap;visit=swh:1:snp:2a6c348c53eb77d458f24c9cbcecaf92e3c45615;anchor=swh:1:rel:373e2604d96de4ab1d505190b654c5c4045db773;path=/src/parmap.ml;lines=192-228", "https://github.com/nuprl/tag-sound", "http://archive.softwareheritage.org/swh:1:dir:cd0b0abeee707e57cd699e2e2ebd075da8ebf1f7;origin=https://github.com/nuprl/tag-sound;visit=swh:1:snp:7967bc0abee8bf3bfffb9252207a07b73538525a;anchor=swh:1:rev:4cc09ca228947a99c8f4ac45eefb76e96ee96e53", "http://archive.softwareheritage.org/swh:1:rel:636541bbf6c77863908eae744610a3d91fa58855;origin=https://github.com/CGAL/cgal/", "http://video.google.com/videoplay?docid=6528042696351994555")),
    "sample-acmcp": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, extra=("https://orcid.org/1234-5678-9012",)),
    "sample-acmengage": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, missing=("https://www.engage-csedu.org/ontology", "https://doi.org/10.1145/1188913.1188915", "http://ccrma.stanford.edu/~jos/bayes/bayes.html"), extra=("https://doi.org/XXXXXXX.XXXXXXX", "https://creativecommons.org/licenses/by/4.0")),
}

_DASH_EXTRACTION = "exact normalized dash residual caused by cross-engine extraction/reflow"
EXPECTED_DASH_DIFFS: dict[str, ExpectedDashDiff] = {
    "figure-heading-test": ExpectedDashDiff(_DASH_EXTRACTION, typst_only=1),
    "list-test": ExpectedDashDiff(_DASH_EXTRACTION, latex_only=1),
    "manuscript-pages-test": ExpectedDashDiff(_DASH_EXTRACTION, typst_only=1),
    "acmtog-test": ExpectedDashDiff(_DASH_EXTRACTION, typst_only=3),
    "sigconf-authors-test": ExpectedDashDiff(_DASH_EXTRACTION, typst_only=1),
    "acmcp-test": ExpectedDashDiff(_DASH_EXTRACTION, latex_only=1),
    "biblatex-edge": ExpectedDashDiff(_DASH_EXTRACTION, latex_only=1),
    "bib-all": ExpectedDashDiff(_DASH_EXTRACTION, typst_only=1),
    "notes-test": ExpectedDashDiff(_DASH_EXTRACTION, latex_only=1),
    "options-test": ExpectedDashDiff(_DASH_EXTRACTION, latex_only=2),
    "authorversion-conf-test": ExpectedDashDiff(_DASH_EXTRACTION, typst_only=1),
    "sample-acmlarge": ExpectedDashDiff(_DASH_EXTRACTION, latex_only=2),
    "sample-sigconf": ExpectedDashDiff(_DASH_EXTRACTION, typst_only=6),
    "sample-sigplan": ExpectedDashDiff(_DASH_EXTRACTION, typst_only=15),
    "sample-acmtog": ExpectedDashDiff(_DASH_EXTRACTION, typst_only=7),
    "sample-acmtog-conf": ExpectedDashDiff(_DASH_EXTRACTION, typst_only=8),
    "sample-sigconf-i13n": ExpectedDashDiff(_DASH_EXTRACTION, typst_only=7),
    "sample-sigconf-authordraft": ExpectedDashDiff(_DASH_EXTRACTION, typst_only=6),
    "sample-acmsmall-biblatex": ExpectedDashDiff(_DASH_EXTRACTION, latex_only=3),
    "sample-sigconf-biblatex": ExpectedDashDiff(_DASH_EXTRACTION, typst_only=8),
    "sample-acmcp": ExpectedDashDiff(_DASH_EXTRACTION, typst_only=1),
    "sample-acmengage": ExpectedDashDiff(_DASH_EXTRACTION, typst_only=8),
}


@dataclass(frozen=True)
class MetricAllowance:
    """One expected out-of-tolerance metric with a hard maximum delta."""

    page: int
    key: str
    max_delta: float


EXPECTED_METRIC_DIFFS: dict[str, tuple[MetricAllowance, ...]] = {
    "sigplan-test": (MetricAllowance(1, "top", 5.25),),
    "acmengage-test": (MetricAllowance(1, "top", 5.25),),
    "acmcp-test": (MetricAllowance(1, "left", 1.75), MetricAllowance(1, "top", 6.25)),
    "sigchi-a-test": (MetricAllowance(1, "left", 6.25),),
    "authorversion-conf-test": (MetricAllowance(1, "top", 5.0),),
    "sample-acmsmall": (MetricAllowance(8, "left", 1.25),),
    "sample-sigplan": (MetricAllowance(1, "top", 5.25),),
    "sample-acmsmall-conf": (MetricAllowance(8, "left", 1.25),),
    "sample-acmtog": (MetricAllowance(2, "left", 1.25),),
    "sample-sigconf-i13n": (MetricAllowance(3, "left", 1.25),),
    "sample-acmsmall-biblatex": (MetricAllowance(8, "left", 1.25),),
    "sample-acmcp": (MetricAllowance(1, "left", 1.75),),
    "sample-acmengage": (MetricAllowance(1, "top", 5.25),),
}


@dataclass(frozen=True)
class Test:
    """One test stem and how the gates treat it.

    Twin page counts must match unless ``expected_page_count_diff`` documents a
    known mismatch. ``metrics_page1_only`` documents why Tier 2 metrics compare
    only page 1 instead of all shared pages. ``metrics_uniform_pitch`` documents
    why baseline pitch is meaningful enough to gate. ``text_equal`` /
    ``expected_text_diffs`` / ``text_assertions`` drive Tier 1.5. ``note`` is
    documentation only. Expected diff entries explain their cause with
    ``ExtractionArtifact("...")`` for PDF extraction noise,
    ``AcceptedTypstBehavior("...")`` for intentionally accepted Typst-vs-LaTeX
    differences, or ``TypstBug("...")`` for known Typst-vs-LaTeX gaps that
    should still be fixed.

    ``text_equal`` selects the Tier 1.5 whole-document text gate:
    ``True`` exact normalized-sequence equality; ``"bag"`` exact word multiset
    equality for extraction-order noise; ``False`` exempt with
    ``expected_text_diffs``; ``None`` unset.

    Independently of ``text_equal``, EVERY twin is also gated by exact character
    and normalized-dash multisets. Expected differences carry both reviewable
    evidence and an exact residual signature/count, so no exemption is blanket.

    EVERY twin is ALSO gated by the Tier 1.8 per-letter FONT check (``font_bag``,
    via PyMuPDF): each alphabetic character must render in the same family (serif/
    sans/mono), weight, italic, size, and colour as LaTeX. ``expected_font_diffs``
    exempt known font/content/math gaps and anchor them to PDF fragments.

    EVERY twin is ALSO gated by the Tier 1.9 per-chunk reading-ORDER check
    (``pdf_chunks``, via pikepdf): the tagged Typst PDF's logical chunks (title,
    each author line, contact-info, headings, bib entries) must appear in the flat
    LaTeX stream in the same intra-chunk order — catching an element emitted out of
    order (an affiliation/email swap, a reordered citation field) that the
    order-independent word/char bags cannot see. ``expected_order_diffs`` exempt
    known extraction-order asymmetries and anchor them to PDF fragments.

    EVERY twin's external hyperlink annotation multiset is compared against
    LaTeX. ``EXPECTED_LINK_DIFFS`` records exact missing/extra multiplicities for
    known differences.
    Any test may also set minimum internal-link counts for targeted regressions;
    those checks normalize LaTeX named /GoTo actions and Typst direct /Dest arrays.

    EVERY twin's Tier 2 layout metrics are gated. ``expected_metrics_diff`` gives
    the rationale while ``EXPECTED_METRIC_DIFFS`` names the exact page/key
    failures and caps each accepted delta.
    ``golden_exempt`` removes a test from the Typst raster golden set, and must
    explain why the rendered PDF is not golden-pinned.
    """

    kind: str
    pages: int
    expected_page_count_diff: str = ""
    expected_metrics_diff: str = ""
    golden_exempt: str = ""
    metrics_page1_only: str = ""
    metrics_uniform_pitch: str = ""
    text_equal: bool | str | None = None
    expected_text_diffs: tuple[ExpectedTextDiff, ...] = ()
    text_assertions: tuple[Assertion, ...] = ()
    expected_font_diffs: tuple[ExpectedFontDiff, ...] = ()
    expected_order_diffs: tuple[ExpectedOrderDiff, ...] = ()
    min_internal_links: int = 0
    min_internal_destinations: int = 0
    review_line_numbers: bool = False
    note: str = ""

    def __post_init__(self) -> None:
        if self.kind not in ("twin", "smoke"):
            raise ValueError(f"unknown test kind {self.kind!r}")
        if self.text_equal not in (None, True, False, "bag"):
            raise ValueError(f"unknown text_equal value {self.text_equal!r}")
        if self.metrics_page1_only and self.pages <= 1:
            raise ValueError("metrics_page1_only is only meaningful for multi-page tests")
        if self.metrics_page1_only and self.kind != "twin":
            raise ValueError("metrics_page1_only only applies to twin tests")
        if self.metrics_uniform_pitch and self.kind != "twin":
            raise ValueError("metrics_uniform_pitch only applies to twin tests")
        if self.min_internal_links < 0 or self.min_internal_destinations < 0:
            raise ValueError("minimum internal-link counts cannot be negative")
        if self.review_line_numbers and self.kind != "twin":
            raise ValueError("review_line_numbers only applies to twin tests")

    @property
    def subdir(self) -> str:
        """Tests live in tests/<subdir>/: ``twins`` for the matched
        ``NAME.tex``+``NAME.typ`` pairs, ``typst-only`` for everything else
        (smoke docs and the upstream-ref port, which have no local ``.tex``)."""
        return "twins" if self.kind == "twin" else "typst-only"


# Full bundled samples are broad integration fixtures. Focused twins above gate
# the exact geometry, fonts, order, and bibliography details; these samples keep
# only the gates that are meaningful for their current extraction profile.
_FULL_SAMPLE_FONT_EVIDENCE = (
    ExpectedFontDiff(
        latex="A formula that appears in the running text",
        typst="A formula that appears in the running text",
        cause=AcceptedTypstBehavior(
            "Full samples include math/reference/sidebar font cases covered by focused twins."
        ),
    ),
)

_TITLE_METRICS_DIFF = (
    "Title-heavy format geometry has known bbox drift; focused geometry twins own "
    "the exact body metrics."
)
_COVER_METRICS_DIFF = (
    "Cover/sidebar formats do not expose a stable body-block metric rectangle."
)
_LANDSCAPE_METRICS_DIFF = (
    "Landscape extended-abstract geometry is covered by page parity, text, links, "
    "and goldens instead of the generic portrait metric gate."
)
_FULL_SAMPLE_METRICS_DIFF = (
    "Full upstream samples include page-fill, column-flow, and float-placement "
    "drift; focused twins own exact geometry."
)
_PAGE1_METRICS_SCOPE = (
    "Only page 1 has stable absolute metrics; later pages include LaTeX page-fill/"
    "column-flow drift not mirrored by Typst."
)
_UNIFORM_PITCH_METRICS = (
    "Fixture is designed around a single baseline grid, so baseline pitch is gated."
)
_FONT_SIZE_PITCH_METRICS = (
    "Fixture isolates base font-size changes while keeping a single baseline grid, "
    "so pitch is gated."
)
_SIGCONF_BIBLATEX_PAGE_DIFF = (
    "Typst currently reflows the numeric BibLaTeX/software reference block to "
    "seven pages while LaTeX fits six."
)
_ALIAS_GOLDEN_EXEMPT = (
    "Compile-only alias smoke; sigconf-test owns the rendered layout golden."
)
_DRAFT_GOLDEN_EXEMPT = (
    "The rendered PDF embeds the compile date, so it is intentionally non-deterministic."
)
_AUTHORDRAFT_GOLDEN_EXEMPT = (
    "Authordraft embeds a compile timestamp in the margin, so it is intentionally "
    "non-deterministic."
)

# --- The test matrix -------------------------------------------------------
#
# Order is the run/report order. Twins come first, then smoke-only docs.
TESTS: dict[str, Test] = {
    "body-test": Test(
        kind="twin", pages=1, metrics_uniform_pitch=_UNIFORM_PITCH_METRICS,
        text_equal=True,
        note="body typography: font, size, baseline grid, justification, indent",
    ),
    "head-test": Test(
        kind="twin", pages=1, metrics_uniform_pitch=_UNIFORM_PITCH_METRICS,
        note="section / subsection / subsubsection / paragraph (run-in) headings",
    ),
    "figure-heading-test": Test(
        kind="twin", pages=1,
        note="figures immediately followed by display/run-in/paragraph headings; "
             "guards the post-figure paragraph-indent shim from leaking into headings.",
    ),
    "body2-test": Test(
        kind="twin", pages=1,
        note="figure & table captions, theorems (plain/definition/proof+QED), lists",
    ),
    "theorem-transition-test": Test(
        kind="twin", pages=1, text_equal=True,
        note="theorem numbering survives section-star/acks; add-punct honors ,;:",
    ),
    "list-test": Test(
        kind="twin", pages=1,
        note="isolated itemize/enumerate/quote geometry under NONACM — the class's "
             "option-time-hook bug reverts the list dimensions to amsart's "
             "(labelsep 5pt, settowidth margins); list-plain-test covers the "
             "plain-document side.",
    ),
    "list-plain-test": Test(
        kind="twin", pages=1,
        note="the same list fixture WITHOUT review/nonacm: acmart's own dimensions "
             "apply (labelsep 4pt, leftmargini 24.5pt, nested 8.5pt).",
    ),
    "fn-test": Test(
        kind="twin", pages=1,
        note="body footnotes + code/verbatim",
    ),
    "full-test": Test(
        kind="twin", pages=2, metrics_page1_only=_PAGE1_METRICS_SCOPE,
        metrics_uniform_pitch=_UNIFORM_PITCH_METRICS,
        note="multi-page cumulative spacing (reveals the \\flushbottom difference)",
    ),
    "title-test": Test(
        kind="twin", pages=1,
        note="frontmatter in isolation: title block, author fields, abstract, CCS, keywords",
    ),
    "manuscript-test": Test(
        kind="twin", pages=1,
        note="format=manuscript: single-column draft geometry (letterpaper, 9pt default) "
             "with the generic sans-bold section fonts shared with acmsmall.",
    ),
    "manuscript-pages-test": Test(
        kind="twin", pages=2, metrics_page1_only=_PAGE1_METRICS_SCOPE,
        text_equal="bag",
        text_assertions=(
            Assertion(engine="both", page=2, text="Lovelace and Hopper"),
            Assertion(engine="both", page=2, text="Manuscript submitted to ACM"),
        ),
        note="Continuation-page header/footer + multi-page body. Body flow reorders "
             "across engines, so text is gated order-independently (word-bag).",
    ),
    "acmlarge-test": Test(
        kind="twin", pages=1,
        note="format=acmlarge: large single-column journal geometry (10pt) with the "
             "\\sffamily\\large (regular-weight) section headings (acmart.dtx:8424).",
    ),
    "acmlarge-pages-test": Test(
        kind="twin", pages=2, metrics_page1_only=_PAGE1_METRICS_SCOPE,
        text_equal="bag",
        text_assertions=(
            Assertion(engine="both", page=2, text="Lovelace and Hopper"),
            Assertion(engine="both", page=2, text="111:2"),
            Assertion(engine="both", page=2, text="J. ACM, Vol. 37, No. 4, Article 111"),
        ),
        note="acmlarge continuation page header/footer; body reorders, so text is "
             "gated order-independently (word-bag).",
    ),
    "acmtog-test": Test(
        kind="twin", pages=1,
        note="format=acmtog: two-column JOURNAL. Spanning left @i title + author list, "
             "contact-info footnote + ACM bibstrip + journal footer, 9pt parindent, "
             "sans-large sections.",
    ),
    "acmtog-pages-test": Test(
        kind="twin", pages=2, metrics_page1_only=_PAGE1_METRICS_SCOPE,
        text_equal="bag",
        text_assertions=(
            Assertion(engine="both", page=2, text="Lovelace and Hopper"),
            Assertion(engine="both", page=2, text="111:2"),
            Assertion(engine="both", page=2,
                      text="ACM Trans. Graph., Vol. 37, No. 4, Article 111"),
        ),
        note="acmtog two-column continuation page; column order differs under "
             "extraction, so text is gated order-independently (word-bag).",
    ),
    "sigconf-test": Test(
        kind="twin", pages=1, text_equal="bag",
        text_assertions=(
            Assertion(engine="both", text="Abstract"),
            Assertion(engine="both", text="Keywords"),
            Assertion(engine="both", text="In Proceedings of ACM Conference"),
            Assertion(engine="both", text="ACM, New York, NY, USA"),
            Assertion(engine="both", kind="absent", text="Additional Key Words and Phrases"),
            Assertion(engine="typst", kind="absent", text="Journal of the ACM"),
        ),
        note="format=sigconf: two-column proceedings title page; text is word-bag gated.",
    ),
    "sigconf-pages-test": Test(
        kind="twin", pages=2, metrics_page1_only=_PAGE1_METRICS_SCOPE,
        text_equal="bag",
        text_assertions=(
            Assertion(engine="both", page=2, text="Lovelace and Hopper"),
            Assertion(engine="both", page=2,
                      text="Conference'17, June 2018, Washington, DC, USA"),
        ),
        note="sigconf two-column continuation page; column order differs under "
             "extraction, so text is gated order-independently (word-bag).",
    ),
    "sigconf-authors-test": Test(
        kind="twin", pages=1,
        note="Conference author grid with a centered partial final row.",
    ),
    "sigplan-test": Test(
        kind="twin", pages=2, metrics_page1_only=_PAGE1_METRICS_SCOPE,
        expected_metrics_diff=_TITLE_METRICS_DIFF, text_equal="bag",
        note="format=sigplan: 10pt proceedings variant + the sigplan style overrides "
             "(1./a. enum labels, bold zero-indent theorem heads with upright notes, "
             "italic noindent proof, bold-label captions). Metrics are report-only for "
             "title bbox drift; two-column flow reorders, so text is word-bag gated.",
    ),
    "acmengage-test": Test(
        kind="twin", pages=1, expected_metrics_diff=_COVER_METRICS_DIFF,
        note="format=acmengage: 10pt sigconf variant with Engage copyright metadata.",
    ),
    "acmcp-test": Test(
        kind="twin", pages=1, expected_metrics_diff=_COVER_METRICS_DIFF, text_equal=False,
        expected_text_diffs=(
            ExpectedTextDiff(
                latex="Code and data links: https://example.com/data Background",
                typst="Code and data links: https://example.com/ data Keywords: datasets",
                cause=ExtractionArtifact("cover-infobox URL extraction"),
            ),
        ),
        text_assertions=(
            Assertion(engine="both", text="Research Article"),
            Assertion(engine="both", text="Keywords: datasets"),
            Assertion(engine="both", text="BT designed the study"),
            Assertion(engine="both", text="Authors' Contact"),
            Assertion(engine="both", text="Information: Ben"),
            Assertion(engine="both",
                      text="Journal of the ACM, Volume 37, Issue 4, Article 111"),
            Assertion(engine="typst", kind="absent",
                      text="Permission to make digital or hard copies"),
            Assertion(engine="typst", kind="absent",
                      text="ACM Reference Format"),
            Assertion(engine="typst", kind="absent",
                      text="Additional Key Words and Phrases"),
        ),
        note="format=acmcp: JDS cover page, infobox, unnumbered sections, and author contributions.",
    ),
    "sigchi-a-test": Test(
        kind="twin", pages=3, metrics_page1_only=_PAGE1_METRICS_SCOPE,
        expected_metrics_diff=_LANDSCAPE_METRICS_DIFF, text_equal="bag",
        note="format=sigchi-a: landscape extended abstract with a bold-small captioned "
             "figure; text bags and page parity are gated.",
    ),
    "startpage-test": Test(
        kind="twin", pages=2, metrics_page1_only=_PAGE1_METRICS_SCOPE,
        text_equal="bag",
        text_assertions=(
            Assertion(engine="both", page=2, text="111:8"),
            Assertion(engine="both", page=2, text="Lovelace and Hopper"),
        ),
        note="\\startPage seeds the page counter: folios, running-head parity, and "
             "the journal footer follow the counter (acmart.dtx:6822-6825). Body "
             "reorders, so text is word-bag gated.",
    ),
    "fontsize-9-pages-test": Test(
        kind="twin", pages=2, metrics_page1_only=_PAGE1_METRICS_SCOPE,
        text_equal="bag",
        text_assertions=(
            Assertion(engine="both", page=2, text="111:2"),
            Assertion(engine="both", page=2, text="Lovelace"),
        ),
        note="multi-page acmsmall at the NON-DEFAULT 9pt base: heightrounded "
             "geometry (571pt), rescaled ladder, page parity, continuation "
             "head/folio. Body reorders, so text is word-bag gated.",
    ),
    "fontsize-8-test": Test(
        kind="twin", pages=1, metrics_uniform_pitch=_FONT_SIZE_PITCH_METRICS,
        text_equal=True,
        note="Base font-size option `8pt`: amsart \\@typesizes ladder + "
             "baselineskip-derived heading/skip scaling. Body is on one grid, so pitch is gated.",
    ),
    "fontsize-9-test": Test(
        kind="twin", pages=1, metrics_uniform_pitch=_FONT_SIZE_PITCH_METRICS,
        text_equal=True,
        note="Base font-size option `9pt`.",
    ),
    "fontsize-11-test": Test(
        kind="twin", pages=1, metrics_uniform_pitch=_FONT_SIZE_PITCH_METRICS,
        text_equal=True,
        note="Base font-size option `11pt`.",
    ),
    "fontsize-12-test": Test(
        kind="twin", pages=1, metrics_uniform_pitch=_FONT_SIZE_PITCH_METRICS,
        text_equal=True,
        note="Base font-size option `12pt`.",
    ),
    "bib-test": Test(
        kind="smoke", pages=1,
        text_assertions=(
            Assertion(engine="typst", text="References"),
            Assertion(engine="typst", text="Ablamowicz"),
        ),
        note="Typst-only smoke for the opt-in \"typst\" (native CSL) bibliography backend: "
             "confirms it compiles and renders a reference list via Typst's built-in ACM CSL "
             "style. Not a faithfulness twin — \"typst\" is a documented approximation of "
             "LaTeX; the faithful default \"bibtex\" backend is validated by keycite / crossref "
             "/ bib-all / sample-* twins.",
    ),
    "bib-cite-links": Test(
        kind="smoke", pages=1,
        text_assertions=(
            Assertion(engine="typst", text="References"),
            # numbers must resolve (regression: the convergence edge left them "?")
            Assertion(engine="typst", text="[1]"),
            Assertion(engine="typst", text="[8]"),
        ),
        min_internal_links=8,
        min_internal_destinations=8,
        note="Regression for the `bibtex` cite-path convergence edge (many `@key`s incl. "
             "dotted keys in one sentence used to crash with `read(none)`), and for the "
             "in-text cite -> reference-list hyperlinks. Golden-pins the linked numbers.",
    ),
    "biblatex-test": Test(
        kind="twin", pages=1,
        text_assertions=(
            Assertion(engine="latex", text="Communications of the ACM"),
            Assertion(engine="typst", text="References"),
        ),
        note="small BibLaTeX acmnumeric isolator so the full sample-sigconf-biblatex "
             "reference-format path is checked without the full upstream sample body.",
    ),
    "biblatex-edge": Test(
        kind="twin", pages=1,
        text_assertions=(
            Assertion(engine="both", text="Lecture Notes in Computer Science. Vol. 1494. "
                      "Ed. by Grzegorz Rozenberg and Frits W. Vaandrager"),
            Assertion(engine="both", text="Ed. by Ian Editor. \"The title of book one. "
                      "The book subtitle.\" (1st. ed.). Vol. 9."),
            Assertion(engine="both", text="Dave Novak. Mar. 2003. \"Solder man.\""),
            Assertion(engine="both", text="Barack Obama. Mar. 2008. A more perfect union. "
                      "Video. (Mar. 2008)."),
            Assertion(engine="both", text="isbn: 3-540-13829-3"),
            Assertion(engine="both", text="Institutional members of the TEX Users Group. "
                      "Retrieved May 27, 2017"),
        ),
        note="BibLaTeX author-year edge cases: book chapters, videos, authorless online entries, ISBNs.",
    ),
    "biblatex-driver-test": Test(
        kind="twin", pages=1,
        text_assertions=(
            Assertion(engine="both", text="Series book. (1st ed.). Book Series 11. "
                      "Vol. 3. Companion volume."),
            Assertion(engine="both", text="Ed. by Evan Editor. \"A contributed chapter.\" "
                      "Beatrice Bookauthor. Big Book of Drivers. (2nd ed.). Vol. 5."),
            Assertion(engine="both", text="Driver Series 7. (3rd ed.). Vol. 2. "
                      "Ed. by Eve Editor and Oscar Organizer"),
            Assertion(engine="both", text="isbn: 978-1-23456-789-7"),
            Assertion(engine="both", text="A translator-led book. Trans. by Trevor Translator. "
                      "Translation House, London."),
            Assertion(engine="both", text="Avery Author. 2019. \"An article in translation.\" "
                      "Trans. by Tina Translator."),
            Assertion(engine="both", text="Pat Inventor. May 4, 2020. "
                      "\"A carefully specified widget.\" (May 4, 2020). "
                      "Utility Patent Patent No. US-123456"),
            Assertion(engine="both", text="Holding Company. Filed electronically. doi:10.1000/patent"),
        ),
        note="BibLaTeX driver order for book/chapter, translator, and patent fields.",
    ),
    "biblatex-driver-numeric-test": Test(
        kind="twin", pages=1,
        text_assertions=(
            Assertion(engine="both", text="Riley Report. 2023. MIXED Case Report Title. "
                      "Research Note RN-7. Example Lab, Ann Arbor, MI."),
            Assertion(engine="both", text="Tara Techreport. 2024. UPPERCASE Techreport Title. "
                      "Technical Memorandum TM-9. Legacy Lab, Palo Alto, CA."),
            Assertion(engine="both", text="2018. A translator-led book. "
                      "Trans. by Trevor Translator. Translation House, London."),
            Assertion(engine="both", text="Avery Author. 2019. An article in translation. "
                      "Trans. by Tina Translator."),
            Assertion(engine="both", text="Pat Inventor. 2020. A carefully specified widget. "
                      "(May 4, 2020). Utility Patent Patent No. US-123456"),
        ),
        note="BibLaTeX numeric report sourcemap plus translator and patent drivers.",
    ),
    "bib-all": Test(
        kind="twin", pages=1,
        note="BST backend sweep over ACM-Reference-Format entry types; text and links are gated.",
    ),
    "bib-edge": Test(
        kind="twin", pages=1,
        note="BST backend edge cases: DOI/pages/key fallback, macros, strings, names, accents.",
        # Word-level guards for things the whitespace-free char bag can't see.
        text_assertions=(
            Assertion(engine="both", text="Tech Press, Ltd."),       # concat keeps the space
            Assertion(engine="both", text="Comput. Surveys"),        # csur macro -> canon.abbrev
            Assertion(engine="both", text="Submitted to Mind"),      # @unpublished note
            Assertion(engine="both", text="Maria de la Cruz"),       # von-name parsing
            Assertion(engine="both", kind="absent", text="doi.acm.org"),  # strip.doi drops the host prefix
            Assertion(engine="both", text="Article 17"),             # articleno path
            Assertion(engine="both", text="9:1"),                    # reduce.pages keeps n:1--n:m verbatim
            Assertion(engine="both", text="250 book pages"),         # format.bookpages
            Assertion(engine="both", text="Issue 7"),                # issue field
            Assertion(engine="both", text="Preprint"),               # howpublished in @article
            Assertion(engine="both", text="Jan von der Berg"),       # comma von-name
            Assertion(engine="both", text="Ludwig van Beethoven"),   # no-comma von-name
        ),
    ),
    "crossref": Test(
        kind="twin", pages=1,
        note="BibTeX crossref inheritance, listing threshold, key fallback, and distinct URL fields.",
        text_assertions=(
            Assertion(engine="both", text="See ["),                  # crossref "See [N]"
            Assertion(engine="both", text="Workshop on Small Things"),  # inherited booktitle (excluded parent)
            Assertion(engine="both", text="GangOfFour"),             # proceedings org->key fallback
        ),
    ),
    "authoryear": Test(
        kind="twin", pages=1,
        note="BST backend author-year labels, year disambiguation, citations, and unnumbered references.",
        text_assertions=(
            Assertion(engine="both", text="2020a"),                  # \natexlab suffix
            Assertion(engine="both", text="Jones et al."),           # >2-author short label (\citet)
        ),
    ),
    "mathfields": Test(
        kind="twin", pages=1,
        expected_font_diffs=(
            ExpectedFontDiff(
                latex="Bounds of 𝑂 (𝑛 log 𝑛) with 𝛼 + 𝛽 ≤ 𝛾 and 𝜇 → ∞.",
                typst="Bounds of 𝑂(𝑛 log 𝑛) with 𝛼 + 𝛽 ≤ 𝛾 and 𝜇 → ∞.",
                cause=AcceptedTypstBehavior("Typst math operators render with the math font instead of LaTeX's text-roman operator font"),
            ),
            ExpectedFontDiff(
                latex="Products 𝑎𝑏 and tensor indices 𝑥𝑖 𝑗 with 2𝑛 terms.",
                typst="Products 𝑎𝑏 and tensor indices 𝑥𝑖𝑗 with 2𝑛 terms.",
                cause=AcceptedTypstBehavior("inline math script glyphs render 0.5pt larger than LaTeX"),
            ),
            ExpectedFontDiff(
                latex="On 𝑛2 bounds for 𝑎 ⊕ 𝑏 with 𝑥 2𝑛 ≤ 𝑦.",
                typst="On 𝑛2 bounds for 𝑎 ⊕ 𝑏 with 𝑥 2𝑛 ≤ 𝑦.",
                cause=AcceptedTypstBehavior("inline math fraction/script glyphs render 0.5pt larger than LaTeX"),
            ),
        ),
        note="BST reference-field math rendering, including operators, scripts, blackboard, and overrides.",
        text_assertions=(
            Assertion(engine="both", text="-calculus"),              # $\lambda$-calculus
        ),
    ),
    "keycite": Test(
        kind="twin", pages=1,
        note="Native `@key` citations routed through the BST backend.",
    ),
    "notes-test": Test(
        kind="twin", pages=1,
        note="title/subtitle/author notes, corresponding mark, received line, and acks. "
             "The title block and footnote stack mix leadings, so pitch is reported, not gated.",
    ),
    "options-test": Test(
        kind="twin", pages=2, metrics_page1_only=_PAGE1_METRICS_SCOPE,
        note="option toggles for nonacm, printccs, printfolios, balance, and natbib.",
    ),
    "authorversion-test": Test(
        kind="twin", pages=1,
        note="author-version copyright block (suppressed permission text + \"author's "
             "version ... Version of Record\" notice). Mixed leadings, so pitch is reported.",
    ),
    "authorversion-conf-test": Test(
        kind="twin", pages=1, text_equal="bag",
        expected_metrics_diff=_TITLE_METRICS_DIFF,
        text_assertions=(
            Assertion(engine="both", text="Conference'17, Washington, DC, USA"),
            Assertion(engine="both",
                      text="Version of Record was published in Proceedings of ACM "
                           "Conference (Conference'17)"),
            Assertion(engine="typst", kind="absent", text="ACM ISBN"),
        ),
        note="author-version on a CONFERENCE format: the italic conference-info line "
             "still prints and the Version-of-Record notice names the booktitle "
             "(acmart.dtx:6615/6638). Two-column extraction order, so word-bag.",
    ),
    "anonymous-test": Test(
        kind="twin", pages=1,
        text_assertions=(
            Assertion(engine="both", text="ANONYMOUS AUTHOR(S)"),
            Assertion(engine="both", text="SUBMISSION ID: 123-A56-BU3"),
            Assertion(engine="typst", kind="absent", text="Trovato"),
            Assertion(engine="typst", kind="absent", text="Contact Information"),
        ),
        note="double-anonymous journal submission: anonymized author strip with the "
             "uppercased \"SUBMISSION ID:\" second line (acmart.dtx:5190-5193), "
             "suppressed contact footnote, anonymized ACM reference block.",
    ),
    "language-test": Test(
        kind="twin", pages=1,
        note="French main language plus English translated title, abstract, and keywords.",
    ),
    "language-de-test": Test(
        kind="twin", pages=1,
        note="German `language=german`: keywordsname/acksname/proofname + tablename "
             "(\"Tabelle\") localized, figure label still \"Fig.\"",
    ),
    "language-es-test": Test(
        kind="twin", pages=1,
        note="Spanish `language=spanish`: keywordsname/acksname/proofname + tablename "
             "(\"Cuadro\") localized, figure label still \"Fig.\"",
    ),
    # Full twins of the bundled acmart samples (acmart/samples/*.tex).
    # Each has a matched .tex/.typ pair in tests/twins/; assets (sample-base.bib,
    # sample-franklin.png, sampleteaser.*) are vendored into tests/twins/ so the
    # build does not depend on the acmart/ reference folder. They share one body via
    # _sample-common.typ; only the preamble (format + options) differs.
    "sample-acmsmall": Test(
        kind="twin", pages=11, expected_metrics_diff=_FULL_SAMPLE_METRICS_DIFF,
        text_equal=False,
        expected_text_diffs=(
            ExpectedTextDiff(
                latex="BEN TROVATO* and G.K.M. TOBIN✉* , Institute for Clarity in "
                      "Documentation, USA",
                typst="BEN TROVATO* and G.K.M. TOBIN *, Institute for Clarity in "
                      "Documentation, USA",
                cause=ExtractionArtifact("author-note marker extraction"),
            ),
            ExpectedTextDiff(
                latex="centered horizontally- is produced by the equation environment",
                typst="centered horizontally -is produced by the equation environment",
                cause=ExtractionArtifact("display-equation hyphen extraction"),
            ),
        ),
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="and follow it with another numbered equation: ∫ π +2 ∞ ∑ xi = f i=0 (2)",
                typst="and follow it with another numbered equation: ∞ π+2 ∑ xi = ∫ i=0 0 f (2)",
                cause=ExtractionArtifact("display-math token-order extraction"),
            ),
        ),
        note="full twin of the upstream acmsmall sample.",
    ),
    "sample-manuscript": Test(
        kind="twin", pages=11, review_line_numbers=True,
        text_equal=False,
        expected_text_diffs=(
            ExpectedTextDiff(
                latex="BEN TROVATO* and G.K.M. TOBIN✉* , Institute for Clarity in "
                      "Documentation, USA",
                typst="BEN TROVATO* and G.K.M. TOBIN *, Institute for Clarity in "
                      "Documentation, USA",
                cause=ExtractionArtifact("author-note marker extraction"),
            ),
        ),
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="and follow it with another numbered equation: (1) n→∞ ∫ π +2 xi = f (2)",
                typst="and follow it with another numbered equation: ∞ π+2 ∑ xi = ∫ i=0 f (2)",
                cause=ExtractionArtifact("display-math token-order extraction"),
            ),
        ),
        note="upstream manuscript sample (manuscript,screen,review + proceedings "
             "metadata). Single-column review style with margin line numbers.",
    ),
    "sample-acmlarge": Test(
        kind="twin", pages=11,
        text_equal=False,
        expected_text_diffs=(
            ExpectedTextDiff(
                latex="BEN TROVATO* and G.K.M. TOBIN✉* , Institute for Clarity in "
                      "Documentation, USA",
                typst="BEN TROVATO* and G.K.M. TOBIN *, Institute for Clarity in "
                      "Documentation, USA",
                cause=ExtractionArtifact("author-note marker extraction"),
            ),
            ExpectedTextDiff(
                latex="doi:10.1007/3540-09237-4 [19] Lars Hörmander",
                typst="doi:10.1007/3-540-09237-4 [19] Lars Hörmander",
                cause=ExtractionArtifact("wrapped DOI extraction"),
            ),
        ),
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="and follow it with another numbered equation: ∞ ∑ ∫ π +2 xi = i=0 f (2)",
                typst="and follow it with another numbered equation: ∞ π+2 ∑ xi = ∫ i=0 0 f (2)",
                cause=ExtractionArtifact("display-math token-order extraction"),
            ),
        ),
        note="upstream acmlarge sample (wide single-column journal, POMACS).",
    ),
    "sample-sigconf": Test(
        kind="twin", pages=6,
        text_equal=False,
        expected_text_diffs=(
            ExpectedTextDiff(
                latex="Name of the Title Is Hope Ben Trovato* G.K.M. Tobin✉* "
                      "trovato@corporation.com",
                typst="Name of the Title Is Hope Ben Trovato* ✉ G.K.M. Tobin * "
                      "trovato@corporation.com",
                cause=ExtractionArtifact("author-note marker extraction"),
            ),
            # (The former "wrapped video URL extraction" diff is gone: with the
            # bibliography hanging indent now matching natbib's \bibhang, the
            # reference reflows exactly as LaTeX and the video URL + docid + [28]
            # cite extract identically in both engines.)
        ),
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="If your figure contains thirdparty material, you must clearly "
                      "identify it as such, as shown in the example below. Comments "
                      "Author For tables",
                typst="If your figure contains thirdparty material, you must clearly "
                      "identify it as such, as shown in the example below. Your figures "
                      "should contain a caption",
                cause=ExtractionArtifact("figure/table stream interleave"),
            ),
        ),
        note="upstream sigconf sample: two-column proceedings with author grid and teaser figure.",
    ),
    "sample-sigplan": Test(
        kind="twin", pages=7, expected_metrics_diff=_FULL_SAMPLE_METRICS_DIFF,
        text_equal=False,
        expected_text_diffs=(
            ExpectedTextDiff(
                latex="Name of the Title Is Hope Ben Trovato* G.K.M. Tobin✉* "
                      "trovato@corporation.com",
                typst="Name of the Title Is Hope Ben Trovato* ✉ G.K.M. Tobin * "
                      "trovato@corporation.com",
                cause=ExtractionArtifact("author-note marker extraction"),
            ),
            ExpectedTextDiff(
                latex="A clear and well-documented LAT X document is presented as E "
                      "an article",
                typst="A clear and well-documented LATEX document is pre sented as "
                      "an article",
                cause=ExtractionArtifact("LaTeX logo extraction"),
            ),
        ),
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="If your figure contains third-party material, you must clearly "
                      "identify it as such, as shown in the example below. Math Equations",
                typst="If your figure contains third-party material, you must clearly "
                      "identify it as such, as shown in the example below. Your figures "
                      "should contain a caption",
                cause=ExtractionArtifact("figure/math stream interleave"),
            ),
        ),
        note="upstream sigplan sample (two-column SIGPLAN proceedings, 10pt).",
    ),
    "sample-acmsmall-submission": Test(
        kind="twin", pages=10, review_line_numbers=True,
        text_equal=False,
        expected_text_diffs=(
            ExpectedTextDiff(
                latex="https://doi.org/XXXXXXX.XXXXXXX Introduction ACM's consolidated "
                      "article template",
                typst="https://doi.org/XXXXXXX.XXXXXXX ACM's consolidated article template",
                cause=ExtractionArtifact("anonymous-review heading extraction"),
            ),
            ExpectedTextDiff(
                latex="centered horizontally- is produced by the equation environment",
                typst="centered horizontally -is produced by the equation environment",
                cause=ExtractionArtifact("display-equation hyphen extraction"),
            ),
        ),
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="Figure captions are placed below the figure. J. ACM, Vol. 37, "
                      "No. 4, Article 111. Publication date: August 2018",
                typst="Figure captions are placed below the figure. Every figure should "
                      "also have a figure description",
                cause=ExtractionArtifact("review-line figure-caption interleave"),
            ),
        ),
        note="upstream acmsmall double-anonymous review sample "
             "(screen,anonymous,review): anonymized author strip + line numbers.",
    ),
    "sample-acmsmall-conf": Test(
        kind="twin", pages=11, expected_metrics_diff=_FULL_SAMPLE_METRICS_DIFF,
        text_equal=False,
        expected_text_diffs=(
            ExpectedTextDiff(
                latex="BEN TROVATO* and G.K.M. TOBIN✉* , Institute for Clarity in "
                      "Documentation, USA",
                typst="BEN TROVATO* and G.K.M. TOBIN *, Institute for Clarity in "
                      "Documentation, USA",
                cause=ExtractionArtifact("author-note marker extraction"),
            ),
        ),
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="Now, we’ll enter an unnumbered equation: ∞ ∑︁ 𝑥 +1 𝑖=0 "
                      "and follow it with another numbered equation: ∫ 𝜋 +2",
                typst="Now, we’ll enter an unnumbered equation: ∞ ∑𝑥 + 1 𝑖=0 "
                      "and follow it with another numbered equation: ∞ 𝜋+2 ∑",
                cause=ExtractionArtifact("display-math token-order extraction"),
            ),
        ),
        note="upstream acmsmall-for-a-conference sample (acmsmall journal format "
             "with conference metadata replacing the journal metadata).",
    ),
    "sample-acmtog": Test(
        kind="twin", pages=6, expected_metrics_diff=_FULL_SAMPLE_METRICS_DIFF,
        text_equal=False,
        expected_text_diffs=(
            ExpectedTextDiff(
                latex="BEN TROVATO* and G.K.M. TOBIN✉* , Institute for Clarity in "
                      "Documentation, USA",
                typst="BEN TROVATO* and G.K.M. TOBIN *, Institute for Clarity in "
                      "Documentation, USA",
                cause=ExtractionArtifact("author-note marker extraction"),
            ),
        ),
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                # The two-column reflow (shorter booktabs rows) lands the run-in
                # subsubsection "9.1.1" past the inline-equation text in Typst's tag
                # order, while LaTeX's pdftotext reads it (with the "111:3" running
                # head) before that text — the same run-in/running-head interleave.
                latex="9.1.1 • 111:3 how this equation",
                typst="(See next section). 9.1.1 Subsubsection. This is a subsubsection.",
                cause=ExtractionArtifact("run-in heading / running-head interleave"),
            ),
        ),
        note="upstream acmtog sample (two-column TOG journal). Uses the author-year "
             "citation style (\\citestyle{acmauthoryear}) via the bst backend.",
    ),
    "sample-acmtog-conf": Test(
        kind="twin", pages=6,
        text_equal=False,
        expected_text_diffs=(
            ExpectedTextDiff(
                latex="BEN TROVATO* and G.K.M. TOBIN✉* , Institute for Clarity in "
                      "Documentation, USA",
                typst="BEN TROVATO* and G.K.M. TOBIN *, Institute for Clarity in "
                      "Documentation, USA",
                cause=ExtractionArtifact("author-note marker extraction"),
            ),
        ),
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="If your figure contains thirdparty material, you must clearly "
                      "identify it as such, as shown in the example below. Comments "
                      "Author For tables",
                typst="If your figure contains thirdparty material, you must clearly "
                      "identify it as such, as shown in the example below. Your figures "
                      "should contain a caption",
                cause=ExtractionArtifact("figure/teaser stream interleave"),
            ),
        ),
        note="upstream acmtog-for-a-conference sample (acmtog two-column with "
             "conference metadata + teaser; author-year citations via the bst backend).",
    ),
    "sample-sigconf-i13n": Test(
        kind="twin", pages=7, expected_metrics_diff=_FULL_SAMPLE_METRICS_DIFF,
        text_equal=False,
        expected_text_diffs=(
            ExpectedTextDiff(
                latex="El nombre del título es esperanza Ben Trovato* G.K.M. Tobin✉* "
                      "trovato@corporation.com",
                typst="El nombre del título es esperanza Ben Trovato* ✉ G.K.M. "
                      "Tobin * trovato@corporation.com",
                cause=ExtractionArtifact("translated-title author-note marker extraction"),
            ),
        ),
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="If your figure contains thirdparty material, you must clearly "
                      "identify it as such, as shown in the example below. The “Teaser "
                      "Figure”",
                typst="If your figure contains thirdparty material, you must clearly "
                      "identify it as such, as shown in the example below. Your figures "
                      "should contain a caption",
                cause=ExtractionArtifact("translated sample figure/teaser interleave"),
            ),
        ),
        note="upstream sigconf internationalization sample: \\translatedtitle + "
             "translatedabstract in French/German/Spanish (English main), each "
             "abstract headed by its babel \\abstractname.",
    ),
    "sample-sigconf-authordraft": Test(
        kind="twin", pages=6,
        golden_exempt=_AUTHORDRAFT_GOLDEN_EXEMPT,
        review_line_numbers=True,
        text_equal=False,
        expected_text_diffs=(
            ExpectedTextDiff(
                latex="Name of the Title Is Hope Ben Trovato* Lars Thørväld Valerie "
                      "Béranger G.K.M. Tobin✉*",
                typst="Name of the Title Is Hope Ben Trovato* ✉* G.K.M. Tobin "
                      "trovato@corporation.com",
                cause=ExtractionArtifact("authordraft author-stream extraction"),
            ),
        ),
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="If your figure contains thirdparty material, you must clearly "
                      "identify it as such, as shown in the example below. Un pu Figure 2",
                typst="If your figure contains thirdparty material, you must clearly "
                      "identify it as such, as shown in the example below. Your figures "
                      "should contain a caption",
                cause=ExtractionArtifact("authordraft line-number figure interleave"),
            ),
        ),
        note="upstream sigconf authordraft sample: draft watermark, line numbers, timestamp.",
    ),
    "sample-acmsmall-biblatex": Test(
        kind="twin", pages=11, expected_metrics_diff=_FULL_SAMPLE_METRICS_DIFF,
        text_equal=False,
        expected_text_diffs=(
            ExpectedTextDiff(
                latex="BEN TROVATO* and G.K.M. TOBIN✉* , Institute for Clarity in "
                      "Documentation, USA",
                typst="BEN TROVATO* and G.K.M. TOBIN *, Institute for Clarity in "
                      "Documentation, USA",
                cause=ExtractionArtifact("author-note marker extraction"),
            ),
            ExpectedTextDiff(
                latex="world wide web resource [Ablamowicz and Fauser 2007; "
                      "Poker-Edge.Com 2006; Thornburg 2001]",
                typst="world wide web resource [Ablamowicz and Fauser 2007; "
                      "PokerEdge.Com 2006; Thornburg 2001]",
                cause=ExtractionArtifact("software URL punctuation extraction"),
            ),
        ),
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="and follow it with another numbered equation: ∫ π +2 ∞ ∑ xi = f i=0 (2)",
                typst="and follow it with another numbered equation: ∞ π+2 ∑ xi = ∫ i=0 0 f (2)",
                cause=ExtractionArtifact("display-math token-order extraction"),
            ),
        ),
        text_assertions=(
            Assertion(engine="both", text="Software project: [Delebecque et al. 1994; "
                   "The CGAL Project 1996]. Software Version: [Greenman and Felleisen "
                   "2020]. Software Module: [Karavelas 2020]. Code fragment: "
                   "[Di Cosmo and Danelutto 2020]."),
            Assertion(engine="both", text="[SW exc.] Roberto Di Cosmo and Marco Danelutto"),
            Assertion(engine="both", text="R. Baggett, M. Simecek, C. Chambellan, "
                      "K. Tsui, and M. Fraune. 2025. Fluidity in the Phased Framework "
                      "of Technology Acceptance"),
            Assertion(engine="both", text="Mobile Telepresence Robots. (2025)."),
            Assertion(engine="both", text="Jacques Cohen, (Ed.). Nov. 1996. "
                      "Special issue: Digital Libraries. Commun. ACM 39, 11 "
                      "(Nov. 1996)."),
            Assertion(engine="both", text="David Harel. 1979. First-Order Dynamic "
                      "Logic. Lecture Notes in Computer Science. Vol. 68."),
            Assertion(engine="both", text="David Harel. 1978. LOGICS of Programs: "
                      "AXIOMATICS and DESCRIPTIVE POWER. MIT Research Lab Technical "
                      "Report TR-200."),
            Assertion(engine="both", text="Newton Lee. Jan. 2005. \"Interview with "
                      "Bill Kinder: January 13, 2005.\" Comput. Entertain., 3, 1, "
                      "(Jan. 2005), 4."),
        ),
        note="upstream acmsmall-biblatex sample with author-year software artifact cites.",
    ),
    "sample-sigconf-biblatex": Test(
        kind="twin", pages=7, expected_page_count_diff=_SIGCONF_BIBLATEX_PAGE_DIFF,
        text_equal=False,
        expected_text_diffs=(
            ExpectedTextDiff(
                latex="Name of the Title Is Hope Ben Trovato* G.K.M. Tobin✉* "
                      "trovato@corporation.com",
                typst="Name of the Title Is Hope Ben Trovato* ✉ G.K.M. Tobin * "
                      "trovato@corporation.com",
                cause=ExtractionArtifact("author-note marker extraction"),
            ),
        ),
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="If your figure contains thirdparty material, you must clearly "
                      "identify it as such, as shown in the example below. 12.1 The "
                      "“Teaser Figure”",
                typst="If your figure contains thirdparty material, you must clearly "
                      "identify it as such, as shown in the example below. Your figures "
                      "should contain a caption",
                cause=ExtractionArtifact("BibLaTeX figure/teaser stream interleave"),
            ),
        ),
        text_assertions=(
            Assertion(engine="both", text="Software project: [41, 12]. Software Version: "
                   "[17]. Software Module: [25]. Code fragment: [13]."),
            Assertion(engine="both", text="[SW Rel.] Ben Greenman and Matthias Felleisen"),
            Assertion(engine="both", text="2004. Ieee tcsc executive committee. In "
                      "Proceedings of the IEEE International Conference on Web Services"),
            Assertion(engine="both", text="3, 1, (Jan. 2005), 4. doi:"
                      "10.1145/1057270.1057278."),
            Assertion(engine="both", text="2017. Institutional members of the TEX users "
                      "group. Retrieved May 27, 2017"),
        ),
        note="upstream sigconf-biblatex sample with numeric software artifact cites; page parity is open.",
    ),
    "sample-acmcp": Test(
        kind="twin", pages=1, expected_metrics_diff=_COVER_METRICS_DIFF,
        text_equal="bag",
        note="upstream acmcp sample: JDS banner, cover infobox, and author contributions.",
    ),
    "sample-acmengage": Test(
        kind="twin", pages=3, expected_metrics_diff=_FULL_SAMPLE_METRICS_DIFF,
        text_equal="bag",
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="ACM ISBN 978-x-xxxx-xxxx-x/YYYY/MM "
                      "https://doi.org/XXXXXXX.XXXXXXX Author Three",
                typst="ACM ISBN 978-x-xxxx-xxxx-x/YYYY/MM "
                      "https://doi.org/XXXXXXX.XXXXXXX be based on at least one "
                      "evidenced-based teaching",
                cause=ExtractionArtifact("Engage metadata/sidebar stream interleave"),
            ),
        ),
        note="upstream acmengage sample: EngageCSEdu layout, synopsis, metadata, and CC license.",
    ),
    # Smoke-only docs (no LaTeX twin).
    "siggraph-test": Test(
        kind="smoke", pages=1, golden_exempt=_ALIAS_GOLDEN_EXEMPT,
        note="obsolete `siggraph` option aliases to sigconf; compile-only smoke.",
    ),
    "sigchi-test": Test(
        kind="smoke", pages=1, golden_exempt=_ALIAS_GOLDEN_EXEMPT,
        note="obsolete public option `sigchi` aliases to sigconf (matching the bundled "
             "LaTeX class). Typst-only alias compile check (see siggraph-test).",
    ),
    "draft-test": Test(
        kind="smoke", pages=1, golden_exempt=_DRAFT_GOLDEN_EXEMPT,
        note="author-draft timestamp mode; non-deterministic compile-only smoke.",
    ),
    "urlbreak-test": Test(
        kind="smoke", pages=1,
        note="`urlbreakonhyphens: false` smoke with golden-pinned Typst URL breaking.",
    ),
    "feature-test": Test(
        kind="smoke", pages=1,
        note="Typst-only smoke for badges, teaser, title notes, and subtitle notes.",
    ),
    "defaults-test": Test(
        kind="smoke", pages=1,
        golden_exempt="Behavior smoke only; focused format twins own the rendered layout.",
        text_assertions=(
            Assertion(engine="typst", text="Manuscript submitted to ACM"),
            Assertion(engine="typst", text="https://doi.org/10.1145/nnnnnnn.nnnnnnn"),
        ),
        note="Default acmart options: format=manuscript and placeholder DOI.",
    ),
    "proceedings-defaults-test": Test(
        kind="smoke", pages=2,
        golden_exempt="Behavior smoke only; sigconf twins own the rendered layout.",
        text_assertions=(
            Assertion(engine="typst", text="Conference'17, July 2017, Washington, DC, USA"),
            Assertion(engine="typst", text="Proceedings of ACM Conference (Conference'17)"),
            Assertion(engine="typst", text="https://doi.org/10.1145/nnnnnnn.nnnnnnn"),
        ),
        note="Proceedings defaults: placeholder \\acmConference/\\acmBooktitle and DOI.",
    ),
    "bib-relative-test": Test(
        kind="smoke", pages=1,
        note="Regression: a single relative #bibliography path resolves against the "
             "caller on the bibtex engine backend (arguments-origin threaded to read()).",
    ),
}


# --- Tier 1.6: expected compile-error cases --------------------------------
#
# Each case compiles a tiny acmsmall document with the bad option spliced in and
# asserts the compile fails with a diagnostic containing the expected substring.
# name -> (extra acmart.with(...) argument, expected diagnostic substring)
# name -> (extra acmart.with arg, expected substring[, custom body]).
ERROR_CASES: dict[str, tuple] = {
    "bad-copyright": ('copyright: "definitely-not-a-mode",', "unsupported copyright mode"),
    "bad-cc-type": ('copyright: "cc", cc-type: "by-mystery",', "unsupported Creative Commons type"),
    "bad-cc-version": ('copyright: "cc", cc-version: "2.5",', "unsupported Creative Commons version"),
    "bad-font-size": ("font-size: 13pt,", "must be a length, one of"),
    "bad-font-size-type": ('font-size: "10pt",', "must be a length"),
    "bad-language": ('language: "klingon",', "unsupported language"),
    "draft-option": ("draft: true,", "option `draft` has no effect"),
    "bad-journal": ('journal: "NOT-A-JOURNAL",', "unknown ACM journal code"),
    "missing-affiliation-country": (
        'authors: ((name: "Ada Lovelace", affiliation: (institution: "Analytical Engine Institute")),),',
        "every author affiliation must include a nonempty `country`",
    ),
    "missing-affiliation-country-nonacm": (
        'nonacm: true, authors: ((name: "Ada Lovelace", affiliation: (institution: "Analytical Engine Institute")),),',
        "every author affiliation must include a nonempty `country`",
    ),
    # the "bst" backend errors on an unsupported TeX command rather than passing
    # it through silently, pointing the user at the tex-render callback.
    "bst-unknown-cmd": (
        "",
        "unsupported TeX command",
        '#import "/src/lib.typ": default-tex-render\n'
        '#default-tex-render("a \\\\frobnicate{x} title")',
    ),
    # A SINGLE relative .bib works on every backend (bib-relative-test), but MULTIPLE
    # files force the shadow to index into the arguments, dropping each path's origin
    # — so a multi-file relative bibliography on the engine backends is rejected with a
    # clear message asking for absolute paths, rather than a confusing "file not found".
    "bibtex-relative-multi": (
        'bib-backend: "bibtex",',
        "must use project-absolute",
        '#bibliography(("a.bib", "b.bib"))',
    ),
    # Citing on the bibtex/biblatex backend with no acmart `#bibliography` registered
    # (here: the `#bibliography` call is simply missing) is an actionable error, not a
    # cryptic `read(none)` deep in the .bib reader — see `with-prepared`.
    "cite-without-bibliography": (
        'bib-backend: "bibtex",',
        "faithful-acmart: cited a key but no bibliography is registered",
        "= Body\nA citation @Cohen07 with no bibliography.",
    ),
}


# --- Copyright / option validation variants --------------------------------
#
# A representative visual suite (NOT exhaustive): for each variant `validate`
# builds a matched LaTeX + Typst page and reports a page-1 mismatch %. The acmart
# package supports every copyright mode; this suite samples the common ones plus
# the document options whose effect shows on page 1.
# name -> (LaTeX class options, LaTeX preamble, Typst acmart.with args)
VARIANTS: dict[str, tuple[str, str, str]] = {
    "acmlicensed":    ("", r"\setcopyright{acmlicensed}",    '  copyright: "acmlicensed",\n'),
    "acmcopyright":   ("", r"\setcopyright{acmcopyright}",   '  copyright: "acmcopyright",\n'),
    "rightsretained": ("", r"\setcopyright{rightsretained}", '  copyright: "rightsretained",\n'),
    "usgov":          ("", r"\setcopyright{usgov}",          '  copyright: "usgov",\n'),
    "usgovmixed":     ("", r"\setcopyright{usgovmixed}",     '  copyright: "usgovmixed",\n'),
    "cc-by-nc-sa":    ("", "\\setcopyright{cc}\n\\setcctype{by-nc-sa}",
                       '  copyright: "cc", cc-type: "by-nc-sa",\n'),
    "screen":    (",screen", r"\setcopyright{acmlicensed}", '  screen: true,\n'),
    "review":    (",review", r"\setcopyright{acmlicensed}", '  review: true,\n'),
    "anonymous": (",anonymous", r"\setcopyright{acmlicensed}", '  anonymous: true,\n'),
    # nonacm drops the journal footer line and, for non-cc copyright, the whole
    # page-1 copyright/permission block (acmart.dtx:6599) — both visible on page 1.
    "nonacm":    (",nonacm", r"\setcopyright{acmlicensed}", '  nonacm: true,\n'),
    # authorversion swaps the page-1 copyright block: no permission text, and the
    # ACM bibstrip becomes the "author's version ... Version of Record" notice
    # naming the full journal + DOI (acmart.dtx:6612/6634).
    "authorversion": (",authorversion", r"\setcopyright{acmlicensed}",
                      '  author-version: true,\n'),
}

# Maximum allowed page-1 raster mismatch percentages for the validation variants.
# These are deliberately a little above the current measured values, so `check`
# catches real drift without turning harmless renderer noise into churn.
VARIANT_MISMATCH_MAX: dict[str, float] = {
    "acmlicensed": 4.75,
    "acmcopyright": 4.50,
    "rightsretained": 4.25,
    "usgov": 4.00,
    "usgovmixed": 4.50,
    "cc-by-nc-sa": 3.75,
    "screen": 4.75,
    "review": 5.00,
    "anonymous": 4.50,
    "nonacm": 2.50,
    "authorversion": 4.00,
}
